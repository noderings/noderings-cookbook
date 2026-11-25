# API properties

[Back to resource list](../README.md#resources)

Every `noderings_*` resource has these properties. None of them is compared when
deciding whether a resource is up to date.

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `api_token` | String | `node.run_state['noderings_api_token']`, then `NODERINGS_TOKEN` | NodeRings API token. Marked sensitive, so it never appears in logs. |
| `api_url` | String | `NODERINGS_API_URL`, then `https://api.noderings.com` | API endpoint. |
| `organization_id` | String | `NODERINGS_ORGANIZATION_ID` | Organization to act in, for tokens that can reach more than one. |
| `api_timeout` | Integer | `60` | Seconds to wait for each API response. |

Requests that fail with a rate limit or a temporary server error are retried with
backoff. Writes are not retried after an error that may have been applied, except
virtual machine orders, which carry an idempotency key.
