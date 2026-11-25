# frozen_string_literal: true

api = noderings_api(input('api_url'), input('api_token'))
id = input('test_id')
zone_name = "#{id}.#{input('domain')}"

control 'noderings-ssh-key' do
  title 'The SSH key exists'
  describe 'ssh key' do
    subject { api.ssh_key("#{id}-key") }
    its(['name']) { should eq "#{id}-key" }
    its(['keyType']) { should eq 'rsa' }
  end
end

control 'noderings-dns' do
  title 'The zone and its records exist with the declared values'
  zone = api.zone(zone_name)

  describe 'zone' do
    subject { zone }
    it { should_not be_nil }
  end

  next unless zone

  describe 'DNSSEC' do
    subject { api.get("/v1/dns/zones/#{zone['id']}/dnssec")['mode'] }
    it { should_not eq 'DNSSEC_MODE_UNSIGNED' }
  end

  describe 'www A' do
    subject { api.record(zone['id'], 'www', 'A') }
    its(['rdata']) { should match_array %w(192.0.2.10 192.0.2.11) }
    its(['ttl']) { should eq 300 }
  end

  describe 'apex MX' do
    subject { api.record(zone['id'], '@', 'MX')['rdata'].map(&:downcase) }
    it { should match_array ['10 mx1.example.net.', '20 mx2.example.net.'] }
  end

  describe 'apex TXT' do
    subject { api.record(zone['id'], '@', 'TXT')['rdata'] }
    it { should include '"v=spf1 -all"' }
    it { should include '"a value with \"quotes\" and spaces"' }
  end

  describe 'blog CNAME' do
    subject { api.record(zone['id'], 'blog', 'CNAME')['rdata'] }
    it { should eq ['www.example.net.'] }
  end
end

control 'noderings-firewall' do
  title 'The ruleset holds the four rules in order'
  ruleset = api.ruleset("#{id}-web")

  describe 'ruleset' do
    subject { ruleset }
    it { should_not be_nil }
  end

  next unless ruleset

  rules = api.rules(ruleset['id']).map { |r| r['rule'] }
  describe 'rules' do
    subject { rules.map { |r| [r['action'], r['protocol'], r['destinationPorts'].to_s] } }
    it {
      should eq [%w(FIREWALL_ACTION_ACCEPT FIREWALL_PROTOCOL_TCP 22), %w(FIREWALL_ACTION_ACCEPT FIREWALL_PROTOCOL_TCP 80),
                 %w(FIREWALL_ACTION_ACCEPT FIREWALL_PROTOCOL_TCP 443), ['FIREWALL_ACTION_ACCEPT', 'FIREWALL_PROTOCOL_ICMP', '']]
    }
  end
end
