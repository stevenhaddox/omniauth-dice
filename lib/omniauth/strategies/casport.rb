require 'omniauth'
require 'logging'

class RequiredCustomParamError < StandardError; end
module OmniAuth
  module Strategies
    #
    # Provides omniauth authentication integration with a CAS server
    #
    class Casport
      include OmniAuth::Strategy
      args [:cas_server, :authentication_path]

      def initialize(*args)
        stdout_logger = Logging.logger(STDOUT)
        @logger = Kernel.const_defined?('Rails') ? Rails.logger : stdout_logger
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
      option :subject_dn_header, 'HTTP_SSL_CLIENT_S_DN'
      option :issuer_dn_header,  'HTTP_SSL_CLIENT_I_DN'
      # option :client_key_pass, nil
      # option :debug, nil
      # option :log_file, nil
      # option :fake_dn, nil

      private

      # Create a Faraday instance with the cas_server & appropriate SSL config
      def connection
        @connection ||= Faraday.new cas_server, ssl: ssl_hash
      end

      # Specifies which attributes are required arguments to initialize
      def required_params
        [:cas_server, :authentication_path]
      end

      # Verify that arguments required to properly run are present or fail hard
      def validate_required_params(args)
        required_params.each do |param|
          param_present = nil
          args.each do |arg|
            param_present = true if param_in_arg?(param, arg) == true
          end

          if param_present.nil?
            error_msg = "omniauth-casport error: #{param} is required"
            fail RequiredCustomParamError, error_msg
          end
        end
      end

      # Determine if a specified param symbol exists in the passed argument
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
