# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

# Reads the NodeRings API from the machine running InSpec, so the token never
# goes to the converged node.
class NoderingsApi < Inspec.resource(1)
  name 'noderings_api'
  desc 'Reads objects from the NodeRings API'

  def initialize(url, token)
    super()
    @base = url.chomp('/')
    @token = token
  end

  def get(path)
    uri = URI("#{@base}#{path}")
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{@token}"
    req['Accept'] = 'application/json'
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |h| h.request(req) }
    raise "GET #{path}: HTTP #{res.code}" unless res.code.to_i < 300

    JSON.parse(res.body)
  end

  def zone(name)
    (get('/v1/dns/zones?page=0&pageSize=-1')['zones'] || []).find { |z| z['name'] == name }
  end

  def records(zone_id)
    get("/v1/dns/zones/#{zone_id}/records?page=0&pageSize=100")['records'] || []
  end

  def record(zone_id, name, type)
    records(zone_id).find { |r| r['name'].to_s.chomp('.') == name && r['type'] == type }
  end

  def ruleset(name)
    (get('/v1/firewall/rulesets?page=0&pageSize=-1')['rulesets'] || []).find { |r| r['name'] == name }
  end

  def rules(ruleset_id)
    (get("/v1/firewall/rulesets/#{ruleset_id}/rules?page=0&pageSize=-1")['rules'] || []).sort_by { |r| r['position'].to_i }
  end

  def ssh_key(name)
    (get('/v1/ssh-keys?page=0&pageSize=-1')['sshKeys'] || []).find { |k| k['name'] == name }
  end

  def vm(hostname)
    found = (get('/v1/virtual-machines?page=0&pageSize=-1')['virtualMachines'] || []).find { |v| v['hostname'] == hostname }
    found && get("/v1/virtual-machines/#{found['id']}")
  end

  def to_s
    'NodeRings API'
  end
end
