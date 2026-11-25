# frozen_string_literal: true

api = noderings_api(input('api_url'), input('api_token'))
id = input('test_id')

control 'noderings-vm' do
  title 'The VM runs with its tags and firewall, and DNS points at it'
  vm = api.vm("#{id}-vm")

  describe 'vm' do
    subject { vm }
    it { should_not be_nil }
  end

  next unless vm

  describe 'vm state' do
    subject { vm }
    its(['operationStatus']) { should eq 'OPERATION_STATUS_STARTED' }
    its(['distro']) { should eq 'DISTRO_UBUNTU_24_04' }
    its(['firewallRulesetId']) { should eq api.ruleset("#{id}-web")['id'] }
    its(['tags']) { should include 'kitchen' }
    its(['tags']) { should include 'chef' }
  end

  zone = api.zone("#{id}.#{input('domain')}")
  describe 'vm A record' do
    subject { api.record(zone['id'], 'vm', 'A')['rdata'] }
    it { should eq [vm['ipv4']] }
  end
end
