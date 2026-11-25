# frozen_string_literal: true

# The token comes from the environment, or from a test-only attribute when the
# suite converges on a remote VM.
token = node['noderings_test']['api_token']
node.run_state['noderings_api_token'] = token unless token.to_s.empty?
