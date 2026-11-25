# frozen_string_literal: true

require 'spec_helper'

describe 'noderings_firewall_ruleset' do
  step_into :noderings_firewall_ruleset
  platform 'ubuntu'

  RULES = [
    { direction: 'ingress', action: 'accept', destination_ports: '22', source: { cidrs: ['0.0.0.0/0'] } },
    { 'direction' => 'ingress', 'action' => 'accept', 'destination_ports' => '443', 'source' => { 'address_groups' => ['office'] } },
  ].freeze

  before { @fake.groups['g1'] = { 'id' => 'G1', 'name' => 'office' } }

  context 'creating' do
    recipe do
      noderings_firewall_ruleset 'web' do
        rules RULES
      end
    end

    it 'creates the ruleset with its rules in order' do
      chef_run
      rs_id = @fake.rulesets.keys.first
      rules = @fake.rules[rs_id].map { |r| r['rule'] }
      expect(rules.map { |r| r['destinationPorts'] }).to eq %w(22 443)
      expect(rules.last['source']).to eq('addressGroupIds' => { 'addressGroupIds' => ['g1'] })
      expect(chef_run.node.run_state['noderings']['firewall_rulesets']['web']['id']).to eq rs_id
    end

    it 'changes nothing on the second run' do
      chef_run
      @fake.calls.clear
      ChefSpec::SoloRunner.new(platform: 'ubuntu', step_into: ['noderings_firewall_ruleset']).converge_block do
        noderings_firewall_ruleset('web') { rules RULES }
      end
      expect(@fake.writes).to be_empty
    end
  end

  context 'an unknown address group' do
    recipe do
      noderings_firewall_ruleset 'web' do
        rules [{ direction: 'ingress', action: 'accept', source: { address_groups: ['nope'] } }]
      end
    end

    it('fails clearly') { expect { chef_run }.to raise_error(/no NodeRings firewall address group is named nope/) }
  end

  context 'an invalid rule' do
    recipe do
      noderings_firewall_ruleset 'web' do
        rules [{ direction: 'ingress', action: 'accept', destination_ports: '80,443', source: { cidrs: ['0.0.0.0/0'] } }]
      end
    end

    it('fails before calling the API') do
      expect { chef_run }.to raise_error(/one port such as 443/)
      expect(@fake.writes).to be_empty
    end
  end

  context 'deleting' do
    before { @fake.call('POST', 'https://api.noderings.com/v1/firewall/rulesets', {}, '{"ruleset":{"name":"web"}}', 1) }

    recipe do
      noderings_firewall_ruleset 'web' do
        force_delete true
        action :delete
      end
    end

    it 'removes it' do
      chef_run
      expect(@fake.rulesets).to be_empty
      expect(@fake.calls.last[2]).to eq('force' => 'true')
    end
  end
end
