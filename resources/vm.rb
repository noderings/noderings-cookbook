# frozen_string_literal: true

#
# Copyright:: NodeRings
# License:: Apache-2.0
#

provides :noderings_vm
unified_mode true

use '_partial/_api'

description 'Manages a NodeRings virtual machine: orders one from the marketplace, keeps its tags, firewall ' \
            'and power state, and deletes it. After :create, its ID and IP addresses are in ' \
            "node.run_state['noderings']['vms'][hostname]. Ordering a VM is billed to the organization."

property :hostname, String,
          name_property: true,
          description: 'Hostname of the VM. It identifies the VM, so it must be unique in the organization'

property :plan, String,
          description: 'Plan code to order, such as SC-GC-1C-1G-20. Required with country and city to order a VM, unless plan_id and region_id are given'

property :country, String,
          description: 'Country of the offer, such as United States'

property :city, String,
          description: 'City of the offer, such as Ashburn'

property :billing_type, String,
          default: 'usage',
          equal_to: %w(usage subscription free),
          description: 'How the plan is billed'

property :provider_id, String,
          description: 'Only consider offers from this provider'

property :sort, String,
          default: 'price',
          equal_to: %w(price rating),
          description: 'Order the cheapest matching offer, or the best rated'

property :require_capabilities, Array,
          default: [],
          description: 'Only consider providers with these capabilities, such as guest_firewall'

property :require_ipv6, [true, false],
          default: false,
          description: 'Only consider offers with IPv6'

property :plan_id, String,
          description: 'Exact plan ID to order, instead of plan, country and city'

property :region_id, String,
          description: 'Exact region ID to order, with plan_id'

property :distro, String,
          coerce: proc { |d| NodeRingsCookbook::Compute.normalize_distro(d) },
          description: 'Operating system, such as ubuntu_24_04 or debian-13. Defaults to ubuntu_24_04 for new VMs. ' \
                       'On an existing VM a different distro fails the run unless allow_reinstall is true'

property :ssh_keys, Array,
          default: [],
          description: 'Names or IDs of NodeRings SSH keys to install. A new VM needs SSH keys or a password'

property :password, String,
          sensitive: true,
          desired_state: false,
          description: 'Root password for a new VM'

property :tags, Array,
          description: 'Tags of the VM. Left unset, tags are not managed'

property :firewall_ruleset, String,
          description: 'Name or ID of the firewall ruleset to attach. An empty string detaches it. Left unset, the firewall is not managed'

property :power_state, String,
          equal_to: %w(running stopped),
          description: 'Keep the VM running or stopped. Left unset, power is not managed'

property :allow_reinstall, [true, false],
          default: false,
          desired_state: false,
          description: 'Reinstall the VM when distro differs. Reinstalling erases the disk'

property :wait, [true, false],
          default: true,
          desired_state: false,
          description: 'Wait for orders and power changes to finish'

property :wait_timeout, Integer,
          default: 900,
          desired_state: false,
          description: 'Seconds to wait for each operation'

