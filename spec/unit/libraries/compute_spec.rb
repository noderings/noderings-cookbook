# frozen_string_literal: true

require 'spec_helper'
load_noderings_libraries

describe NodeRingsCookbook::Compute do
  let(:fake) { FakeNodeRings.new }
  let(:client) { NodeRingsCookbook::Client.new(token: 't', transport: fake, sleeper: ->(_s) {}) }
  let(:compute) { described_class }

  it 'normalizes distro names' do
    expect(compute.normalize_distro('Ubuntu-24.04')).to eq 'ubuntu_24_04'
    expect(compute.distro_enum('DISTRO_DEBIAN_13')).to eq 'DISTRO_DEBIAN_13'
  end

  it 'picks the cheapest offer by its compute price' do
    plan_id, region_id, offer = compute.choose_offer(client, 'SC-GC-1C-1G-20', 'United States', 'Ashburn')
    expect([plan_id, region_id, offer['provider_name']]).to eq [FakeNodeRings::PLAN_ID, FakeNodeRings::REGION_ID, 'Cheap Host']
  end

  it 'picks the best rated offer on request, and filters by capability' do
    expect(compute.choose_offer(client, 'P', 'United States', 'Ashburn', sort: 'rating')[2]['provider_name']).to eq 'Dear Host'
    expect(compute.choose_offer(client, 'P', 'United States', 'Ashburn', sort: 'rating',
                                                                         require_capabilities: ['guest_firewall'])[2]['provider_name']).to eq 'Cheap Host'
  end

  context 'with a provider' do
    [FakeNodeRings::ACME_ID, 'acme-hosting', 'Acme Hosting', '  acme HOSTING '].each do |provider|
      it "orders from the provider given as #{provider.inspect}" do
        plan_id, region_id, offer = compute.choose_offer(client, 'SC-GC-1C-1G-20', 'United States', 'Ashburn',
                                                         provider: provider)
        expect([plan_id, region_id, offer['provider_name']]).to eq [FakeNodeRings::ACME_PLAN_ID, FakeNodeRings::ACME_REGION_ID, 'Acme Hosting']
      end
    end

    it 'takes the cheapest offer without one' do
      expect(compute.choose_offer(client, 'SC-GC-1C-1G-20', 'United States', 'Ashburn', provider: '').first).to eq FakeNodeRings::PLAN_ID
    end

    it 'prefers provider_id when both are given' do
      expect(compute.choose_offer(client, 'SC-GC-1C-1G-20', 'United States', 'Ashburn',
                                  provider_id: FakeNodeRings::ACME_ID, provider: 'Cheap Host').first).to eq FakeNodeRings::ACME_PLAN_ID
    end

    it 'fails for an unknown provider' do
      expect { compute.choose_offer(client, 'SC-GC-1C-1G-20', 'United States', 'Ashburn', provider: 'Nobody Hosting') }
        .to raise_error(NodeRingsCookbook::UsageError, /in Ashburn, United States from provider Nobody Hosting/)
    end

    it 'refuses a provider name two providers share' do
      fake.extra_providers << FakeNodeRings::ACME_OFFER.merge('organizationId' => '66666666-6666-6666-6666-666666666666')
      expect { compute.choose_offer(client, 'SC-GC-1C-1G-20', 'United States', 'Ashburn', provider: 'acme hosting') }
        .to raise_error(NodeRingsCookbook::UsageError, /more than one provider is named acme hosting; give its provider ID or storefront slug/)
    end

    it 'passes on storefront errors other than not found' do
      fake.failures['GET /v1/public/storefronts/acme-hosting'] = [403]
      expect { compute.choose_offer(client, 'SC-GC-1C-1G-20', 'United States', 'Ashburn', provider: 'acme-hosting') }
        .to raise_error(NodeRingsCookbook::APIError)
    end
  end

  it 'explains a missing offer' do
    expect { compute.choose_offer(client, 'P', 'United States', 'Nowhere') }
      .to raise_error(NodeRingsCookbook::UsageError, /No offer for plan code P in Nowhere/)
  end

  it 'orders a VM with an idempotency key and attaches the firewall' do
    rs = client.create_firewall_ruleset('web')
    vm = compute.order_vm(client, 'web-1', FakeNodeRings::PLAN_ID, FakeNodeRings::REGION_ID,
                          distro: 'debian-13', ssh_key_ids: ['k1'], tags: %w(b a), ruleset_id: rs['id'])
    body = fake.created_vm_bodies.last
    expect(body).to include('hostname' => 'web-1', 'distro' => 'DISTRO_DEBIAN_13', 'sshKeyIds' => ['k1'], 'tags' => %w(a b))
    expect(NodeRingsCookbook.uuid?(body['idempotencyKey'])).to be true
    expect(vm['firewallRulesetId']).to eq rs['id']
    expect(compute.view(vm)).to include('hostname' => 'web-1', 'ipv4' => '192.0.2.50', 'power_state' => 'running')
  end

  it 'retries a lost order with the same idempotency key' do
    fake.failures['POST /v1/virtual-machines'] = [502]
    compute.order_vm(client, 'web-1', FakeNodeRings::PLAN_ID, FakeNodeRings::REGION_ID, password: 'pw')
    keys = fake.calls.select { |c| c.first == 'POST' && c[1] == '/v1/virtual-machines' }.map { |c| c[3]['idempotencyKey'] }
    expect(keys.length).to eq 2
    expect(keys.uniq.length).to eq 1
    expect(fake.vms.length).to eq 1
  end

  it 'does not retry an order the API refused' do
    fake.failures['POST /v1/virtual-machines'] = [400]
    expect { compute.order_vm(client, 'web-1', 'p', 'r', password: 'pw') }.to raise_error(NodeRingsCookbook::UsageError, /ordering/)
  end

  it 'tags free orders with a nonce and removes it afterwards' do
    allow(client).to receive(:get_marketplace_plan).and_return('billingType' => 'BILLING_TYPE_FREE')
    vm = compute.order_vm(client, 'free-1', 'p', 'r', password: 'pw')
    expect(fake.created_vm_bodies.last['tags'].first).to start_with('noderings-create-')
    expect(vm['tags']).to be_empty
  end

  it 'finds VMs by hostname or ID and refuses ambiguous names' do
    vm = compute.order_vm(client, 'web-1', 'p', 'r', password: 'pw')
    expect(compute.find_vm(client, 'web-1')['id']).to eq vm['id']
    expect(compute.find_vm(client, vm['id'])['hostname']).to eq 'web-1'
    expect(compute.find_vm(client, '00000000-0000-0000-0000-000000000000')).to be_nil
    compute.order_vm(client, 'web-1', 'p', 'r', password: 'pw')
    expect { compute.find_vm(client, 'web-1') }.to raise_error(NodeRingsCookbook::UsageError, /2 virtual machines/)
  end

  it 'changes power state and reinstalls' do
    vm = compute.order_vm(client, 'web-1', 'p', 'r', password: 'pw')
    expect(compute.power_state(compute.set_power(client, vm['id'], 'stopped'))).to eq 'stopped'
    expect(compute.power_state(compute.set_power(client, vm['id'], 'restarted'))).to eq 'running'
    expect(compute.reinstall(client, vm['id'], 'web-1', 'debian_13')['distro']).to eq 'DISTRO_DEBIAN_13'
  end
end
