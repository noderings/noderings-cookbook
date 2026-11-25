# noderings_dns_record

[Back to resource list](../README.md#resources)

Manages the records of one name and type in a NodeRings DNS zone, as one set:
the values given replace whatever the set held.

Introduced: v0.1.0

## Actions

| Action | Description |
| --- | --- |
| `:create` | Default. Creates or replaces the record set. |
| `:delete` | Deletes the record set. |

## Properties

The [API properties](partial_api.md) also apply.

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `record_name` | String | resource name | Name relative to the zone, such as `www`, or `@` for the apex. A full name inside the zone (`www.example.com.`) also works. |
| `zone` | String | | Name or ID of the zone, which must already exist. Required. |
| `type` | String | | Record type. Required. One of `A`, `AAAA`, `ALIAS`, `CAA`, `CERT`, `CNAME`, `DNAME`, `DS`, `HINFO`, `HTTPS`, `LOC`, `MX`, `NAPTR`, `NS`, `OPENPGPKEY`, `PTR`, `RP`, `SMIMEA`, `SRV`, `SSHFP`, `SVCB`, `TLSA`, `TXT`. |
| `values` | String, Array | | Record values. Required for `:create`. |
| `ttl` | Integer | `3600` | Time to live in seconds, from 30 to 86400. |

Values are checked before any API call: `A` takes IPv4 addresses, `AAAA` IPv6
addresses, and `CNAME`, `DNAME` and `ALIAS` exactly one hostname. Write hostnames
with a trailing dot. TXT values are plain text: the resource quotes them and
splits long values into 255-byte strings, so do not add quotes yourself.

Comparison ignores order, case in hostnames and trailing dots, so a converge only
writes when the record set really differs.

## Examples

```ruby
noderings_dns_record 'www' do
  zone 'example.com'
  type 'A'
  values %w(192.0.2.10 192.0.2.11)
  ttl 300
end

noderings_dns_record 'mail' do
  record_name '@'
  zone 'example.com'
  type 'MX'
  values ['10 mx1.example.net.', '20 mx2.example.net.']
end

noderings_dns_record 'spf' do
  record_name '@'
  zone 'example.com'
  type 'TXT'
  values 'v=spf1 include:_spf.example.net -all'
end

noderings_dns_record 'old' do
  zone 'example.com'
  type 'CNAME'
  action :delete
end
```
