# noderings_dns_zone

[Back to resource list](../README.md#resources)

Manages a DNS zone hosted on NodeRings, and optionally its DNSSEC signing.

Introduced: v0.1.0

## Actions

| Action | Description |
| --- | --- |
| `:create` | Default. Creates the zone, and signs or unsigns it when `dnssec` is set. |
| `:delete` | Deletes the zone. A zone that still has records needs `force_delete true`. |

## Properties

The [API properties](partial_api.md) also apply.

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `zone_name` | String | resource name | The domain, such as `example.com`. Case and a trailing dot are ignored. |
| `dnssec` | true, false | not managed | `true` signs the zone with DNSSEC, `false` removes signing. Left unset, signing is not changed. |
| `force_delete` | true, false | `false` | With `:delete`, also delete a zone that still has records. |

After `:create`, `node.run_state['noderings']['dns_zones'][zone_name]` holds:

* `id`
* `nameservers`: the nameservers to set at your registrar
* `state`: such as `pending_ns` until the registrar points at them
* `dnssec_mode`
* `ds`: the DS record to publish at the registrar for a signed zone

## Examples

```ruby
noderings_dns_zone 'example.com' do
  dnssec true
end

log 'registrar' do
  message(lazy { "Set the nameservers of example.com to #{node.run_state['noderings']['dns_zones']['example.com']['nameservers'].join(', ')}" })
end
```

```ruby
noderings_dns_zone 'old.example' do
  force_delete true
  action :delete
end
```
