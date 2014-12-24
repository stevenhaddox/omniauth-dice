require 'spec_helper'
class MockDice; end

describe OmniAuth::Strategies::Dice, type: :strategy do
  attr_accessor :app
  let(:auth_hash)    { last_response.headers['env']['omniauth.auth'] }
  let(:dice_hash) { last_response.headers['env']['omniauth.dice'] }
  let!(:user_cert)   { File.read('spec/certs/ruby_user.crt') }

  # customize rack app for testing, if block is given, reverts to default
  # rack app after testing is done
  def set_app!(dice_options = {})
    dice_options = {:model => MockDice}.merge(dice_options)
    old_app = self.app
    self.app = Rack::Builder.app do
      use Rack::Session::Cookie
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

    it "should set the client's DN (from certificate)" do
      header 'Ssl-Client-Cert', user_cert
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_CERT']).to eq(user_cert)
      #expect(last_response.original_headers['omniauth.dice']['raw_dn']).to eq(user_dn)
    end

    it "should set the client's DN (from header)" do
      user_dn = '/DC=org/DC=ruby-lang/CN=Ruby certificate rbcert'
      header 'Ssl-Client-S-Dn', user_dn
      get '/auth/dice'
      expect(last_request.env['HTTP_SSL_CLIENT_S_DN']).to eq(user_dn)
      #expect(last_response.original_headers['omniauth.dice']['raw_dn']).to eq(user_dn)
    end

    it 'should request data from the cas_server' do
      pending 'todo'
    end
  end

  describe '#callback_phase' do
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
