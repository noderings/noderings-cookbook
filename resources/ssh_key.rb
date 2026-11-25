# frozen_string_literal: true

#
# Copyright:: NodeRings
# License:: Apache-2.0
#

provides :noderings_ssh_key
unified_mode true

use '_partial/_api'

description 'Manages an SSH public key in a NodeRings organization, for installing on new virtual machines.'

property :key_name, String,
          name_property: true,
          description: 'Name of the key in NodeRings'

property :public_key, String,
          coerce: proc(&:strip),
          description: 'The OpenSSH public key, such as the contents of ~/.ssh/id_ed25519.pub. Required for :create'

action_class do
  include NodeRingsCookbook::ResourceHelpers

  def find_key
    noderings_call('listing SSH keys') { noderings_client.list_ssh_keys }.find { |k| k['name'] == new_resource.key_name }
  end

  # The key type and body; the comment does not matter.
  def key_material(key)
    key.to_s.split[0, 2].join(' ')
  end

  def create_key
    key = noderings_call("creating SSH key #{new_resource.key_name}") do
      noderings_client.create_ssh_key(new_resource.key_name, new_resource.public_key)
    rescue NodeRingsCookbook::APIError => e
      raise unless e.code == NodeRingsCookbook::CODE_ALREADY_EXISTS

      raise NodeRingsCookbook::UsageError, 'this public key is already stored in NodeRings under another name; ' \
                                           'NodeRings keeps each key once, so use that name or delete it first'
    end
    noderings_publish('ssh_keys', new_resource.key_name, 'id' => key && key['id'])
  end
end

action :create do
  raise Chef::Exceptions::ValidationFailed, 'noderings_ssh_key: public_key is required for :create' if new_resource.public_key.to_s.empty?

  key = find_key
  if key.nil?
    converge_by("create NodeRings SSH key #{new_resource.key_name}") { create_key }
  elsif key_material(key['publicKey']) != key_material(new_resource.public_key)
    converge_by("replace NodeRings SSH key #{new_resource.key_name} (the public key changed)") do
      noderings_call("deleting SSH key #{new_resource.key_name}") { noderings_client.delete_ssh_key(key['id']) }
      create_key
    end
  else
    noderings_publish('ssh_keys', new_resource.key_name, 'id' => key['id'])
  end
end

action :delete do
  key = find_key
  if key
    converge_by("delete NodeRings SSH key #{new_resource.key_name}") do
      noderings_call("deleting SSH key #{new_resource.key_name}") do
        noderings_client.delete_ssh_key(key['id'])
      rescue NodeRingsCookbook::APIError => e
        raise unless e.not_found?
      end
    end
  end
end
