# frozen_string_literal: true

require 'spec_helper'

describe 'noderings_vm' do
  step_into :noderings_vm
  platform 'ubuntu'

  before do
    @fake.ssh_keys['k1'] = { 'id' => 'k1', 'name' => 'laptop', 'publicKey' => 'ssh-ed25519 AAAA laptop' }
    @fake.call('POST', 'https://api.noderings.com/v1/firewall/rulesets', {}, '{"ruleset":{"name":"web"}}', 1)
  end

  let(:ruleset_id) { @fake.rulesets.keys.first }

  def vm
    @fake.vms.values.first
  end

  def order_existing(distro = 'DISTRO_UBUNTU_24_04')
    body = { hostname: 'web-1', planId: 'p', regionId: 'r', distro: distro, tags: ['old'] }.to_json
    @fake.call('POST', 'https://api.noderings.com/v1/virtual-machines', {}, body, 1)
    @fake.calls.clear
  end

  context 'ordering a VM' do
    recipe do
      noderings_vm 'web-1' do
        plan 'SC-GC-1C-1G-20'
        country 'United States'
        city 'Ashburn'
        distro 'debian-13'
        ssh_keys ['laptop']
        tags %w(web chef)
        firewall_ruleset 'web'
      end
    end

    it 'orders the cheapest offer and publishes the VM' do
      chef_run
      body = @fake.created_vm_bodies.last
      expect(body).to include('hostname' => 'web-1', 'planId' => FakeNodeRings::PLAN_ID, 'regionId' => FakeNodeRings::REGION_ID,
                              'distro' => 'DISTRO_DEBIAN_13', 'sshKeyIds' => ['k1'], 'tags' => %w(chef web))
      expect(vm['firewallRulesetId']).to eq ruleset_id
      published = chef_run.node.run_state['noderings']['vms']['web-1']
      expect(published).to include('id' => vm['id'], 'ipv4' => '192.0.2.50', 'power_state' => 'running')
    end
  end

  context 'an existing VM' do
    before { order_existing }

    recipe do
      noderings_vm 'web-1' do
        plan 'SC-GC-1C-1G-20'
        country 'United States'
        city 'Ashburn'
        tags %w(web)
        firewall_ruleset 'web'
        power_state 'stopped'
      end
    end

    it 'converges tags, firewall and power without ordering again' do
      chef_run
      expect(@fake.created_vm_bodies.length).to eq 1
      expect(vm).to include('tags' => ['web'], 'firewallRulesetId' => ruleset_id, 'operationStatus' => 'OPERATION_STATUS_STOPPED')
    end
  end

  context 'an existing VM that already matches' do
    before { order_existing }

    recipe do
      noderings_vm 'web-1' do
        tags %w(old)
        distro 'ubuntu_24_04'
        power_state 'running'
      end
    end

    it 'changes nothing' do
      chef_run
      expect(@fake.writes).to be_empty
      expect(chef_run.noderings_vm('web-1')).not_to be_updated
    end
  end

  context 'a different distro' do
    before { order_existing }

    recipe do
      noderings_vm 'web-1' do
        distro 'debian_13'
      end
    end

    it('refuses to erase the disk silently') do
      expect { chef_run }.to raise_error(/only done with allow_reinstall true/)
      expect(@fake.writes).to be_empty
    end
  end

  context 'a different distro with allow_reinstall' do
    before { order_existing }

    recipe do
      noderings_vm 'web-1' do
        distro 'debian_13'
        ssh_keys ['laptop']
        allow_reinstall true
      end
    end

    it 'reinstalls' do
      chef_run
      expect(vm['distro']).to eq 'DISTRO_DEBIAN_13'
      expect(@fake.calls.find { |c| c[1].end_with?(':reinstall') }[3]).to include('sshKeyIds' => ['k1'])
    end
  end

  context 'a missing VM without an offer' do
    recipe do
      noderings_vm 'web-1'
    end

    it('explains what is needed') { expect { chef_run }.to raise_error(/give plan, country and city/) }
  end

  context 'a missing VM without a way to log in' do
    recipe do
      noderings_vm 'web-1' do
        plan_id 'p'
        region_id 'r'
      end
    end

    it('refuses to order') do
      expect { chef_run }.to raise_error(/needs ssh_keys or a password/)
      expect(@fake.created_vm_bodies).to be_empty
    end
  end

  context 'power actions' do
    before { order_existing }

    recipe do
      noderings_vm('stop web-1') do
        hostname 'web-1'
        action :stop
      end
      noderings_vm('restart web-1') do
        hostname 'web-1'
        action :restart
      end
    end

    it 'stops and restarts' do
      chef_run
      expect(@fake.writes.map(&:last)).to eq ["/v1/virtual-machines/#{vm['id']}:stop", "/v1/virtual-machines/#{vm['id']}:restart"]
      expect(vm['operationStatus']).to eq 'OPERATION_STATUS_STARTED'
    end
  end

  context 'deleting' do
    before { order_existing }

    recipe do
      noderings_vm 'web-1' do
        action :delete
      end
    end

    it 'deletes the VM and waits until it is gone' do
      chef_run
      expect(@fake.vms).to be_empty
    end
  end

  context 'why-run' do
    before { order_existing }

    recipe do
      noderings_vm 'web-1' do
        tags %w(new)
      end
    end

    it 'reports the change without making it' do
      Chef::Config[:why_run] = true
      chef_run
      expect(@fake.writes).to be_empty
    ensure
      Chef::Config[:why_run] = false
    end
  end
end
