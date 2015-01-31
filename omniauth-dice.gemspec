# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'omniauth/dice/version'

Gem::Specification.new do |spec|
  spec.name          = 'omniauth-dice'
  spec.version       = Omniauth::Dice::VERSION
  spec.authors       = ['Steven Haddox']
  spec.email         = ['steven.haddox@gmail.com']
  spec.summary       = %q{DN Interoperable Conversion Expert Strategy}
  spec.description   = %q{Simple gem to enable rack powered Ruby apps to authenticate via REST with an enterprise CAS authentication server via X509 client certificates.}
  spec.homepage      = "https://github.com/stevenhaddox/omniauth-dice"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_development_dependency 'awesome_print'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'capybara'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'rack_session_access'
  spec.add_development_dependency 'redcarpet'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rack'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'simplecov-badge'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'yard'

  spec.add_dependency 'cert_munger', '~> 0.1'
  spec.add_dependency 'dnc', '~> 0.1'
  spec.add_dependency 'excon', '~> 0.43'
  spec.add_dependency 'faraday', '~> 0.9'
  spec.add_dependency 'faraday_middleware', '~> 0.9'
  spec.add_dependency 'logging', '~> 1.8'
  spec.add_dependency 'multi_xml', '~> 0.5'
  spec.add_dependency 'omniauth', '~> 1.0'

  spec.cert_chain  = ['certs/stevenhaddox.pem']
  spec.signing_key = File.expand_path("~/.gem/certs/gem-private_key.pem") if $0 =~ /gem\z/
end
