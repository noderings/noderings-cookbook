# frozen_string_literal: true

require 'spec_helper'

describe 'noderings_dns_zone and noderings_dns_record' do
  step_into :noderings_dns_zone, :noderings_dns_record
  platform 'ubuntu'

  def zone_id
    @fake.zones.keys.first
  end

  context 'a zone with records' do
    recipe do
      noderings_dns_zone 'Example.com.' do
        dnssec true
      end

      noderings_dns_record 'www' do
        zone 'example.com'
        type 'a'
        values %w(192.0.2.10 192.0.2.11)
        ttl 300
      end

      noderings_dns_record 'apex txt' do
        record_name 'example.com.'
        zone 'example.com'
        type 'TXT'
        values 'v=spf1 -all'
      end

      noderings_dns_record 'blog' do
        zone 'example.com'
        type 'CNAME'
        values 'WWW.example.net.'
      end
    end

    it 'creates the zone, signs it and writes the records' do
      chef_run
      expect(@fake.zones.values.first).to include('name' => 'example.com', 'dnssecMode' => 'DNSSEC_MODE_SIGNED_DS_PENDING')
      expect(@fake.records[zone_id][%w(www A)]).to eq('ttl' => 300, 'rdata' => %w(192.0.2.10 192.0.2.11))
      expect(@fake.records[zone_id][%w(@ TXT)]['rdata']).to eq ['"v=spf1 -all"']
      zone = chef_run.node.run_state['noderings']['dns_zones']['example.com']
      expect(zone['nameservers']).to eq %w(ans1.nrings.io ans2.nrings.io)
      expect(zone['ds']).to eq '12345 13 2 abcdef'
    end

    it 'changes nothing on the second run' do
      chef_run
      @fake.calls.clear
      runner = ChefSpec::SoloRunner.new(platform: 'ubuntu', step_into: %w(noderings_dns_zone noderings_dns_record))
      runner.converge_block do
        noderings_dns_zone('example.com') { dnssec true }
        noderings_dns_record 'www' do
          zone 'example.com'
          type 'A'
          values %w(192.0.2.11 192.0.2.10)
          ttl 300
        end
        noderings_dns_record 'blog' do
          zone 'example.com'
          type 'CNAME'
          values 'www.example.net'
        end
      end
      expect(@fake.writes).to be_empty
    end
  end

  context 'a changed record' do
    before do
      @fake.call('POST', 'https://api.noderings.com/v1/dns/zones', {}, '{"name":"example.com"}', 1)
      @fake.records[zone_id][%w(www A)] = { 'ttl' => 3600, 'rdata' => ['192.0.2.1'] }
    end

    recipe do
      noderings_dns_record 'www' do
        zone 'example.com'
        type 'A'
        values '192.0.2.2'
      end
    end

    it 'replaces the values' do
      chef_run
      expect(@fake.records[zone_id][%w(www A)]['rdata']).to eq ['192.0.2.2']
    end
  end

  context 'deleting' do
    before do
      @fake.call('POST', 'https://api.noderings.com/v1/dns/zones', {}, '{"name":"example.com"}', 1)
      @fake.records[zone_id][%w(www A)] = { 'ttl' => 3600, 'rdata' => ['192.0.2.1'] }
    end

    recipe do
      noderings_dns_record 'www' do
        zone 'example.com'
        type 'A'
        action :delete
      end
      noderings_dns_zone 'example.com' do
        action :delete
      end
    end

    it 'removes the record, then the empty zone' do
      chef_run
      expect(@fake.zones).to be_empty
    end
  end

  context 'invalid input' do
    recipe do
      noderings_dns_zone 'example.com'
      noderings_dns_record 'www' do
        zone 'example.com'
        type 'A'
        values '2001:db8::1'
      end
    end

    it('fails before calling the API') { expect { chef_run }.to raise_error(/not an IPv4 address/) }
  end

  context 'a record in a missing zone' do
    recipe do
      noderings_dns_record 'www' do
        zone 'nope.example'
        type 'A'
        values '192.0.2.1'
      end
    end

    it('says the zone is missing') { expect { chef_run }.to raise_error(/nope.example does not exist/) }
  end
end
