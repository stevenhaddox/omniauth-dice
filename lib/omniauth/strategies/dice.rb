require 'faraday'
require 'faraday_middleware'
require 'open-uri'
require 'omniauth'
require 'cert_munger'
require 'dnc'

class RequiredCustomParamError < StandardError; end

module OmniAuth
  module Strategies

    #
    # Provides omniauth authentication integration with a CAS server
    #
    class Dice
      include OmniAuth::Strategy
      attr_accessor :dn, :raw_dn, :data
      args [:cas_server, :authentication_path]

      def initialize(*args, &block)
        validate_required_params(args)

        super
      end

      option :dnc_options, {}
      option :cas_server, nil
      option :authentication_path, nil
      option :return_field, 'info'
      option :ssl_config, {}
      option :format_header, 'application/json'
      option :format, 'json'
      option :client_cert_header, 'HTTP_SSL_CLIENT_CERT'
      option :subject_dn_header,  'HTTP_SSL_CLIENT_S_DN'
      option :issuer_dn_header,   'HTTP_SSL_CLIENT_I_DN'

      # Reformat DN to expected element order for CAS DN server (via dnc gem).
      def format_dn(dn_str)
        custom_order = %w(cn l st ou o c street dc uid)
        default_opts = { dn_string: dn_str, string_order: custom_order }
        dnc_config = unhashie(options.dnc_options)
        DN.new( default_opts.merge(dnc_config) ).to_s
      end

      protected

      # Change Hashie indifferent access keys back to symbols
      def unhashie(hash)
        tmp_hash = {}
        hash.each do |key, value|
          tmp_hash[key.to_sym] = value
        end

        tmp_hash
      end

      def setup_phase(*args)
        log :debug, 'setup_phase'
        super
      end

      def request_phase
        subject_dn = get_dn_by_type('subject')
        return fail!('You need a valid DN to authenticate.') unless subject_dn
        user_dn = format_dn(subject_dn)
        log :debug, "Formatted user_dn:   #{user_dn}"
        return fail!('You need a valid DN to authenticate.') unless user_dn
        set_session_dn(user_dn, 'subject')
        issuer_dn = get_dn_by_type('issuer')
        issuer_dn = format_dn(issuer_dn) if issuer_dn
        log :debug, "Formatted issuer_dn: #{issuer_dn}"
        set_session_dn(issuer_dn, 'issuer') if issuer_dn

        redirect callback_url
      end

      def callback_phase
        issuer_dn = env['omniauth.params']['issuer_dn']
        if issuer_dn
          response = connection.get query_url, { issuerDN: issuer_dn }
        else
          response = connection.get query_url
        end
        if !response || response.status.to_i >= 400
          log :error, response.inspect
          return fail!(:invalid_credentials)
        end
        @data = response.body
        create_auth_hash

        redirect request.env['omniauth.origin'] || '/'
      end

      private

      # Coordinate building out the auth_hash
      def create_auth_hash
        log :debug, '.create_auth_hash'
        init_auth_hash
        set_auth_uid
        parse_response_data
        create_auth_info
      end

      # Initialize the auth_hash expected fields
      def init_auth_hash
        log :debug, '.init_auth_hash'
        session['omniauth.auth'] ||= {
          'provider' => 'Dice',
          'uid'      => nil,
          'info'     => nil,
          'extra'    => {
            'raw_info' => nil
          }
        }
      end

      # Set the user's uid field for the auth_hash
      def set_auth_uid
        log :debug, '.set_auth_uid'
        session['omniauth.auth']['uid'] = env['omniauth.params']['user_dn']
      end

      # Detect data format, parse with appropriate library
      def parse_response_data
        log :debug, '.parse_response_data'
        session['omniauth.auth']['extra']['raw_info'] = @data
        log :debug, "cas_server response.body:\r\n#{@data}"
        unless @data.class == Hash # Webmock hack
          case options.format.to_sym
          when :json
            @data = JSON.parse(@data, symbolize_names: true)
          when :xml
            @data = MultiXml.parse(@data)
          end
          log :debug, "Formatted response.body data: #{@data}"
        end

        @data
      end


      # Parse CAS server response and assign values as appropriate
      def create_auth_info
        log :debug, '.create_auth_info'
        info = {}

        defaults = [:dn, :email, :firstName, :lastName, :fullName,
                    :citizenshipStatus, :country, :grantBy, :organizations,
                    :uid, :dutyorg, :visas, :affiliations]

        info['dn']                 = @data[:dn]
        info['email']              = @data[:email]
        info['first_name']         = @data[:firstName]
        info['last_name']          = @data[:lastName]
        info['full_name']          = @data[:fullName]
        info['citizenship_status'] = @data[:citizenshipStatus]
        info['country']            = @data[:country]
        info['grant_by']           = @data[:grantBy]
        info['organizations']      = @data[:organizations]
        info['uid']                = @data[:uid]
        info['dutyorg']            = @data[:dutyorg]
        info['visas']              = @data[:visas]
        info['affiliations']       = @data[:affiliations]

        @data.each do |key, value|
          info[key.to_s.to_snake] = value unless defaults.include?(key)
        end

        session['omniauth.auth']['info'] = info
      end

      # Coordinate getting DN from cert, fallback to header
      def get_dn_by_type(type='subject')
        raw_dn   = get_dn_from_certificate(type=type)
        raw_dn ||= get_dn_from_header(type=type)
      end

      # Reads the DN from headers
      def get_dn_from_header(type)
        headers = request.env
        if type == 'issuer'
          raw_dn = headers["#{options.issuer_dn_header}"]
        else
          raw_dn = headers["#{options.subject_dn_header}"]
        end
        log :debug, "raw_dn (#{type}) from headers: #{raw_dn}"

        raw_dn
      end

      # Gets the DN from X509 certificate
      def get_dn_from_certificate(type)
        cert_str = request.env["#{options.client_cert_header}"]
        if cert_str
          client_cert = cert_str.to_cert
          log :debug, "Client certificate:\r\n#{client_cert}"
          raw_dn ||= parse_dn_from_certificate(client_cert, type)
          log :debug, "raw_dn (#{type}) from cert: #{raw_dn}"
        end

        raw_dn
      end

      # Parse the DN out of an SSL X509 Client Certificate
      def parse_dn_from_certificate(certificate, type='subject')
        certificate.send(type.to_sym).to_s
      end

      # Create a Faraday instance with the cas_server & appropriate SSL config
      def connection
        log :debug, '.connection'

        @conn ||= Faraday.new(url: options.cas_server, ssl: ssl_hash) do |conn|
          conn.headers  = headers
          conn.response :logger                  # log requests to STDOUT
          conn.response :xml,  :content_type => /\bxml$/
          conn.response :json, :content_type => /\bjson$/
          conn.adapter  :excon
        end
      end

      def headers
        {
          'Accept' => options.format_header,
          'Content-Type' => options.format_header,
          'X-XSRF-UseProtection' => ('false' if options.format_header),
          'user-agent' => "Faraday via Ruby #{RUBY_VERSION}"
        }
      end

      # Build out the query URL for CAS server with DN params
      def query_url
        user_dn    = env['omniauth.params']['user_dn']
        build_query = "#{options.cas_server}#{options.authentication_path}"
        build_query += "/#{user_dn}"
        build_query += "/#{options.return_field}.#{options.format}"
        URI::encode(build_query)
      end

      # Specifies which attributes are required arguments to initialize
      def required_params
        [:cas_server, :authentication_path]
      end

      # Verify that arguments required to properly run are present or fail hard
      # NOTE: CANNOT call "log" method from initialize block hooks
      def validate_required_params(args)
        required_params.each do |param|
          param_present = nil
          args.each do |arg|
            param_present = true if param_in_arg?(param, arg) == true
          end

          if param_present.nil?
            error_msg = "omniauth-dice error: #{param} is required"
            fail RequiredCustomParamError, error_msg
          end
        end
      end

      # Determine if a specified param symbol exists in the passed argument
      # NOTE: CANNOT call "log" method from initialize block hooks
      def param_in_arg?(param, arg)
        if arg.class == Hash
          if arg.key?(param.to_sym)
            true
          else
            false
          end
        else
          false
        end
      end

      def set_session_dn(dn_string, type='subject')
        dn_type = case type
        when 'subject'
          'user_dn'
        when 'issuer'
          'issuer_dn'
        else
          fail "Invalid DN string type"
        end
        session['omniauth.params'] ||= {}
        session['omniauth.params'][dn_type] = dn_string
      end

      # Dynamically builds out Faraday's SSL config hash by merging passed
      # options hash with the default options.
      #
      # Available Faraday config options include:
      # ca_file      (e.g., /usr/lib/ssl/certs/ca-certificates.crt)
      # ca_path      (e.g., /usr/lib/ssl/certs)
      # cert_store
      # client_cert
      # client_key
      # certificate
      # private_key
      # verify
      # verify_mode
      # verify_depth
      # version
      def ssl_hash
        ssl_defaults = {
          verify:       true,
          verify_depth: 3,
          version:      'TLSv1'
        }

        custom_config = unhashie(options.ssl_config)
        ssl_defaults.merge(custom_config)
      end
    end
  end
end
