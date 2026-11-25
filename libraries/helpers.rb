# frozen_string_literal: true

#
# Copyright:: NodeRings
# License:: Apache-2.0
#
# Helpers mixed into the action class of every noderings_* resource.

module NodeRingsCookbook
  # Tests plug an in-memory API in here; nil means the real one over HTTPS.
  class << self
    attr_accessor :transport, :sleeper
  end

  module ResourceHelpers
    # The API token: the api_token property, then node.run_state, then the environment.
    def noderings_api_token
      return new_resource.api_token unless new_resource.api_token.to_s.empty?

      from_state = node.run_state['noderings_api_token']
      return from_state unless from_state.to_s.empty?

      TOKEN_ENV_VARS.map { |v| ENV[v] }.find { |v| !v.to_s.empty? }
    end

    def noderings_cookbook_version
      run_context.cookbook_collection['noderings']&.version || '0.0.0'
    rescue StandardError
      '0.0.0'
    end

    def noderings_client
      @noderings_client ||= Client.new(
        token: noderings_api_token,
        api_url: new_resource.api_url || ENV['NODERINGS_API_URL'],
        organization_id: new_resource.organization_id || ENV['NODERINGS_ORGANIZATION_ID'],
        timeout: new_resource.api_timeout,
        user_agent: "noderings-cookbook/#{noderings_cookbook_version} (Chef Infra #{Chef::VERSION})",
        transport: NodeRingsCookbook.transport,
        sleeper: NodeRingsCookbook.sleeper
      )
    end

    # Runs an API call and turns its failure into a readable Chef error.
    def noderings_call(what)
      yield
    rescue APIError, UsageError, WaitTimeout => e
      raise Chef::Exceptions::ValidationFailed, "NodeRings: #{what}: #{e.message}" if e.is_a?(UsageError)

      raise "NodeRings: #{what}: #{e.message}"
    end

    # Publishes what a resource learned (IDs, IP addresses) for later resources:
    # node.run_state['noderings'][kind][name]
    def noderings_publish(kind, name, data)
      node.run_state['noderings'] ||= {}
      node.run_state['noderings'][kind] ||= {}
      node.run_state['noderings'][kind][name] = data
    end
  end
end
