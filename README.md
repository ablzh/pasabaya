# [Pasabaya.app](https://pasabaya.app/)

[![CI](https://github.com/ablzh/pasabaya/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ablzh/pasabaya/actions/workflows/ci.yml)
![Ruby](https://img.shields.io/badge/Ruby-4.0.5-red.svg)
![Rails](https://img.shields.io/badge/Rails-8.1.3-cc0000.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A community carpool board for the Philippines. Drivers publish ride offers, passengers request seats, and accepted participants coordinate through trip chat. The platform takes no payments or commissions.

This is a Rails monolith maintained by one developer. Its engineering focus is explicit booking transitions, seat inventory under concurrent requests, authorized realtime delivery, and account deletion that survives database restoration. See [the architecture overview](docs/architecture.md) for the domain rules and implementation boundaries.

## Features

- Search routes and publish dated driver offers, including approximate departure times.
- Request seats, accept or decline requests, cancel participation, and close new requests.
- Coordinate accepted trips through private chat and receive notifications or route alerts.
- Join the University of the Philippines hub through institutional email verification.
- Record post-trip reviews; no-show adjudication currently uses an operator console, with no administrative web UI.
- Use responsive HTML, dark mode, and versioned Hotwire Native navigation configuration. Native apps and offline storage are not implemented; see [the mobile guide](docs/hotwire-native.md).

Optional Facebook profile links are self-supplied and do not verify identity.

## Stack and tradeoffs

| Concern | Implementation |
| --- | --- |
| Application | Ruby 4.0.5, Rails 8.1.3, ViewComponent |
| Browser UI | Turbo, Stimulus, import maps, Tailwind CSS 4 |
| Persistence | SQLite; separate production primary, queue, cache, and cable databases |
| Background work | Solid Queue supervised by Puma on one server |
| Realtime and cache | Solid Cable and Solid Cache |
| Deployment | Docker, Kamal, Puma, Thruster |
| Recovery | Litestream primary database replication and Restic snapshots |

SQLite and local uploads keep this single-server deployment small. They also require persistent volumes, verified backups, and attention to write contention and disk capacity. Adding application servers would require a deliberate persistence and worker design; it is not a configuration-only scaling step. Application assets do not require a Node build pipeline; Herb's development linter does invoke Node/npm.

## Run locally

Prerequisites: Ruby 4.0.5 (see [.ruby-version](.ruby-version) and [mise.toml](mise.toml)), Git, SQLite, and libvips. Full CI also needs Node/npm for Herb and Chrome/Chromium for Cuprite. macOS, Linux, and Windows through WSL2 are supported development environments.

```bash
git clone https://github.com/ablzh/pasabaya.git
cd pasabaya
bin/setup
```

Open `http://localhost:3000`. Setup installs gems, prepares reference data, and starts Puma plus the Tailwind watcher. Use `bin/setup --skip-server` to prepare the app without starting it, and `bin/dev` to start it later.

Development email is written to `tmp/mails`; sandbox SMTP is an optional `USE_MAILTRAP_SANDBOX=1` setting. See [the operations guide](docs/operations.md#local-email). A contributor does not need deployment credentials to work on the application.

### Optional demo accounts

Reference seeds contain Philippine locations and the UP hub. Demo users, verified memberships, and rides require an explicit local opt-in:

```bash
SEED_DEMO=1 bin/rails db:seed
```

| Account | Password | Fresh demo data |
| --- | --- | --- |
| `driver@example.com` | `password` | Manila → Quezon City draft; Manila → Baguio active offer |
| `passenger@example.com` | `password` | Verified demo UP membership |
| `admin@example.com` | `password` | Local moderator flag; no administrative web UI |

Demo seeds are restricted to development and test, even when `SEED_DEMO=1`. Replaying them preserves existing accounts and ride IDs; it does not refresh an old offer's departure date or reset passwords. `SEED_DEMO=1 bin/setup --reset` recreates a disposable local database and demo data. Never use reset/replant commands on a production database.

## Verification

Run the complete gate before submitting a change:

```bash
bin/ci
```

It checks Ruby style, ERB views and components, database consistency, the boundaries in `Archspec.rb`, known dependency vulnerabilities, application tests, browser flows, and seed loading. Seed regression tests cover replay idempotency and production exclusion of demo data. Security audits need network access; report any check that cannot run.

Useful focused commands:

```bash
bin/rails test
bin/rails test:system
bin/rubocop
bin/herb lint app/views app/components
bin/database_consistency
bundle exec archspec check
```

## Code and operating guides

- `app/models` contains domain predicates, associations, and persistence rules; `app/services` coordinates multi-record transitions.
- `app/controllers` handles HTTP authorization and responses; `app/channels` authorizes realtime streams.
- `app/components`, `app/views`, and `app/javascript` implement the shared browser/native UI.
- `test` includes model, request, service, job, channel, migration, and browser regression tests.

Read [architecture](docs/architecture.md), [operations and moderation](docs/operations.md), [account deletion recovery](docs/account-deletion-recovery.md), [security reporting](SECURITY.md), and [contribution guidelines](CONTRIBUTING.md).

Licensed under the [MIT License](LICENSE).
