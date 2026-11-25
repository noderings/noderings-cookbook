# frozen_string_literal: true

require 'spec_helper'

KEY = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGVY laptop'

describe 'noderings_ssh_key' do
  step_into :noderings_ssh_key
  platform 'ubuntu'

  context 'creating a key' do
    recipe do
      noderings_ssh_key 'laptop' do
        public_key KEY
      end
    end

    it 'stores the key and publishes its ID' do
      expect(chef_run).to create_noderings_ssh_key('laptop')
      key = @fake.ssh_keys.values.first
      expect(key).to include('name' => 'laptop', 'publicKey' => KEY)
      expect(chef_run.node.run_state['noderings']['ssh_keys']['laptop']['id']).to eq key['id']
    end
  end

  context 'when the key is already there with another comment' do
    before { @fake.ssh_keys['k1'] = { 'id' => 'k1', 'name' => 'laptop', 'publicKey' => 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGVY other' } }

    recipe do
      noderings_ssh_key 'laptop' do
        public_key KEY
      end
    end

    it 'changes nothing' do
      chef_run
      expect(@fake.writes).to be_empty
      expect(chef_run.noderings_ssh_key('laptop')).not_to be_updated
    end
  end

  context 'when the public key changed' do
    before { @fake.ssh_keys['k1'] = { 'id' => 'k1', 'name' => 'laptop', 'publicKey' => 'ssh-ed25519 OLD laptop' } }

    recipe do
      noderings_ssh_key 'laptop' do
        public_key KEY
      end
    end

    it 'replaces it' do
      chef_run
      expect(@fake.writes).to eq [['DELETE', '/v1/ssh-keys/k1'], ['POST', '/v1/ssh-keys']]
    end
  end

  context 'deleting' do
    before { @fake.ssh_keys['k1'] = { 'id' => 'k1', 'name' => 'laptop', 'publicKey' => KEY } }

    recipe do
      noderings_ssh_key 'laptop' do
        action :delete
      end
    end

    it 'removes the key' do
      chef_run
      expect(@fake.ssh_keys).to be_empty
    end
  end

  context 'without a public key' do
    recipe do
      noderings_ssh_key 'laptop'
    end

    it('fails clearly') { expect { chef_run }.to raise_error(/public_key is required/) }
  end
end
