# frozen_string_literal: true

#
# Copyright:: NodeRings
# License:: Apache-2.0
#

provides :noderings_dns_zone
unified_mode true

use '_partial/_api'

description 'Manages a DNS zone hosted on NodeRings. After :create, the nameservers to set at your registrar ' \
            "are in node.run_state['noderings']['dns_zones'][zone_name]['nameservers']."

property :zone_name, String,
          name_property: true,
          coerce: proc { |n| n.strip.downcase.chomp('.') },
          description: 'The domain, such as example.com'

property :dnssec, [true, false],
          description: 'true signs the zone with DNSSEC, false removes signing. Left unset, signing is not managed'

property :force_delete, [true, false],
          default: false,
          desired_state: false,
          description: 'With :delete, also delete a zone that still has records'

action_class do
  include NodeRingsCookbook::ResourceHelpers

  def find_zone
    noderings_call('listing DNS zones') { NodeRingsCookbook::DNS.find_zone(noderings_client, new_resource.zone_name) }
  end

  def signed?(mode)
    !['', 'unsigned'].include?(NodeRingsCookbook.trim_enum(mode, 'DNSSEC_MODE_'))
  end
end

action :create do
  zone = find_zone
  if zone.nil?
    converge_by("create NodeRings DNS zone #{new_resource.zone_name}") do
      created = noderings_call("creating DNS zone #{new_resource.zone_name}") { noderings_client.create_dns_zone(new_resource.zone_name) }
      # The create response omits some fields, such as the assigned nameservers.
      zone = noderings_call('reading the new DNS zone') { noderings_client.get_dns_zone(created['id']) } || created
    end
  end

  # In why-run mode the zone was not really created; there is nothing more to read.
  if zone && zone['id']
    dnssec = noderings_call('reading DNSSEC status') { noderings_client.get_dnssec(zone['id']) }
    if property_is_set?(:dnssec) && new_resource.dnssec != signed?(dnssec['mode'])
      if new_resource.dnssec
        converge_by("sign NodeRings DNS zone #{new_resource.zone_name} with DNSSEC") do
          noderings_call('enabling DNSSEC') { noderings_client.enable_dnssec(zone['id']) }
        end
      else
        converge_by("remove DNSSEC signing from NodeRings DNS zone #{new_resource.zone_name}") do
          noderings_call('disabling DNSSEC') { noderings_client.disable_dnssec(zone['id']) }
        end
      end
      dnssec = noderings_call('reading DNSSEC status') { noderings_client.get_dnssec(zone['id']) } unless whyrun_mode?
    end
    noderings_publish('dns_zones', new_resource.zone_name,
                      'id' => zone['id'],
                      'nameservers' => Array(zone['assignedNameservers']),
                      'state' => NodeRingsCookbook.trim_enum(zone['state'], 'DNS_ZONE_STATE_'),
                      'dnssec_mode' => NodeRingsCookbook.trim_enum(dnssec['mode'], 'DNSSEC_MODE_'),
                      'ds' => dnssec['ds'])
  end
end

action :delete do
  zone = find_zone
  if zone
    converge_by("delete NodeRings DNS zone #{new_resource.zone_name}") do
      noderings_call("deleting DNS zone #{new_resource.zone_name}") do
        noderings_client.delete_dns_zone(zone['id'], force: new_resource.force_delete)
      rescue NodeRingsCookbook::APIError => e
        raise unless e.not_found?
      end
    end
  end
end
