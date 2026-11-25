# noderings_ssh_key

[Back to resource list](../README.md#resources)

Manages an SSH public key stored in a NodeRings organization. `noderings_vm`
installs stored keys on new virtual machines.

Introduced: v0.1.0

## Actions

| Action | Description |
| --- | --- |
| `:create` | Default. Stores the key. A key with the same name but different key material is replaced. |
| `:delete` | Deletes the key. Virtual machines that already have it keep it. |

## Properties

The [API properties](partial_api.md) also apply.

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `key_name` | String | resource name | Name of the key in NodeRings. |
| `public_key` | String | | The OpenSSH public key, such as the contents of `id_ed25519.pub`. Required for `:create`. Only the key type and body are compared; the comment is ignored. |

NodeRings keeps each public key once. Storing a key that already exists under
another name fails with a message naming the problem.

The key's ID is published in `node.run_state['noderings']['ssh_keys'][key_name]['id']`.

## Examples

```ruby
noderings_ssh_key 'deploy' do
  public_key ::File.read('/home/deploy/.ssh/id_ed25519.pub')
end

noderings_ssh_key 'old-laptop' do
  action :delete
end
```
