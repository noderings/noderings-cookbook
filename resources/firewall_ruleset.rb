# frozen_string_literal: true

#
# Copyright:: NodeRings
# License:: Apache-2.0
#

provides :noderings_firewall_ruleset
unified_mode true

use '_partial/_api'

description 'Manages a NodeRings firewall ruleset and its ordered rules. The ruleset holds exactly the rules given, ' \
            'in order; rules not listed are removed.'

property :ruleset_name, String,
          name_property: true,
          description: 'Name of the ruleset'

property :rules, Array,
          default: [],
          coerce: proc { |r| NodeRingsCookbook::Firewall.stringify(r) },
          description: 'Ordered rules. Each is a Hash with direction (ingress or egress), action (accept or drop), protocol ' \
                       '(default tcp), source and destination (each with cidrs, address_groups, address_group_ids or ' \
                       'vm_tags), and optional source_ports and destination_ports (one port or one range)'

property :force_delete, [true, false],
          default: false,
          desired_state: false,
          description: 'With :delete, also delete a ruleset that is still attached to virtual machines'

action_class do
  include NodeRingsCookbook::ResourceHelpers

  def find_ruleset
    noderings_call('listing firewall rulesets') do
      NodeRingsCookbook.find_by_name(noderings_client.list_firewall_rulesets(new_resource.ruleset_name),
                                     new_resource.ruleset_name)
    end
  end

  def desired_rules
    fw = NodeRingsCookbook::Firewall
    rules = new_resource.rules
    raise Chef::Exceptions::ValidationFailed, "a ruleset holds at most #{fw::MAX_RULES} rules" if rules.length > fw::MAX_RULES

    rules.each_with_index do |rule, i|
      error = fw.validate_rule(rule, i)
      raise Chef::Exceptions::ValidationFailed, "noderings_firewall_ruleset[#{new_resource.ruleset_name}] #{error}" if error
    end
    groups = {}
    if rules.any? { |r| %w(source destination).any? { |s| Array((r[s] || {})['address_groups']).any? } }
      noderings_call('listing firewall address groups') { noderings_client.list_firewall_address_groups }
        .each { |g| groups[g['name']] = g['id'] }
    end
    noderings_call('reading firewall rules') { rules.map { |r| fw.rule_to_api(r, groups) } }
  end
end

action :create do
  fw = NodeRingsCookbook::Firewall
  desired = desired_rules
  ruleset = find_ruleset
  if ruleset.nil?
    converge_by("create NodeRings firewall ruleset #{new_resource.ruleset_name}") do
      ruleset = noderings_call("creating firewall ruleset #{new_resource.ruleset_name}") do
        noderings_client.create_firewall_ruleset(new_resource.ruleset_name)
      end
    end
  end

  if ruleset && ruleset['id']
    current = noderings_call('listing firewall rules') { noderings_client.list_firewall_rules(ruleset['id']) }
    if fw.rules_differ?(current, desired)
      converge_by("set the #{desired.length} rule(s) of NodeRings firewall ruleset #{new_resource.ruleset_name} " \
                  "(it had #{current.length})") do
        noderings_call("writing the rules of firewall ruleset #{new_resource.ruleset_name}") do
          fw.reconcile(noderings_client, ruleset['id'], desired)
        end
      end
    end
    noderings_publish('firewall_rulesets', new_resource.ruleset_name, 'id' => ruleset['id'])
  else
    # Why-run: the ruleset would be created with every rule.
    converge_by("add #{desired.length} rule(s) to the new ruleset") {} unless desired.empty?
  end
end

action :delete do
  ruleset = find_ruleset
  if ruleset
    converge_by("delete NodeRings firewall ruleset #{new_resource.ruleset_name}") do
      noderings_call("deleting firewall ruleset #{new_resource.ruleset_name}") do
        noderings_client.delete_firewall_ruleset(ruleset['id'], force: new_resource.force_delete)
      rescue NodeRingsCookbook::APIError => e
        raise unless e.not_found?
      end
    end
  end
end
