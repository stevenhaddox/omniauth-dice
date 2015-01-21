require 'spec_helper'

describe OmniAuth::Strategies::Dice do
  let!(:app)            { TestRackApp.new }
  let(:invalid_subject) { OmniAuth::Strategies::Dice.new(app) }
  let(:valid_subject)   {
    OmniAuth::Strategies::Dice.new(app,
      cas_server: 'https://dice.dev',
      authentication_path: '/users'
    )
  }
  let!(:client_dn_from_cert) { '/DC=org/DC=ruby-lang/CN=Ruby certificate rbcert' }
  let(:client_dn_reversed)   { client_dn_from_cert.split('/').reverse.join('/') }
  let(:formatted_client_dn)  { 'CN=RUBY CERTIFICATE RBCERT,DC=RUBY-LANG,DC=ORG' }

  context "invalid params" do
    subject { invalid_subject }
    let(:subject_without_authentication_path) { OmniAuth::Strategies::Dice.new(app, cas_server: 'https://dice.dev') }

    it 'should require a cas server url' do
      expect{ subject }.to raise_error(RequiredCustomParamError, "omniauth-dice error: cas_server is required")
    end

    it 'should require an authentication path' do
      expect{ subject_without_authentication_path }.to raise_error(RequiredCustomParamError, "omniauth-dice error: authentication_path is required")
    end
  end

  context "defaults" do
    subject { valid_subject }
    it 'should have the correct name' do
      expect(subject.options.name).to eq('dice')
    end

    it "should return the default options" do
      expect(subject.options.format).to        eq('json')
      expect(subject.options.format_header).to eq('application/json')
    end
  end

  context "configured with options" do
    subject { valid_subject }

    it 'should have the configured CAS server URL' do
      expect(subject.options.cas_server).to eq("https://dice.dev")
    end

    it 'should have the configured authorization path' do
      expect(subject.options.authentication_path).to eq('/users')
    end
  end

  context ".format_dn" do
    subject { valid_subject }

    it 'should ensure the client DN format is in the proper order' do
      formatted_cert_dn = subject.format_dn(client_dn_from_cert)
      expect(formatted_cert_dn).to eq(formatted_client_dn)

      formatted_reverse_client_dn = subject.format_dn(client_dn_reversed)
      expect(formatted_reverse_client_dn).to eq(formatted_client_dn)
    end
  end
end
