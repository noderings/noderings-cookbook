# noderings cookbook

[![Cookbook Version](https://img.shields.io/cookbook/v/noderings.svg)](https://supermarket.chef.io/cookbooks/noderings)
[![CI](https://github.com/noderings/noderings-cookbook/actions/workflows/ci.yml/badge.svg)](https://github.com/noderings/noderings-cookbook/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](https://opensource.org/licenses/Apache-2.0)

Custom resources to manage [NodeRings](https://noderings.com) from Chef Infra:
virtual machines ordered from the NodeRings marketplace, DNS zones and records,
firewall rulesets and SSH keys.

New to it? The step-by-step guide [How to use Chef on a NodeRings VPS: cookbook, knife and Test Kitchen](https://noderings.com/blog/chef-vps) walks through a first run.

```ruby
noderings_ssh_key 'deploy' do
  public_key ::File.read('/home/deploy/.ssh/id_ed25519.pub')
end

noderings_firewall_ruleset 'web' do
  rules [
    { direction: 'ingress', action: 'accept', protocol: 'tcp', destination_ports: '22', source: { cidrs: ['198.51.100.0/24'] } },
    { direction: 'ingress', action: 'accept', protocol: 'tcp', destination_ports: '443', source: { cidrs: ['0.0.0.0/0'] } },
  ]
end

noderings_vm 'web-1' do
  plan 'SC-GC-1C-1G-20'
  country 'United States'
  city 'Ashburn'
  distro 'ubuntu_24_04'
  ssh_keys ['deploy']
  firewall_ruleset 'web'
end

noderings_dns_zone 'example.com'

noderings_dns_record 'www' do
  zone 'example.com'
  type 'A'
  values(lazy { node.run_state['noderings']['vms']['web-1']['ipv4'] })
  ttl 300
end
```

The resources call the NodeRings API, so they can run on any node: a workstation
with `chef-client --local-mode`, a management node, or a CI runner. They use the
Ruby standard library only and install nothing on the node.

## Installation

The cookbook is on [Chef Supermarket](https://supermarket.chef.io/cookbooks/noderings).
Add it as a dependency in a wrapper cookbook's `metadata.rb`:

```ruby
depends 'noderings'
```

With Berkshelf, in the `Berksfile`:

```ruby
source 'https://supermarket.chef.io'
cookbook 'noderings'
```

With a Policyfile:

```ruby
default_source :supermarket
cookbook 'noderings'
```

## Requirements

### Chef Infra Client

* Chef Infra Client 17 or later, or Cinc Client 17 or later

### Platforms

The resources only make HTTPS calls, so they run on every platform Chef Infra
supports: Linux distributions, macOS and Windows.

### NodeRings

* A service account token. Create one in the NodeRings console under
  **Organization → Access Control → Service accounts**, with the permissions for
  the resources you use.
* For `noderings_vm`: a payment method or credit on the organization. Ordering a
  virtual machine is billed.

## Credentials

Each resource takes the token from, in order:

1. its `api_token` property,
2. `node.run_state['noderings_api_token']`,
3. the `NODERINGS_TOKEN` environment variable (also `NODERINGS_API_TOKEN` or `NR_API_TOKEN`).

Keep the token out of node attributes, which are saved to the Chef Infra Server.
Load it from an encrypted source at the start of the run instead, for example
with [chef-vault](https://github.com/chef/chef-vault):

```ruby
node.run_state['noderings_api_token'] = chef_vault_item('secrets', 'noderings')['token']
```

`api_url` and `organization_id` work the same way, with the `NODERINGS_API_URL`
and `NODERINGS_ORGANIZATION_ID` environment variables.

## Resources

* [noderings_vm](documentation/noderings_vm.md): orders, configures, powers and deletes a virtual machine
* [noderings_dns_zone](documentation/noderings_dns_zone.md): a DNS zone, optionally signed with DNSSEC
* [noderings_dns_record](documentation/noderings_dns_record.md): the records of one name and type
* [noderings_firewall_ruleset](documentation/noderings_firewall_ruleset.md): a firewall ruleset and its ordered rules
* [noderings_ssh_key](documentation/noderings_ssh_key.md): an SSH public key for new virtual machines

All resources share the [API properties](documentation/partial_api.md) and
support why-run mode (`chef-client --why-run`), which reports what would change
without calling any write endpoint.

## Using what a resource created

Resources publish what they learned, such as IDs and IP addresses, in
`node.run_state['noderings']`, keyed by kind and name:

| Key | Contents |
| --- | --- |
| `['vms'][hostname]` | `id`, `ipv4`, `ipv6`, `power_state`, `distro`, `plan_code`, `billing_type`, `firewall_ruleset_id`, `tags` |
| `['dns_zones'][zone]` | `id`, `nameservers` (to set at your registrar), `state`, `dnssec_mode`, `ds` |
| `['firewall_rulesets'][name]` | `id` |
| `['ssh_keys'][name]` | `id` |

Read them with `lazy` in later resources, as in the DNS record above.

## Testing

See [TESTING.md](TESTING.md). In short: `cookstyle`, `chef exec rspec` for the
unit tests (no token needed), and Test Kitchen for the integration suites,
which call the real API.

## Related projects

* [knife-noderings](https://github.com/noderings/knife-noderings): order a NodeRings server and bootstrap Chef on it with knife
* [kitchen-noderings](https://github.com/noderings/kitchen-noderings): run Test Kitchen instances on NodeRings servers

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Copyright NodeRings. Licensed under the [Apache License, Version 2.0](LICENSE).
