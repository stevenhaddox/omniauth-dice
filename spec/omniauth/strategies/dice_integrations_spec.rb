require 'spec_helper'
require'dnc'

class MockDice; end
describe OmniAuth::Strategies::Dice, type: :strategy do
  attr_accessor :app
  let(:auth_hash)  { last_response.headers['env']['omniauth.auth'] }
  let(:dice_hash)  { last_response.headers['env']['omniauth.dice'] }
  let!(:user_cert) { File.read('spec/certs/ruby_user.crt') }
  let!(:raw_dn)    { '/DC=org/DC=ruby-lang/CN=Ruby certificate rbcert' }
  let!(:user_dn)   { DN.new(dn_string: '/DC=org/DC=ruby-lang/CN=Ruby certificate rbcert') }
  let(:raw_issuer_dn)   { '/DC=org/DC=ruby-lang/CN=Ruby CA' }
  let(:issuer_dn)   { 'CN=RUBY CA,DC=RUBY-LANG,DC=ORG' }
  let!(:auth_hash) { {
    'uid' => 'RUBY CERTIFICATE RBCERT',
    'email' => '',
    'extra' => {
      'info' => {
        'dn' => user_dn
      }
    }
  } }

  # customize rack app for testing, if block is given, reverts to default
  # rack app after testing is done
  def set_app!(dice_options = {})
    dice_options = {:model => MockDice}.merge(dice_options)
    old_app = self.app
    self.app = Rack::Builder.app do
      use Rack::Session::Cookie, :secret => '1337geeks'
      use RackSessionAccess::Middleware
      use OmniAuth::Strategies::Dice, dice_options
      run lambda{|env| [404, {'env' => env}, ["HELLO!"]]}
    end
    if block_given?
      yield
      self.app = old_app
    end
    Capybara.app = self.app
    self.app
  end

  before(:all) do
    defaults={
      cas_server: 'http://example.org',
      authentication_path: '/users'
    }
    set_app!(defaults)
  end

  describe '#request_phase' do
    it 'should fail without a client DN' do
      expect { get '/auth/dice' }.to raise_error(OmniAuth::Error, 'You need a valid DN to authenticate.')
    end

    it "should set the client & issuer's DN (from certificate)" do
      header 'Ssl-Client-Cert', user_cert
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_CERT']).to eq(user_cert)
      expect(last_request.url).to eq('http://example.org/auth/dice')
      expect(last_request.env['rack.session']['omniauth.params']['user_dn']).to eq(user_dn.to_s)
      expect(last_request.env['rack.session']['omniauth.params']['issuer_dn']).to eq(issuer_dn)
      expect(last_response.location).to eq('http://example.org/auth/dice/callback')
    end

    it "should set the client's DN (from header)" do
      header 'Ssl-Client-S-Dn', raw_dn
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_S_DN']).to eq(raw_dn)
      expect(last_request.url).to eq('http://example.org/auth/dice')
      expect(last_request.env['rack.session']['omniauth.params']['user_dn']).to eq(user_dn.to_s)
      expect(last_request.env['rack.session']['omniauth.params']['issuer_dn']).to be_nil
      expect(last_response.location).to eq('http://example.org/auth/dice/callback')
    end

    it "should set the issuer's DN (from header)" do
      header 'Ssl-Client-S-Dn', raw_dn
      header 'Ssl-Client-I-Dn', raw_issuer_dn
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_I_DN']).to eq(raw_issuer_dn)
      expect(last_request.url).to eq('http://example.org/auth/dice')
      expect(last_request.env['rack.session']['omniauth.params']['issuer_dn']).to eq(issuer_dn)
      expect(last_response.location).to eq('http://example.org/auth/dice/callback')
    end
  end

  describe '#callback_phase' do
    it 'should request data from the cas_server' do
      header 'Ssl-Client-Cert', user_cert
      get '/auth/dice'
      follow_redirect!
      expect(last_response.location).to eq('/')
#      ap last_response
#      ap last_request.env
#      expect(last_response.env['omniauth.auth']).to eq(auth_hash)
    end

    context 'success' do
      it 'should return an omniauth auth_hash' do
        header 'Ssl-Client-Cert', user_cert
        get '/auth/dice'
        follow_redirect!
        expect(last_response.location).to eq('/')
        expect(last_request.env['omniauth.auth']).to be_kind_of(Hash)
        expect(last_request.env['omniauth.auth']).to eq(auth_hash)
      end
    end

    context 'fail' do
      pending 'todo'
    end
  end

#    expect(last_request.env['rack.session'][:dice][:dn]).to eq(cert_dn)
#    expect(last_request.env['rack.session'][:dice][:issuer]).to eq(cert_issuer)
#    expect(last_request.env['rack.session'][:dice][:sid]).to eq(cert_sid)
#    expect(last_response.status).to eq(200)

end