action_class do
  include NodeRingsCookbook::ResourceHelpers

  def compute
    NodeRingsCookbook::Compute
  end

  def find_vm
    noderings_call("looking up virtual machine #{new_resource.hostname}") do
      compute.find_vm(noderings_client, new_resource.hostname)
    end
  end

  def find_vm!
    vm = find_vm
    return vm if vm

    raise Chef::Exceptions::ValidationFailed, "NodeRings virtual machine #{new_resource.hostname} does not exist"
  end

  def publish(vm)
    noderings_publish('vms', new_resource.hostname, compute.view(vm)) if vm && vm['id']
  end

  def ssh_key_ids
    noderings_call('resolving SSH keys') { compute.resolve_ssh_keys(noderings_client, new_resource.ssh_keys) }
  end

  def ruleset_id
    noderings_call('resolving the firewall ruleset') { compute.resolve_ruleset(noderings_client, new_resource.firewall_ruleset) }
  end

  def wait_args
    { wait: new_resource.wait, timeout: new_resource.wait_timeout }
  end

  def offer!
    if new_resource.plan_id && new_resource.region_id
      return [new_resource.plan_id, new_resource.region_id, "plan #{new_resource.plan_id}"]
    end

    unless new_resource.plan && new_resource.country && new_resource.city
      raise Chef::Exceptions::ValidationFailed,
            "noderings_vm[#{new_resource.hostname}] does not exist; to order it give plan, country and city " \
            '(or plan_id and region_id)'
    end
    plan_id, region_id, offer = noderings_call('finding an offer') do
      compute.choose_offer(noderings_client, new_resource.plan, new_resource.country, new_resource.city,
                           billing_type: new_resource.billing_type, provider_id: new_resource.provider_id,
                           require_capabilities: new_resource.require_capabilities,
                           require_ipv6: new_resource.require_ipv6, sort: new_resource.sort)
    end
    [plan_id, region_id, "#{new_resource.plan} from #{offer['provider_name']} in #{new_resource.city}, #{new_resource.country}"]
  end

  def order
    plan_id, region_id, what = offer!
    keys = ssh_key_ids
    if keys.empty? && new_resource.password.to_s.empty?
      raise Chef::Exceptions::ValidationFailed,
            "noderings_vm[#{new_resource.hostname}]: a new VM needs ssh_keys or a password so you can log in"
    end
    rs = new_resource.firewall_ruleset.to_s.empty? ? nil : ruleset_id
    distro = new_resource.distro || 'ubuntu_24_04'
    vm = nil
    converge_by("order NodeRings virtual machine #{new_resource.hostname} (#{what}, #{distro})") do
      vm = noderings_call("ordering virtual machine #{new_resource.hostname}") do
        compute.order_vm(noderings_client, new_resource.hostname, plan_id, region_id,
                         distro: distro, ssh_key_ids: keys, password: new_resource.password,
                         tags: new_resource.tags || [], ruleset_id: rs, **wait_args)
      end
    end
    vm
  end

  def converge_distro(vm)
    want = new_resource.distro
    have = NodeRingsCookbook.trim_enum(vm['distro'], 'DISTRO_')
    return vm if want.nil? || want == have

    unless new_resource.allow_reinstall
      raise Chef::Exceptions::ValidationFailed,
            "NodeRings virtual machine #{new_resource.hostname} runs #{have}, not #{want}. Reinstalling erases " \
            'its disk, so it is only done with allow_reinstall true (or the :reinstall action)'
    end
    reinstall(vm, want)
  end

  def reinstall(vm, distro)
    keys = ssh_key_ids
    converge_by("reinstall NodeRings virtual machine #{new_resource.hostname} with #{distro} (erases the disk)") do
      vm = noderings_call("reinstalling virtual machine #{new_resource.hostname}") do
        compute.reinstall(noderings_client, vm['id'], new_resource.hostname, distro,
                          ssh_key_ids: keys, password: new_resource.password, **wait_args)
      end
    end
    vm
  end

  def converge_tags(vm)
    return vm if new_resource.tags.nil?

    have = compute.user_tags(vm)
    want = new_resource.tags.uniq.sort
    return vm if have == want

    converge_by("set the tags of NodeRings virtual machine #{new_resource.hostname} to #{want.join(', ')}") do
      noderings_call('updating tags') do
        noderings_client.update_virtual_machine_tags(vm['id'], add: want - have, remove: have - want)
        vm = noderings_client.get_virtual_machine(vm['id'])
      end
    end
    vm
  end

  def converge_firewall(vm)
    return vm if new_resource.firewall_ruleset.nil?

    want = ruleset_id
    have = vm['firewallRulesetId'].to_s
    return vm if want == have

    if want.empty?
      converge_by("detach the firewall ruleset from NodeRings virtual machine #{new_resource.hostname}") do
        vm = noderings_call('detaching the firewall') { compute.detach_firewall(noderings_client, vm['id'], have, **wait_args) }
      end
    else
      converge_by("attach firewall ruleset #{new_resource.firewall_ruleset} to NodeRings virtual machine #{new_resource.hostname}") do
        vm = noderings_call('attaching the firewall') { compute.attach_firewall(noderings_client, vm['id'], want, **wait_args) }
      end
    end
    vm
  end

  def converge_power(vm, want)
    return vm if want.nil? || compute.power_state(vm) == want

    verb = want == 'running' ? 'start' : 'stop'
    converge_by("#{verb} NodeRings virtual machine #{new_resource.hostname}") do
      vm = noderings_call("#{verb}ing virtual machine #{new_resource.hostname}") do
        compute.set_power(noderings_client, vm['id'], want, **wait_args)
      end
    end
    vm
  end
end

action :create do
  vm = find_vm
  if vm.nil?
    vm = order
    vm = converge_power(vm, new_resource.power_state) if vm && new_resource.power_state == 'stopped'
  else
    if new_resource.plan && vm['planCode'] && vm['planCode'] != new_resource.plan
      Chef::Log.warn("NodeRings virtual machine #{new_resource.hostname} is on plan #{vm['planCode']}, not " \
                     "#{new_resource.plan}; the plan of an existing VM is not changed")
    end
    vm = converge_distro(vm)
    vm = converge_tags(vm)
    vm = converge_firewall(vm)
    vm = converge_power(vm, new_resource.power_state)
  end
  publish(vm)
end

action :delete do
  vm = find_vm
  if vm
    converge_by("delete NodeRings virtual machine #{new_resource.hostname} (#{vm['id']})") do
      noderings_call("deleting virtual machine #{new_resource.hostname}") do
        compute.waiter(noderings_client, new_resource.wait_timeout).retry_busy do
          noderings_client.delete_virtual_machine(vm['id'])
        rescue NodeRingsCookbook::APIError => e
          raise unless e.not_found?
        end
        if new_resource.wait
          compute.waiter(noderings_client, new_resource.wait_timeout).wait("virtual machine #{new_resource.hostname} to be deleted") do
            noderings_client.get_virtual_machine(vm['id'])
            [false, nil]
          rescue NodeRingsCookbook::APIError => e
            raise unless e.not_found?

            [true, nil]
          end
        end
      end
    end
  end
end

action :start do
  publish(converge_power(find_vm!, 'running'))
end

action :stop do
  publish(converge_power(find_vm!, 'stopped'))
end

action :restart do
  vm = find_vm!
  converge_by("restart NodeRings virtual machine #{new_resource.hostname}") do
    vm = noderings_call("restarting virtual machine #{new_resource.hostname}") do
      compute.set_power(noderings_client, vm['id'], 'restarted', **wait_args)
    end
  end
  publish(vm)
end

action :reinstall do
  raise Chef::Exceptions::ValidationFailed, 'noderings_vm: distro is required for :reinstall' if new_resource.distro.nil?

  publish(reinstall(find_vm!, new_resource.distro))
end
