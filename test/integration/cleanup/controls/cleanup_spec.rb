# frozen_string_literal: true

api = noderings_api(input('api_url'), input('api_token'))
id = input('test_id')

control 'noderings-cleanup' do
  title 'Everything the suites made is gone'
  describe('vm') do
    subject { api.vm("#{id}-vm") }
    it { should be_nil }
  end
  describe('zone') do
    subject { api.zone("#{id}.#{input('domain')}") }
    it { should be_nil }
  end
  describe('ruleset') do
    subject { api.ruleset("#{id}-web") }
    it { should be_nil }
  end
  describe('ssh key') do
    subject { api.ssh_key("#{id}-key") }
    it { should be_nil }
  end
end
