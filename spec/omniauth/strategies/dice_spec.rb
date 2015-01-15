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
      expect(subject.options.uid_field).to     eq(:dn)
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

  context "Old specs" do
    context "success" do
      before :each do
        pending
      end

      it "should return dn from raw_info if available" do
        subject.stub!(:raw_info).and_return({'dn' => 'givenName = Steven Haddox, ou = apache, ou = org'})
        subject.dn.should eq('givenName = Steven Haddox, ou = apache, ou = org')
      end

      it "should return email from raw_info if available" do
        subject.stub!(:raw_info).and_return({'email' => 'stevenhaddox@shortmail.com'})
        subject.email.should eq('stevenhaddox@shortmail.com')
      end

      it "should return nil if there is no raw_info and email access is not allowed" do
        subject.stub!(:raw_info).and_return({})
        subject.email.should be_nil
      end

      it "should return the first email if there is no raw_info and email access is allowed" do
        subject.stub!(:raw_info).and_return({})
        subject.options['scope'] = 'user'
        subject.stub!(:emails).and_return([ 'you@example.com' ])
        subject.email.should eq('you@example.com')
      end
    end

    context "failure" do
      pending
    end
  end

end
