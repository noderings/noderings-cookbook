# frozen_string_literal: true

require 'spec_helper'
load_noderings_libraries

describe NodeRingsCookbook::Firewall do
  let(:fw) { described_class }
  let(:ssh) { { 'direction' => 'ingress', 'action' => 'accept', 'destination_ports' => '22', 'source' => { 'cidrs' => ['0.0.0.0/0'] } } }

  it 'accepts a valid rule' do
    expect(fw.validate_rule(ssh, 0)).to be_nil
  end

  it 'explains invalid rules' do
    expect(fw.validate_rule(ssh.merge('protocol' => 'nope'), 1)).to match(/unknown protocol/)
    expect(fw.validate_rule(ssh.merge('source' => {}), 1)).to match(/needs a source or destination/)
    expect(fw.validate_rule(ssh.merge('destination_ports' => '80,443'), 1)).to match(/one port/)
    expect(fw.validate_rule(ssh.merge('protocol' => 'icmp'), 1)).to match(/has no ports/)
    expect(fw.validate_rule(ssh.merge('source' => { 'cidrs' => ['0.0.0.0/0', '::/0'] }), 1)).to match(/only entry/)
    expect(fw.validate_rule(ssh.merge('source' => { 'cidrs' => ['300.1.1.1'] }), 1)).to match(/not an IP/)
    expect(fw.validate_rule(ssh.merge('direction' => 'inbound'), 1)).to match(/direction/)
  end

  it 'converts rules to the API form and back' do
    body = fw.rule_to_api(fw.stringify(direction: 'ingress', action: 'accept', protocol: 'tcp',
                                       destination_ports: '443', source: { cidrs: ['10.1.2.3/8'] }))
    expect(body).to eq('action' => 'FIREWALL_ACTION_ACCEPT', 'protocol' => 'FIREWALL_PROTOCOL_TCP',
                       'direction' => 'FIREWALL_DIRECTION_INGRESS', 'destinationPorts' => '443',
                       'source' => { 'ips' => { 'ips' => ['10.0.0.0/8'] } })
    expect(fw.rule_view(body)).to eq('direction' => 'ingress', 'action' => 'accept', 'protocol' => 'tcp',
                                     'source' => { 'cidrs' => ['10.0.0.0/8'] }, 'destination_ports' => '443')
  end

  context 'reconciling against the API' do
    let(:fake) { FakeNodeRings.new }
    let(:client) { NodeRingsCookbook::Client.new(token: 't', transport: fake, sleeper: ->(_s) {}) }
    let(:rs) { client.create_firewall_ruleset('web') }

    def rule(port)
      fw.rule_to_api('direction' => 'ingress', 'action' => 'accept', 'destination_ports' => port.to_s,
                     'source' => { 'cidrs' => ['0.0.0.0/0'] })
    end

    def ports
      client.list_firewall_rules(rs['id']).map { |r| r['rule']['destinationPorts'] }
    end

    it 'creates rules in order, then reorders, updates and deletes them' do
      fw.reconcile(client, rs['id'], [rule(22), rule(80), rule(443)])
      expect(ports).to eq %w(22 80 443)
      ids = client.list_firewall_rules(rs['id']).map { |r| r['id'] }

      fw.reconcile(client, rs['id'], [rule(443), rule(22), rule(80)])
      expect(ports).to eq %w(443 22 80)
      expect(client.list_firewall_rules(rs['id']).map { |r| r['id'] }).to match_array ids

      fw.reconcile(client, rs['id'], [rule(443), rule(8080)])
      expect(ports).to eq %w(443 8080)

      expect(fw.rules_differ?(client.list_firewall_rules(rs['id']), [rule(443), rule(8080)])).to be false
      expect(fw.rules_differ?(client.list_firewall_rules(rs['id']), [rule(8080), rule(443)])).to be true
    end
  end
end
