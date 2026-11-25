# noderings_firewall_ruleset

[Back to resource list](../README.md#resources)

Manages a NodeRings firewall ruleset and its ordered rules. The ruleset holds
exactly the rules given, in order: rules that are not listed are removed. Attach a
ruleset to a virtual machine with the `firewall_ruleset` property of
[noderings_vm](noderings_vm.md).

Introduced: v0.1.0

## Actions

| Action | Description |
| --- | --- |
| `:create` | Default. Creates the ruleset and makes its rules match. |
| `:delete` | Deletes the ruleset. A ruleset still attached to virtual machines needs `force_delete true`. |

## Properties

The [API properties](partial_api.md) also apply.

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `ruleset_name` | String | resource name | Name of the ruleset. |
| `rules` | Array | `[]` | Ordered rules, at most 50. See below. |
| `force_delete` | true, false | `false` | With `:delete`, also delete a ruleset that is still attached. |

### Rules

Each rule is a Hash with string or symbol keys:

| Key | Description |
| --- | --- |
| `direction` | `ingress` or `egress`. Required. |
| `action` | `accept` or `drop`. Required. |
| `protocol` | `tcp` (default), `udp`, `icmp`, `icmpv6`, `any`, or another IP protocol name. |
| `source`, `destination` | Each a Hash with any of `cidrs` (addresses or CIDR blocks), `address_groups` (names), `address_group_ids` and `vm_tags`. A rule needs at least one of the two. |
| `source_ports`, `destination_ports` | One port (`443`) or one range (`8000-8100`), for `tcp`, `udp`, `sctp`, `dccp` and `udplite`. |

To match every IPv4 address use `cidrs: ['0.0.0.0/0']`, and every IPv6 address
`cidrs: ['::/0']`. Each must be the only entry on its side, so matching both takes
two rules.

Rules are validated before any API call. When rules change, the resource keeps
rules that already match, updates changed ones in place, creates and deletes the
rest, and moves them into order, so rule IDs stay stable where possible.

The ruleset's ID is published in `node.run_state['noderings']['firewall_rulesets'][ruleset_name]['id']`.

## Examples

```ruby
noderings_firewall_ruleset 'web' do
  rules [
    { direction: 'ingress', action: 'accept', protocol: 'tcp', destination_ports: '22', source: { cidrs: ['198.51.100.0/24'] } },
    { direction: 'ingress', action: 'accept', protocol: 'tcp', destination_ports: '443', source: { cidrs: ['0.0.0.0/0'] } },
    { direction: 'ingress', action: 'accept', protocol: 'tcp', destination_ports: '443', source: { cidrs: ['::/0'] } },
    { direction: 'ingress', action: 'accept', protocol: 'icmp', source: { address_groups: ['office'] } },
    { direction: 'ingress', action: 'drop', protocol: 'any', source: { cidrs: ['0.0.0.0/0'] } },
  ]
end
```
