# noderings_vm

[Back to resource list](../README.md#resources)

Manages a NodeRings virtual machine. `:create` orders one from the marketplace
when no VM has the hostname, and keeps an existing one's tags, firewall ruleset
and power state as declared. Ordering is billed to the organization.

Introduced: v0.1.0

## Actions

| Action | Description |
| --- | --- |
| `:create` | Default. Orders the VM if it does not exist, then converges `distro`, `tags`, `firewall_ruleset` and `power_state`. |
| `:delete` | Deletes the VM and waits until it is gone. An hourly VM stops billing; a monthly subscription is cancelled without a refund. |
| `:start` | Starts the VM if it is stopped. |
| `:stop` | Stops the VM if it is running. The disk and IP addresses are kept. |
| `:restart` | Restarts the VM. Always reports a change. |
| `:reinstall` | Reinstalls the VM with `distro`. Erases the disk; the IP addresses are kept. |

## Properties

The [API properties](partial_api.md) also apply.

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `hostname` | String | resource name | Hostname. It identifies the VM, so keep it unique in the organization. |
| `plan` | String | | Plan code to order, such as `SC-GC-1C-1G-20`. |
| `country` | String | | Country of the offer, such as `United States`. |
| `city` | String | | City of the offer, such as `Ashburn`. |
| `billing_type` | String | `usage` | `usage` (hourly), `subscription` (monthly) or `free`. |
| `sort` | String | `price` | Order the cheapest matching offer, or the best rated with `rating`. |
| `provider_id` | String | | Only consider offers from this provider. |
| `require_capabilities` | Array | `[]` | Only consider providers with these capabilities, such as `guest_firewall`. |
| `require_ipv6` | true, false | `false` | Only consider offers with IPv6. |
| `plan_id`, `region_id` | String | | An exact plan and region, instead of `plan`, `country` and `city`. |
| `distro` | String | `ubuntu_24_04` for new VMs | Operating system, such as `ubuntu_24_04`, `debian-13` or `rocky_9`. On an existing VM, see below. |
| `ssh_keys` | Array | `[]` | Names or IDs of stored [SSH keys](noderings_ssh_key.md) to install. A new VM needs SSH keys or a password. |
| `password` | String | | Root password for a new VM. Sensitive. |
| `tags` | Array | not managed | Tags of the VM. |
| `firewall_ruleset` | String | not managed | Name or ID of the [ruleset](noderings_firewall_ruleset.md) to attach. `''` detaches it. |
| `power_state` | String | not managed | `running` or `stopped`. |
| `allow_reinstall` | true, false | `false` | Reinstall an existing VM whose distro differs. Reinstalling erases the disk. |
| `wait` | true, false | `true` | Wait for orders and power changes to finish. |
| `wait_timeout` | Integer | `900` | Seconds to wait for each operation. |

To order, give `plan`, `country` and `city`; the resource orders the cheapest
offer that matches (or the best rated with `sort 'rating'`). Find what is sold in
the NodeRings console marketplace, or with
`knife noderings plan list` from [knife-noderings](https://github.com/noderings/knife-noderings).

The order carries an idempotency key, so a lost response is retried without
ordering twice.

The plan of an existing VM is not changed; a different `plan` only logs a
warning. A different `distro` fails the run unless `allow_reinstall` is true,
because reinstalling erases the disk.

After every action, `node.run_state['noderings']['vms'][hostname]` holds `id`,
`ipv4`, `ipv6`, `power_state`, `distro`, `plan_code`, `plan_id`, `region_id`,
`billing_type`, `provisioning_status`, `firewall_ruleset_id` and `tags`.

## Examples

```ruby
noderings_vm 'web-1' do
  plan 'SC-GC-1C-1G-20'
  country 'United States'
  city 'Ashburn'
  distro 'debian_13'
  ssh_keys ['deploy']
  tags %w(web production)
  firewall_ruleset 'web'
end

noderings_dns_record 'web-1' do
  zone 'example.com'
  type 'A'
  values(lazy { node.run_state['noderings']['vms']['web-1']['ipv4'] })
end
```

```ruby
noderings_vm 'batch-1' do
  power_state 'stopped'
end

noderings_vm 'web-1' do
  distro 'ubuntu_26_04'
  ssh_keys ['deploy']
  action :reinstall
end

noderings_vm 'old-1' do
  action :delete
end
```
