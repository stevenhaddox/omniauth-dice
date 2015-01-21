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
      attr_accessor :dn, :raw_dn
      args [:cas_server, :authentication_path]

      def initialize(*args, &block)
        validate_required_params(args)

        super
      end

      # option :fields, [:dn]
      option :uid_field, :dn

      option :cas_server, nil
      option :authentication_path, nil
      option :ssl_config, {}
      option :format_header, 'application/json'
      option :format, 'json'
      option :client_cert_header, 'HTTP_SSL_CLIENT_CERT'
      option :subject_dn_header,  'HTTP_SSL_CLIENT_S_DN'
      option :issuer_dn_header,   'HTTP_SSL_CLIENT_I_DN'
      # option :client_key_pass, nil
      # option :fake_dn, nil

      # Reformat DN to expected element order for CAS DN server (via dnc gem).
      def format_dn(dn_str)
        custom_order = %w(cn l st ou o c street dc uid)
        DN.new({dn_string: dn_str, string_order: custom_order}).to_s
      end

      protected

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
        user_dn  = env['omniauth.params']['user_dn']
        response = connection.post options.authentication_path, { DN: user_dn }

        query_path = "#{options.cas_server}#{options.authentication_path}"
        ap query_url
        ap user_dn

        cas_response = nil # GET / POST here!
#        return fail!(:invalid_credentials) if !authentication_response
#        return fail!(:invalid_credentials) if authentication_response.code.to_i >= 400

        redirect request.env['omniauth.origin'] || '/'
      end

      private

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
          log :debug, "raw_dn from cert: #{raw_dn}"
        end

        raw_dn
      end

      # Parse the DN out of an SSL X509 Client Certificate
      def parse_dn_from_certificate(certificate, type='subject')
        certificate.send(type.to_sym).to_s
      end

      # Create a Faraday instance with the cas_server & appropriate SSL config
      def connection
        log :debug, 'connection method'
        @connection ||= Faraday.new cas_server, ssl: ssl_hash
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

        if session['omniauth.params']
          session['omniauth.params'][dn_type] = dn_string
        else
          session['omniauth.params'] = { dn_type => dn_string }
        end
      end

      # Dynamically builds out Faraday's SSL config hash by merging passed
      # options hash with the default options.
      #
      # Available Faraday config options include:
      # ca_file
      # ca_path
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
          ca_file:    '/usr/lib/ssl/certs/ca-certificates.crt',
          client_cer: '/usr/lib/ssl/certs/cert.cer',
          client_key: '/usr/lib/ssl/certs/cert.key',
          version:    'SSLv3'
        }

        ssl_defaults.merge(ssl_config)
      end
    end
  end
end
