# frozen_string_literal: true

#
# Copyright:: NodeRings
# License:: Apache-2.0
#
# API connection properties shared by every noderings_* resource.

property :api_token, String,
          sensitive: true,
          desired_state: false,
          description: "NodeRings API token. Defaults to node.run_state['noderings_api_token'], then the NODERINGS_TOKEN environment variable"

property :api_url, String,
          desired_state: false,
          description: 'NodeRings API endpoint. Defaults to the NODERINGS_API_URL environment variable, then https://api.noderings.com'

property :organization_id, String,
          desired_state: false,
          description: 'Organization to act in, for tokens that can reach more than one. Defaults to the NODERINGS_ORGANIZATION_ID environment variable'

property :api_timeout, Integer,
          default: 60,
          desired_state: false,
          description: 'Seconds to wait for each API response'
