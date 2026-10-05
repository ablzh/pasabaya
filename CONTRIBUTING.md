# Contributing to Pasabaya.app

Start with the local setup in [README.md](README.md) and the domain boundaries in [docs/architecture.md](docs/architecture.md). Prefer Rails conventions and an existing module before adding dependencies or abstractions.

## Changes and tests

1. Fork the repository and create a descriptive branch from `main`.
2. Keep the change focused and include the smallest relevant behavior or regression test. Browser tests are needed for browser behavior, not for every backend change.
3. Run `bin/ci`. This is the full gate for style, templates, architecture, schema consistency, security, application tests, browser tests, and seeds. If a check cannot run, state what prevented it; do not describe the gate as passing.
4. Open a pull request describing the problem, resulting behavior, and validation. Include screenshots when the visual result matters.

Use `bin/rails test path/to/test.rb` for a focused application test and `bin/rails test:system` for browser tests. `bin/rubocop` uses Rails Omakase style. Avoid unrelated formatting or generated scaffolding in a functional change.

## Issues and security

For bugs, include the reproduction steps, expected result, actual result, and relevant environment. Keep personal data and credentials out of reports. Follow [SECURITY.md](SECURITY.md) for vulnerabilities instead of posting exploit details in a public issue.
