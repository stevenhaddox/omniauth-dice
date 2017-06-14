# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'omniauth/dice/version'

Gem::Specification.new do |spec|
  spec.name          = 'omniauth-dice'
  spec.version       = Omniauth::Dice::VERSION
  spec.authors       = ['Steven Haddox']
  spec.email         = ['steven.haddox@gmail.com']
  spec.summary       = 'DN Interoperable Conversion Expert Strategy'
  spec.description   = 'Simple gem to enable rack powered Ruby apps to
authenticate via REST with an enterprise CAS authentication server via X509
client certificates.'
  spec.homepage      = 'https://github.com/stevenhaddox/omniauth-dice'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(/^bin\//) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)\//)
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_development_dependency 'awesome_print'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'capybara'
  spec.add_development_dependency 'mime-types', '< 3.0'
  spec.add_development_dependency 'codeclimate-test-reporter'
  spec.add_development_dependency 'rack_session_access'
  spec.add_development_dependency 'redcarpet'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rack', '< 2.0'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rubocop', '~> 0.41.2', '< 0.42'
  spec.add_development_dependency 'webmock', '~> 2.3.2', '< 3.0'
  spec.add_development_dependency 'yard'

  spec.add_dependency 'addressable', '~> 2.4.0'
  spec.add_dependency 'cert_munger', '~> 0.2.2', '< 1.0'
  spec.add_dependency 'dnc', '~> 0.1.9'
  spec.add_dependency 'excon', '~> 0.43'
  spec.add_dependency 'faraday', '~> 0.9'
  spec.add_dependency 'faraday_middleware', '~> 0.9'
  spec.add_dependency 'hashie', '~> 3.4.6'
  spec.add_dependency 'logging'
  spec.add_dependency 'multi_xml', '~> 0.5'
  spec.add_dependency 'nokogiri', '< 1.7.0'
  spec.add_dependency 'omniauth', '< 1.5.0', '> 1.0'

  spec.cert_chain  = ['certs/stevenhaddox.pem']
  if $PROGRAM_NAME =~ /gem\z/
    spec.signing_key = File.expand_path('~/.gem/certs/gem-private_key.pem')
  end
end
