require 'spec_helper'
class MockCasport; end

describe OmniAuth::Strategies::Casport, type: :strategy do
  attr_accessor :app
  let(:auth_hash)    { last_response.headers['env']['omniauth.auth'] }
  let(:casport_hash) { last_response.headers['env']['omniauth.casport'] }
  let!(:user_cert)   { File.read('spec/certs/ruby_user.crt') }

  # customize rack app for testing, if block is given, reverts to default
  # rack app after testing is done
  def set_app!(casport_options = {})
    casport_options = {:model => MockCasport}.merge(casport_options)
    old_app = self.app
    self.app = Rack::Builder.app do
      use Rack::Session::Cookie
      use OmniAuth::Strategies::Casport, casport_options
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
      cas_server: 'https://casport.dev',
      authentication_path: '/users'
    }
    set_app!(defaults)
  end

#  describe '#setup_phase' do
#    it 'should log that setup_phase was invoked' do
#      pending 'FIXME!'
#      header 'Ssl-Client-Cert', user_cert
#      get '/auth/casport/setup'
#    end
#  end

  describe '#request_phase', :focus do
    it 'should fail without a client DN' do
      expect { get '/auth/casport' }.to raise_error(OmniAuth::Error, 'You need a valid DN to authenticate.')
    end

    it 'should assign the user certificate to an omniauth variable' do
      header 'Ssl-Client-Cert', user_cert
      get '/auth/casport'
puts last_response.to_yaml
ap last_request.env
      expect(last_request.env['HTTP_SSL_CLIENT_CERT']).to eq(user_cert)
      expect(last_response.headers['env']).to be(!nil)
#      expect(last_response.session).to be(nil)
#      expect(last_response.body).to be_include("CERTSSSSS!!!")
    end

    it 'should request data from the cas_server' do
      pending 'todo'
    end
  end

  describe '#callback_phase' do
    context 'success' do
      it 'should return an omniauth auth_hash' do
        pending 'todo'
        get '/auth/casport/callback'
        expect(last_request.env['omniauth.auth']).to be_kind_of(Hash)
      end
    end
    context 'fail' do
      pending 'todo'
    end
  end

#    expect(last_request.env['rack.session'][:casport][:dn]).to eq(cert_dn)
#    expect(last_request.env['rack.session'][:casport][:issuer]).to eq(cert_issuer)
#    expect(last_request.env['rack.session'][:casport][:sid]).to eq(cert_sid)
#    expect(last_response.status).to eq(200)

end
