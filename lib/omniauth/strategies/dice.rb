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

      def initialize(*args)
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
        raw_dn = get_dn_from_header(request.env)
        raw_dn ||= get_dn_from_env_certificate
        return fail!('You need a valid DN to authenticate.') if !raw_dn
        session['omniauth.dice'] = { 'raw_dn' => raw_dn }
        ap session['omniauth.dice']['raw_dn']

        redirect callback_url
      end

      def callback_phase
ap '*'*80
ap response
        raw_dn = session['omniauth.dice']['raw_dn']
        session.delete('omniauth.dice')
        return fail!('Client DN could not be retrieved') unless raw_dn
#ap session.delete 'omniauth.crowd'

#        return fail!(:invalid_credentials) if !authentication_response
#        return fail!(:invalid_credentials) if authentication_response.code.to_i >= 400
      end

      private

      # Reads the DN from headers
      def get_dn_from_header(headers)
        raw_dn = headers["#{options.subject_dn_header}"]
        log :debug, "raw_dn from headers: #{raw_dn}"

        raw_dn
      end

      # Gets the DN from X509 certificate
      def get_dn_from_env_certificate
        cert_str = request.env["#{options.client_cert_header}"]
        if cert_str
          client_cert = cert_str.to_cert
          log :debug, "certificate string:\r\n#{client_cert}"
          raw_dn ||= parse_dn_from_certificate(client_cert)
          log :debug, "raw_dn from cert: #{raw_dn}"
        end

        raw_dn
      end

      # Parses the Subject DN out of an SSL X509 Client Certificate
      def parse_dn_from_certificate(certificate)
        raw_dn ||= certificate.subject.to_s
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
