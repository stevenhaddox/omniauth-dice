# Omniauth::Dice [![Gem Version](https://badge.fury.io/rb/omniauth-dice.png)](http://badge.fury.io/rb/omniauth-dice)

[![Travis CI](https://travis-ci.org/stevenhaddox/omniauth-dice.svg?branch=master)](https://travis-ci.org/stevenhaddox/omniauth-dice) [![Dependency Status](https://gemnasium.com/stevenhaddox/omniauth-dice.png)](https://gemnasium.com/stevenhaddox/omniauth-dice) [![Coverage Status](https://coveralls.io/repos/stevenhaddox/omniauth-dice/badge.png)](https://coveralls.io/r/stevenhaddox/omniauth-dice) [![Code Climate](https://codeclimate.com/github/stevenhaddox/omniauth-dice/badges/gpa.svg)](https://codeclimate.com/github/stevenhaddox/omniauth-dice) [![Inline docs](http://inch-ci.org/github/stevenhaddox/omniauth-dice.svg?branch=master)](http://inch-ci.org/github/stevenhaddox/omniauth-dice)

# **D**N **I**nteroperable **C**onversion **E**xpert

omniauth-dice is an internal authentication strategy that authenticates via
a user's X509 certificate DN string to an Enterprise CAS server via REST.

## Installation

Add this line to your application's Gemfile:

    gem 'omniauth-dice', '~> 0.1'

And then execute:

    $ bundle

Or install it yourself with:

    $ gem install omniauth-dice

## Usage

Setup your OmniAuth::Dice builder like so:

Ruby on Rails (3.0+):
```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :dice, {
    cas_server:          'https://example.org',
    authentication_path: '/users',
    primary_visa:        'EQUESTRIA',
    dnc_options: { :transformation => 'downcase' }, # see `dnc` gem for all options
    ssl_config: {
        ca_file:     '/path/to/your/CA.all.pem',
        client_cert: '/path/to/server/cert.pem',
        client_key:  '/path/to/server/key.np.key'
    }
  }
end
```

Rack / Sinatra:
```ruby
use OmniAuth::Strategies::Dice, {
  cas_server:          'https://example.org:3000',
  authentication_path: '/dn',
  format_header:       'application/xml', # default is 'application/json'
  format:              'xml', # default is 'json'
  primary_visa:        'EQUESTRIA', # Optional
  dnc_options: { transformation: 'downcase' }, # see `dnc` gem for all options
  ssl_config: {
      ca_file:     '/path/to/your/CA.all.pem',
      client_cert: '/path/to/server/cert.pem',
      client_key:  '/path/to/server/key.np.key'
  }
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

## auth_hash Results

The session's omniauth['auth'] hash will resond with the following structure:

```
{
  "provider"=>"dice",
  "uid"=>"cn=steven haddox,ou=rails,ou=ruby,ou=a,o=developer,c=us",
  "info"=>{
    "dn"=>"cn=steven haddox,ou=rails,ou=ruby,ou=a,o=developer,c=us",
    "email"=>"steven.haddox@example.org",
    "name"=>"steven haddox",
    "primary_visa?"=>false,
    "likely_npe?"=>false
    # ...<other fields dynamically inserted>...
  },
  "extra"=>{
    "raw_info"=>{
      # ...parsed response from CAS server...
    }
  }
}
```

The `provider`, `uid`, `info`, and `extra` fields follow omniauth best
practices but there are a few computed fields from omniauth-dice worth being
aware of:

* `likely_npe?`: [Boolean] This field tries to detect if the client  
  certificate / DN comes from a non-person entity (e.g., server) or a person.
* `primary_visa?`: [Boolean] If the CAS server responds with an array of  
  `visas`, this attribute will indicate if a specific visa is present.
* `name`: [String] Returns the client's name as configured or uses defaults.

### SSL Client Certificate Notes

`Faraday` (the HTTP library used by OmniAuth) can accept certificate paths:

```
  client_cert: 'path/to/server/cert.pem',
  client_key:  'path/to/server/key.np.pem'
```

Or it also works with actual certificates (such as to pass a passphrase in):
```
  client_cert: File.read('path/to/server/cert.pem').to_cert,
  client_key:  OpenSSL::PKey::RSA.new(File.read('path/to/server/key.pem'), 'PASSW0RD')
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/omniauth-dice/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. **Add specs!**
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request
