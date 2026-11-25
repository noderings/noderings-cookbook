# Testing

## Lint and unit tests

```shell
cookstyle
chef exec rspec        # or: cinc exec rspec
```

The unit tests converge every resource with ChefSpec against an in-memory
NodeRings API (`spec/support/fake_noderings.rb`), so they need no token and make
no network calls.

## Integration tests

The suites in `test/cookbooks/test` call the real NodeRings API, and InSpec
checks the result through the API (`test/integration`). They create objects
named after `NODERINGS_TEST_ID`, so give concurrent runs different IDs.

| Suite | What it does | Cost |
| --- | --- | --- |
| `default` | SSH key, DNSSEC-signed zone with A, MX, TXT and CNAME records, a four-rule firewall ruleset | free |
| `vm` | orders a VM with the key, tags and firewall, points a DNS record at it, stops and starts it | billed, needs `NODERINGS_TEST_BILLED=1` |
| `cleanup` | deletes everything the other suites made, and checks it is gone | free |

Every suite converges twice and fails if the second run changes anything.

```shell
export NODERINGS_TOKEN=...          # a service account token
export NODERINGS_TEST_ID=ci-1234    # optional, names the test objects
export NODERINGS_TEST_BILLED=1      # optional, adds the vm suite
```

Run the suites on this machine (what CI does):

```shell
KITCHEN_LOCAL_YAML=kitchen.exec.yml kitchen test
```

Or on NodeRings virtual machines with
[kitchen-noderings](https://github.com/noderings/kitchen-noderings):

```shell
chef gem install kitchen-noderings
kitchen test
```
