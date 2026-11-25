# frozen_string_literal: true

# A billed VM behind a firewall, with a DNS record that points at it.
include_recipe 'test::default'

n = NodeRingsTest.names(node)
t = node['noderings_test']

noderings_vm n[:vm] do
  plan t['plan']
  country t['country']
  city t['city']
  distro 'ubuntu-24.04'
  ssh_keys [n[:key]]
  tags %w(kitchen chef)
  firewall_ruleset n[:ruleset]
  power_state 'running'
end

noderings_dns_record 'vm' do
  zone n[:zone]
  type 'A'
  values(lazy { node.run_state['noderings']['vms'][n[:vm]]['ipv4'] })
  ttl 300
end

# Stop and start it once. A marker file keeps the second converge (the
# idempotency check) from cycling it again; then :start has nothing to do.
marker = ::File.join(t['key_dir'], "#{n[:vm]}.power-cycled")

noderings_vm "stop #{n[:vm]}" do
  hostname n[:vm]
  action :stop
  not_if { ::File.exist?(marker) }
end

noderings_vm "start #{n[:vm]}" do
  hostname n[:vm]
  action :start
end

file marker do
  content "stopped and started\n"
end
