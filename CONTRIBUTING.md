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
