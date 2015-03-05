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
    # @option cas_server [String] Required base URL for CAS server
    # @option authentication_path [String] URL path for endpoint, e.g. '/users'
    # @option return_field [String] Optional path to append after DN string
    # @option ssl_config [Hash] Configuration hash for `Faraday` SSL options
    # @option format_header [String] 'application/json', 'application/xml', etc
    #   Defaults to 'application/json'
    # @option format [String] 'json', 'xml', etc.
    #   Defaults to 'json'
    # @option client_cert_header [String] ENV string to access user's X509 cert
    #   Defaults to 'HTTP_SSL_CLIENT_CERT'
    # @option subject_dn_header [String] ENV string to access user's subject_dn
    #   Defaults to 'HTTP_SSLC_LIENT_S_DN'
    # @option issuer_dn_header [String] ENV string to access user's issuer_dn
    #   Defaults to 'HTTP_SSL_CLIENT_I_DN'
    # @option name_format [Symbol] Format for auth_hash['info']['name']
    #   Defaults to attempting DN common name -> full name -> first & last name
    #   Valid options are: :cn, :full_name, :first_last_name to override
    # @option primary_visa [String] String to trigger primary visa boolean
    class Dice
      include OmniAuth::Strategy
      attr_accessor :dn, :raw_dn, :data

      option :dnc_options, {}
      option :cas_server, nil
      option :custom_callback_url, nil
      option :use_callback_url, false
      option :authentication_path, nil
      option :return_field, 'info'
      option :ssl_config, {}
      option :format_header, 'application/json'
      option :format, 'json'
      option :client_cert_header, 'HTTP_SSL_CLIENT_CERT'
      option :subject_dn_header,  'HTTP_SSL_CLIENT_S_DN'
      option :issuer_dn_header,   'HTTP_SSL_CLIENT_I_DN'
      option :name_format
      option :primary_visa

      # Reformat DN to expected element order for CAS DN server (via dnc gem).
      def format_dn(dn_str)
        get_dn(dn_str).to_s
      end

      # Specifies which attributes are required arguments to initialize
      def required_params
        [:cas_server, :authentication_path]
      end

      # Determine if required arguments are present or fail hard
      def validate_required_params
        log :debug, '.validate_required_params'
        required_params.each do |param|
          unless options.send(param)
            error_msg = "omniauth-dice error: #{param} is required"
            fail RequiredCustomParamError, error_msg
          end
        end
      end

      def request_phase
        validate_required_params
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

        redirect_for_callback
      end

      def callback_phase
        response = authenticate_user
        @raw_data = response.body
        @data = parse_response_data
        session['omniauth.auth'] ||= auth_hash

        super
      end

      def auth_hash
        log :debug, '.auth_hash'
        Hashie::Mash.new( {
          'provider' => name,
          'uid'      => uid,
          'info'     => info,
          'extra'    => extra
        } )
      end

      # Set the user's uid field for the auth_hash
      uid do
        log :debug, '.uid'
        env['omniauth.params']['user_dn']
      end

      # Detect data format, parse with appropriate library
      extra do
        log :debug, '.extra'
        { 'raw_info' => @raw_data }
      end

      # Parse CAS server response and assign values as appropriate
      info do
        log :debug, '.info'
        info = {}
        info = auth_info_defaults(info)
        info = auth_info_dynamic(info)
        info = auth_info_custom(info)

        info
      end

      def redirect_for_callback
        if options.custom_callback_url
          redirect options.custom_callback_url
        else
          if options.use_callback_url == true
            redirect callback_url
          else
            redirect callback_path
          end
        end
      end

      private

      # Change Hashie indifferent access keys back to symbols
      def unhashie(hash)
        tmp_hash = {}
        hash.each do |key, value|
          tmp_hash[key.to_sym] = value
        end

        tmp_hash
      end

      def authenticate_user
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

        response
      end

      # Default ['omniauth.auth']['info'] field names
      def info_defaults
        [:dn, :email, :firstName, :lastName, :fullName, :citizenshipStatus,
         :country, :grantBy, :organizations, :uid, :dutyorg, :visas,
         :affiliations]
      end

      # Defualt auth_info fields
      def auth_info_defaults(info)
        info_defaults.each do |key_name|
          info[key_name.to_s.to_snake] = @data[key_name]
        end

        info
      end

      # Dynamic auth_info fields
      def auth_info_dynamic(info)
        @data.each do |key, value|
          info[key.to_s.to_snake] = value unless info_defaults.include?(key)
        end

        info
      end

      # Custom auth_info fields
      def auth_info_custom(info)
        info['common_name'] = get_dn(info['dn']).cn
        set_name(info)
        has_primary_visa?(info)
        info['likely_npe?'] = identify_npe(info)

        info
      end

      # Allow for a custom field for the name, or use a best guess default
      def set_name(info)
        # Do NOT override the value if it's returned from the CAS server
        return info['name'] if info['name']
        info['name'] = case options.name_format
        when :cn
          info['common_name']
        when :full_name
          info['full_name']
        when :first_last_name
          "#{info['first_name']} #{info['last_name']}"
        end
        info['name'] ||= info['common_name'] || info['full_name'] ||
                         "#{info['first_name']} #{info['last_name']}"
      end

      # Determine if client has the primary visa
      def has_primary_visa?(info)
        return info['primary_visa?'] = false unless info['visas']
        return info['primary_visa?'] = false unless options.primary_visa
        info['primary_visa?'] = info['visas'].include?(options.primary_visa)
      end

      # Determine if a client is likely a non-person entity
      def identify_npe(info)
        info['likely_npe?']   = nil
        return true  if auth_cn_with_tld?(info['common_name']) == true
        return true  if auth_info_missing_email?(info)         == true
        return true  if auth_has_email_without_names?(info)    == true
        return false if auth_has_email_with_any_name?(info)    == true
      end

      # Identify if there's a domain w/ TLD in the common_name
      def auth_cn_with_tld?(common_name)
        !!( common_name =~ /\w{2}\.\w+(\.\w{3,}+)?/ )
      end

      # Determine if the auth_hash does not have an email address
      def auth_info_missing_email?(info)
        !( info['email'] ) # !! returns false if no email, ! returns true
      end

      # Determine if the auth_hash has an email but no name fields
      def auth_has_email_without_names?(info)
        return false unless info['email']
        return true if auth_info_has_any_name?(info) == false
      end

      # Determine if the auth_hash has an email with ANY name field
      def auth_has_email_with_any_name?(info)
        return false unless info['email']
        return true if auth_info_has_any_name?(info) == true
      end

      # Determine if any name fields are present in the auth_hash['info']
      def auth_info_has_any_name?(info)
        name   = info['full_name']
        name ||= info['first_name']
        name ||= info['last_name']
        !!(name)
      end

      # Coordinate getting DN from cert, fallback to header
      def get_dn_by_type(type='subject')
        raw_dn   = get_dn_from_certificate(type)
        raw_dn ||= get_dn_from_header(type)
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

      # Detect data format, parse with appropriate library
      def parse_response_data
        log :debug, '.parse_response_data'
        log :debug, "cas_server response.body:\r\n#{@raw_data}"
        formatted_data = nil
        unless @raw_data.class == Hash # Webmock hack
          case options.format.to_sym
          when :json
            formatted_data = JSON.parse(@raw_data, symbolize_names: true)
          when :xml
            formatted_data = MultiXml.parse(@raw_data)['userinfo']
          end
        end
        formatted_data = formatted_data.nil? ? @raw_data : formatted_data
        log :debug, "Formatted response.body data: #{formatted_data}"

        formatted_data
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

      # Retrieve DNC default & custom configs
      #
      # @param dn_str [String] The string of text you wish to parse into a DN
      # @return [DN]
      def get_dn(dn_str)
        custom_order = %w(cn l st ou o c street dc uid)
        default_opts = { dn_string: dn_str, string_order: custom_order }
        dnc_config = unhashie(options.dnc_options)
        DN.new( default_opts.merge(dnc_config) )
      end
    end
  end
end
