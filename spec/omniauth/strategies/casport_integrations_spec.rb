require 'spec_helper'
class MockCasport; end

describe OmniAuth::Strategies::Casport do
  attr_accessor :app
  let(:auth_hash){ last_response.headers['env']['omniauth.auth'] }
  let(:casport_hash){ last_response.headers['env']['omniauth.casport'] }

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
    set_app!
  end

  describe '#setup_phase' do
    it 'should access the cert from HTTP_SSL_CLIENT_CERT' do

      get '/auth/casport/setup'
ap last_response
      expect(last_response.body).to be_include("CERTSSSSS!!!")
    end
  end
  describe '#request_phase' do
    it 'should assign the DN from HTTP_SSL_CLIENT_S_DN' do

      get '/auth/casport'
ap last_response
      expect(last_response.body).to be_include("<form")
    end
  end
end
