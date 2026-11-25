# frozen_string_literal: true

# Free objects: an SSH key, a DNS zone with records, and a firewall ruleset.
include_recipe 'test::_common'

n = NodeRingsTest.names(node)

noderings_ssh_key n[:key] do
  public_key NodeRingsTest.public_key(node['noderings_test']['key_dir'], n[:key])
end

noderings_dns_zone n[:zone] do
  dnssec true
end

noderings_dns_record 'www' do
  zone n[:zone]
  type 'A'
  values %w(192.0.2.10 192.0.2.11)
  ttl 300
end

noderings_dns_record '@' do
  zone n[:zone]
  type 'MX'
  values ['10 mx1.example.net.', '20 mx2.example.net.']
end

noderings_dns_record 'apex-txt' do
  record_name '@'
  zone n[:zone]
  type 'TXT'
  values ['v=spf1 -all', 'a value with "quotes" and spaces']
end

noderings_dns_record "blog.#{n[:zone]}." do
  zone n[:zone]
  type 'CNAME'
  values 'www.example.net.'
end

noderings_firewall_ruleset n[:ruleset] do
  rules [
    { direction: 'ingress', action: 'accept', protocol: 'tcp', destination_ports: '22',
      source: { cidrs: ['0.0.0.0/0'] } },
    { direction: 'ingress', action: 'accept', protocol: 'tcp', destination_ports: '80',
      source: { cidrs: ['0.0.0.0/0'] } },
    { direction: 'ingress', action: 'accept', protocol: 'tcp', destination_ports: '443',
      source: { cidrs: ['::/0'] } },
    { direction: 'ingress', action: 'accept', protocol: 'icmp', source: { cidrs: ['10.0.0.0/8', '192.168.0.0/16'] } },
  ]
end
