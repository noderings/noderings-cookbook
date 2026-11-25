# frozen_string_literal: true

# Removes everything the other suites made.
include_recipe 'test::_common'

n = NodeRingsTest.names(node)

noderings_vm n[:vm] do
  action :delete
end

noderings_dns_zone n[:zone] do
  force_delete true
  action :delete
end

noderings_firewall_ruleset n[:ruleset] do
  force_delete true
  action :delete
end

noderings_ssh_key n[:key] do
  action :delete
end
