# Contributing

Thanks for helping improve the noderings cookbook.

1. Open an issue describing the bug or change before large pull requests.
2. Fork the repository and create a topic branch.
3. Run `cookstyle` and `chef exec rspec` (or `cinc exec rspec`); both must pass.
   See [TESTING.md](TESTING.md) for the integration suites.
4. Add ChefSpec tests for new behaviour, and document new properties in
   `documentation/`.
5. Use [Conventional Commits](https://www.conventionalcommits.org/) for commit
   messages, and sign off each commit (`git commit -s`) to certify the
   [Developer Certificate of Origin](https://developercertificate.org/).

Please report security problems privately as described in [SECURITY.md](SECURITY.md).

## Releases

1. Merge pull requests into `main`. release-please
   (`.github/workflows/release-please.yml`, using the noderings-release-bot GitHub App)
   keeps a pull request named `chore: release X.Y.Z` up to date. It changes
   `version` in `metadata.rb` and writes `CHANGELOG.md`.
2. Merge that pull request when you want to release. release-please pushes the tag
   `vX.Y.Z` and creates a draft GitHub release.
3. The tag starts `.github/workflows/release.yml`, which shares the cookbook on
   [Chef Supermarket](https://supermarket.chef.io/cookbooks/noderings) with
   `knife supermarket share`, then publishes the GitHub release.

Do not create tags or releases by hand. A cookbook version on Supermarket cannot be
uploaded twice, so do not merge the release pull request before the Supermarket
credentials below exist.

### Supermarket credentials

Supermarket has no API tokens. The upload is signed with the private key of a
Supermarket user, so the repository needs two Actions secrets:

| Secret | Value |
| --- | --- |
| `SUPERMARKET_USER` | the user name of the Chef account that owns the cookbook |
| `SUPERMARKET_KEY` | that user's private key (`.pem`) |

Set up once:

1. Create a Chef account at <https://manage.chef.io/signup?ref=community> with the
   address <partners@noderings.com> and confirm the email.
2. Sign in to <https://supermarket.chef.io> once with that account (Sign In, then
   authorize). Supermarket stores the account's public key at that point.
3. In <https://manage.chef.io>, open your profile and use *Get a New Key* to download
   the private key. If you reset the key later, sign out of Supermarket and in
   again so it learns the new public key.
4. Save the secrets (never paste the key anywhere else):

   ```shell
   gh secret set SUPERMARKET_USER --repo noderings/noderings-cookbook
   gh secret set SUPERMARKET_KEY --repo noderings/noderings-cookbook < user.pem
   ```

If a release ran before the secrets existed, open Actions, Release, *Run workflow*,
pick the tag under *Use workflow from*, and run it again. A version that is already
on Supermarket is skipped.
