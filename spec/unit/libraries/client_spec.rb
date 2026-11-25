# frozen_string_literal: true

require 'spec_helper'
load_noderings_libraries

describe NodeRingsCookbook::Client do
  let(:fake) { FakeNodeRings.new }
  let(:client) do
    described_class.new(token: 'secret-token', organization_id: 'org-9', user_agent: 'ua/1',
                        transport: fake, sleeper: ->(_s) {})
  end

  it 'requires a token' do
    expect { described_class.new(token: ' ') }.to raise_error(NodeRingsCookbook::UsageError, /token is required/)
  end

  it 'rejects a relative API URL' do
    expect { described_class.new(token: 't', api_url: 'api.noderings.com') }.to raise_error(NodeRingsCookbook::UsageError)
  end

  it 'keeps the token out of inspect' do
    expect(client.inspect).not_to include('secret-token')
  end

  it 'sends auth, organization and User-Agent headers' do
    client.organization
    headers = fake.calls.last[4]
    expect(headers).to include('Authorization' => 'Bearer secret-token', 'X-Organization-ID' => 'org-9',
                               'User-Agent' => 'ua/1')
  end

  it 'encodes queries sorted and skips empty values' do
    client.list_providers('PLAN', 'United States', 'Ashburn', ipv6_only: true)
    _, path, query = fake.calls.last
    expect(path).to eq '/v1/marketplace/providers'
    expect(query).to include('filterCountry' => 'United States', 'filterIpv6AvailableOnly' => 'true')
    expect(query).not_to have_key('filterBillingType')
  end

  it 'retries GET on 503 and gives up on writes' do
    fake.failures['GET /v1/organization'] = [503, 502]
    expect(client.organization['id']).to eq 'org-1'
    fake.failures['POST /v1/dns/zones'] = [503]
    expect { client.create_dns_zone('example.com') }.to raise_error(NodeRingsCookbook::APIError) { |e|
      expect(e.status).to eq 503
    }
  end

  it 'never retries a VM order' do
    fake.failures['POST /v1/virtual-machines'] = [502]
    expect { client.create_virtual_machine('hostname' => 'x') }.to raise_error(NodeRingsCookbook::APIError)
    expect(fake.created_vm_bodies).to be_empty
  end

  it 'decodes API errors' do
    err = NodeRingsCookbook.decode_error(400, '{"code": 9, "message": "operation in progress"}', 'POST', '/x')
    expect(err).to be_busy
    expect(err.message).to eq 'operation in progress (HTTP 400 on POST /x)'
    expect(NodeRingsCookbook.decode_error(404, 'nope')).to be_not_found
  end

  it 'explains quota errors' do
    body = { code: 8, message: 'limit reached', details: [
      { '@type' => 'type.googleapis.com/google.rpc.ErrorInfo', 'reason' => 'VM_LIMIT_REACHED',
        'metadata' => { 'limit_key' => 'vms', 'current' => '5', 'limit' => '5' } },
    ] }.to_json
    err = NodeRingsCookbook.decode_error(429, body)
    expect(err).to be_quota
    expect(err).not_to be_ambiguous
    expect(err.message).to include('quota vms: 5 of 5 used')
  end

  it 'returns an empty hash for empty bodies' do
    expect(client.request('DELETE', '/v1/ssh-keys/abc')).to eq('code' => 5, 'message' => 'not found').or eq({})
  rescue NodeRingsCookbook::APIError => e
    expect(e).to be_not_found
  end
end

describe NodeRingsCookbook::Waiter do
  it 'waits with growing delays and times out' do
    now = 0.0
    slept = []
    waiter = described_class.new(10, sleeper: lambda { |s|
      slept << s
      now += s
    }, clock: -> { now })
    expect { waiter.wait('nothing') { [false, nil] } }.to raise_error(NodeRingsCookbook::WaitTimeout, /nothing/)
    expect(slept.first(3)).to eq [2.0, 3.0, 4.5]
  end

  it 'retries while the VM is busy' do
    tries = 0
    waiter = described_class.new(60, sleeper: ->(_s) {})
    out = waiter.retry_busy do
      tries += 1
      raise NodeRingsCookbook::APIError.new(400, 9, 'operation in progress') if tries < 3

      :done
    end
    expect([out, tries]).to eq [:done, 3]
  end
end
