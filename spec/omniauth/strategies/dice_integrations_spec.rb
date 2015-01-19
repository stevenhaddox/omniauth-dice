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

  # customize rack app for testing, if block is given, reverts to default
  # rack app after testing is done
  def set_app!(dice_options = {})
    dice_options = {:model => MockDice}.merge(dice_options)
    old_app = self.app
    self.app = Rack::Builder.app do
      use Rack::Session::Cookie, :secret => '1337geeks'
      use OmniAuth::Strategies::Dice, dice_options
      run lambda{|env| [404, {'env' => env}, ["HELLO!"]]}
    end
    if block_given?
      yield
      self.app = old_app
    end
    self.app
  end

  before(:all) do
    defaults={
      cas_server: 'https://dice.dev',
      authentication_path: '/users'
    }
    set_app!(defaults)
  end

  describe '#request_phase' do
    it 'should fail without a client DN' do
      expect { get '/auth/dice' }.to raise_error(OmniAuth::Error, 'You need a valid DN to authenticate.')
    end

    # This test is imperfect, but for now it works as so:
    # get '/auth/dice' with no headers fails
    # Add header 'Ssl-Client-Cert' and we're redirected to callback == success
    it "should set the client's DN (from certificate)" do
      header 'Ssl-Client-Cert', user_cert
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_CERT']).to eq(user_cert)
      expect(last_request.url).to eq('http://example.org/auth/dice')
      expect(last_response.location).to eq('http://example.org/auth/dice/callback')
    end

    # This test is imperfect, but for now it works as so:
    # get '/auth/dice' with no headers fails
    # Add header 'Ssl-Client-S-Dn' and we're redirected to callback == success
    it "should set the client's DN (from header)" do
      header 'Ssl-Client-S-Dn', raw_dn
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_S_DN']).to eq(raw_dn)
      expect(last_request.url).to eq('http://example.org/auth/dice')
      expect(last_response.location).to eq('http://example.org/auth/dice/callback')
    end
  end

  describe '#callback_phase' do
    it 'should request data from the cas_server' do
      header 'Ssl-Client-Cert', user_cert
      get '/auth/dice'
      follow_redirect!
      expect(last_response.location).to eq('/')
      ap last_response
    end

    context 'success' do
      it 'should return an omniauth auth_hash' do
        pending 'todo'
        get '/auth/dice/callback'
        expect(last_request.env['omniauth.auth']).to be_kind_of(Hash)
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
