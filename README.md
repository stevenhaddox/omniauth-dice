# Omniauth::Dice [![Gem Version](https://badge.fury.io/rb/omniauth-dice.png)](http://badge.fury.io/rb/omniauth-dice)

[![Travis CI](https://travis-ci.org/stevenhaddox/omniauth-dice.svg?branch=master)](https://travis-ci.org/stevenhaddox/omniauth-dice) [![Dependency Status](https://gemnasium.com/stevenhaddox/omniauth-dice.png)](https://gemnasium.com/stevenhaddox/omniauth-dice) [![Coverage Status](https://coveralls.io/repos/stevenhaddox/omniauth-dice/badge.png)](https://coveralls.io/r/stevenhaddox/omniauth-dice) [![Code Climate](https://codeclimate.com/github/stevenhaddox/omniauth-dice/badges/gpa.svg)](https://codeclimate.com/github/stevenhaddox/omniauth-dice) [![Inline docs](http://inch-ci.org/github/stevenhaddox/omniauth-dice.svg?branch=master)](http://inch-ci.org/github/stevenhaddox/omniauth-dice)

# **D**N **I**nteroperable **C**onversion **E**xpert

omniauth-dice is an internal authentication strategy that authenticates via
a user's X509 certificate DN string to an Enterprise CAS server via REST.

## Installation

Add this line to your application's Gemfile:
```ruby
gem 'omniauth-dice'

And then execute:

    $ bundle

Or install it yourself with:

    $ gem install omniauth-dice
```

## Usage

Setup your OmniAuth::Dice builder like so:

```ruby
{
  cas_server:          'https://example.org:3000',
  authentication_path: '/dn',
  format_header:       'application/xml', # default is 'application/json'
  format:              'xml', # default is 'json'
  dnc_options: { transformation: 'downcase' }, # see `dnc` gem for all options
  ssl_config:  {
    ca_file:     'spec/certs/CA.pem',
    client_cert: 'spec/certs/client.pem',
    client_key:  'spec/certs/key.np.pem'
  } # See OmniAuth::Strategies::Dice.ssl_hash for all options
}
```

Full configuration options are as follows:

* `cas_server` [String] Required base URL for CAS server
* `authentication_path` [String] URL path for endpoint, e.g. '/users'
* `return_field` [String] Optional path to append after DN string
* `ssl_config` [Hash] Configuration hash for `Faraday` SSL options
* `format_header` [String] 'application/json', 'application/xml', etc  
  Defaults to 'application/json'
* `format` [String] 'json', 'xml', etc.  
  Defaults to 'json'
* `client_cert_header` [String] ENV string to access user's X509 cert  
  Defaults to 'HTTP_SSL_CLIENT_CERT'
* `subject_dn_header` [String] ENV string to access user's subject_dn  
  Defaults to 'HTTP_SSLC_LIENT_S_DN'
* `issuer_dn_header` [String] ENV string to access user's issuer_dn  
  Defaults to 'HTTP_SSL_CLIENT_I_DN'
* `name_format` [Symbol] Format for auth_hash['info']['name']  
  Defaults to attempting DN common name -> full name -> first & last name  
  Valid options are: :cn, :full_name, :first_last_name to override

### SSL Client Certificate Notes

`Faraday` (the HTTP library used by OmniAuth) can accept certificate paths:

```
  client_cert: 'spec/certs/client.pem',
  client_key:  'spec/certs/key.np.pem'
```

Or it also works with actual certificates (such as to pass a passphrase in):
```
  client_cert: File.read('spec/certs/client.pem').to_cert,
  client_key:  OpenSSL::PKey::RSA.new(File.read('spec/certs/key.pem'), 'PASSW0RD')
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/omniauth-dice/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. **Add specs!**
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request
