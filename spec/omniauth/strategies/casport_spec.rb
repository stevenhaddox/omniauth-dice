require 'spec_helper'

describe OmniAuth::Strategies::Casport do
  let!(:app)             { TestRackApp.new }
  let(:invalid_subject) { OmniAuth::Strategies::Casport.new(app) }
  let(:valid_subject)   {
    OmniAuth::Strategies::Casport.new(app,
      cas_server: 'https://casport.dev',
      authentication_path: '/users'
    )
  }

  context "invalid params" do
    subject { invalid_subject }
    let(:subject_without_authentication_path) { OmniAuth::Strategies::Casport.new(app, cas_server: 'https://casport.dev') }

    it 'should require a cas server url' do
      expect{ subject }.to raise_error(RequiredCustomParamError, "omniauth-casport error: cas_server is required")
    end

    it 'should require an authentication path' do
      expect{ subject_without_authentication_path }.to raise_error(RequiredCustomParamError, "omniauth-casport error: authentication_path is required")
    end
  end

  context "defaults" do
    subject { valid_subject }
    it 'should have the correct name' do
      expect(subject.options.name).to eq('casport')
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
      expect(subject.options.cas_server).to eq("https://casport.dev")
    end

    it 'should have the configured authorization path' do
      expect(subject.options.authentication_path).to eq('/users')
    end

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
