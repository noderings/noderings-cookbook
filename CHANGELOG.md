# Changelog

This file is used to list changes made in each version of the noderings cookbook.

## Unreleased

## 0.1.0 - *2026-11-25*

Initial release.

* `noderings_vm`: order a virtual machine from the NodeRings marketplace, converge
  its distro (with `allow_reinstall`), tags, firewall ruleset and power state,
  and start, stop, restart, reinstall or delete it. Orders carry an
  idempotency key.
* `noderings_dns_zone`: DNS zones with optional DNSSEC signing; publishes the
  nameservers and DS record.
* `noderings_dns_record`: record sets of every supported type, with TXT quoting
  and value validation.
* `noderings_firewall_ruleset`: ordered firewall rules, reconciled in place.
* `noderings_ssh_key`: SSH public keys for new virtual machines.
* Results published in `node.run_state['noderings']`; why-run support; the API
  token can come from a property, `node.run_state` or the environment.
