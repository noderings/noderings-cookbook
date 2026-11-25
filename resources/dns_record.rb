# frozen_string_literal: true

#
# Copyright:: NodeRings
# License:: Apache-2.0
#

provides :noderings_dns_record
unified_mode true

use '_partial/_api'

description 'Manages the records of one name and type in a NodeRings DNS zone.'

property :record_name, String,
          name_property: true,
          description: 'Name relative to the zone (www, or @ for the apex). A full name inside the zone also works'

property :zone, String,
          required: true,
          description: 'Name or ID of the zone, which must already exist'

property :type, String,
          required: true,
          coerce: proc(&:upcase),
          equal_to: NodeRingsCookbook::DNS::RECORD_TYPES,
          description: 'Record type, such as A, AAAA, CNAME, MX or TXT'

property :values, [String, Array],
          coerce: proc { |v| Array(v).map { |x| x.to_s.strip } },
          description: 'Record values. Hostnames should end with a dot; TXT values are plain text without quotes. Required for :create'

property :ttl, Integer,
          default: 3600,
          callbacks: { 'must be between 30 and 86400 seconds' => ->(t) { t.between?(30, 86_400) } },
          description: 'Time to live in seconds'

action_class do
  include NodeRingsCookbook::ResourceHelpers

  def zone!
    zone = noderings_call('listing DNS zones') { NodeRingsCookbook::DNS.find_zone(noderings_client, new_resource.zone) }
    return zone if zone

    raise Chef::Exceptions::ValidationFailed,
          "NodeRings DNS zone #{new_resource.zone} does not exist in this organization; create it with noderings_dns_zone"
  end

  def label(rel)
    "#{rel} #{new_resource.type} in #{new_resource.zone}"
  end
end

action :create do
  dns = NodeRingsCookbook::DNS
  type = new_resource.type
  values = Array(new_resource.values)
  error = dns.validate_values(type, values)
  raise Chef::Exceptions::ValidationFailed, "noderings_dns_record[#{new_resource.record_name}] #{type}: #{error}" if error

  zone = zone!
  rel = dns.relative_name(new_resource.record_name, zone['name'])
  current = noderings_call('listing DNS records') { dns.find_record(noderings_client, zone['id'], rel, type) }
  have = current ? Array(current['rdata']).map { |v| dns.from_api(type, v) } : nil

  if current.nil? || current['ttl'].to_i != new_resource.ttl || !dns.same_values?(type, have, values)
    what = if current.nil?
             "create NodeRings DNS record #{label(rel)}: #{values.join(', ')}"
           else
             "update NodeRings DNS record #{label(rel)}: #{have.join(', ')} (ttl #{current['ttl']}) -> " \
             "#{values.join(', ')} (ttl #{new_resource.ttl})"
           end
    converge_by(what) do
      noderings_call("writing DNS record #{label(rel)}") do
        noderings_client.upsert_dns_record(zone['id'], 'name' => rel, 'type' => type, 'ttl' => new_resource.ttl,
                                                       'rdata' => values.map { |v| dns.to_api(type, v) })
      end
    end
  end
end

action :delete do
  dns = NodeRingsCookbook::DNS
  zone = noderings_call('listing DNS zones') { dns.find_zone(noderings_client, new_resource.zone) }
  if zone
    rel = dns.relative_name(new_resource.record_name, zone['name'])
    current = noderings_call('listing DNS records') { dns.find_record(noderings_client, zone['id'], rel, new_resource.type) }
    if current
      converge_by("delete NodeRings DNS record #{label(rel)}") do
        noderings_call("deleting DNS record #{label(rel)}") do
          noderings_client.delete_dns_record(zone['id'], rel, new_resource.type)
        rescue NodeRingsCookbook::APIError => e
          raise unless e.not_found?
        end
      end
    end
  end
end
