# [Pasabaya.app](https://pasabaya.app/)

```text
  ____                                  _                           _                      
 |  _ \  __ _  ___   __ _  |__ \  __ _  _   _   __ _        __ _  _ __  _ __  
 | |_) |/ _` |/ __| / _` | |  _ \/ _` || | | | / _` |      / _` || '_ \| '_ \ 
 |  __/| (_| |\__ \| (_| | | |_) | (_| || |_| || (_| |  _ | (_| || |_) || |_) |
 |_|    \__,_||___/ \__,_| |____/ \__,_| \__, | \__,_| (_) \__,_|| .__/ | .__/ 
                                         |___/                   |_|    |_|    
```

[![CI](https://github.com/ablzh/pasabaya/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ablzh/pasabaya/actions/workflows/ci.yml)
![Ruby](https://img.shields.io/badge/Ruby-4.0.1-red.svg)
![Rails](https://img.shields.io/badge/Rails-8.1.3-cc0000.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Carpooling for the community, not for profit.**  
> A smarter, social way to find travel companions across the Philippines with zero platform fees, zero commissions, and zero middlemen.

---

## The Philosophy

As the industry moves toward microservices and division of responsibility, Rails proves that a single developer, with the right monolith at their disposal, can compete on their own with entire product teams.

This project demonstrates that a single developer can build a fully functional SaaS product—from frontend and backend to deployment on a production server and ongoing maintenance—while balancing it with a full-time job and university studies.

In creating Pasabaya.app, I was inspired by **The One Person Framework** philosophy. The source code is open, and the codebase is designed to be as simple as possible, making it easy for others to understand, contribute, and suggest improvements.

---

## Core Features

- **Community Ride Board:** Drivers offer carpools; passengers request seats on driver offers.
- **Route Discovery:** Browse and search rides between Philippine regions, provinces, and cities (e.g., Metro Manila ↔ Baguio, Quezon City ↔ Manila).
- **Direct Social Connection:** Facebook profile links for users to review; no in-app financial transactions or commission fees. Profile ownership is not independently verified.
- **Modern Interface:** Encapsulated UI built with ViewComponents, Tailwind CSS 4, Heroicons, and native dark mode support.
- **Hotwire Native Foundation:** Shared Rails screens, stable tab destinations, persistent sessions, and versioned iOS/Android navigation configuration. Native apps and offline storage are not implemented yet. See [the mobile implementation guide](docs/hotwire-native.md).

---

## Technical Stack

The project leverages **Rails 8.1** capabilities to their fullest, adhering to the principle of minimizing external dependencies.

| Layer / Task | Traditional Industry Stack | Pasabaya Stack (Lean Monolith) |
| :--- | :--- | :--- |
| **Framework** | Next.js / Express / Django | **Ruby on Rails 8.1.3** + **Ruby 4.0.1** |
| **Database** | PostgreSQL / MySQL | **SQLite** (Production-ready with WAL mode) |
| **Interactive UI** | React + Next.js + Redux | **Hotwire** (Turbo + Stimulus) |
| **UI Components** | React / Vue components | **ViewComponent** (`app/components/`) |
| **Styling & Icons** | Node.js + PostCSS / Tailwind CLI | **Tailwind CSS 4** (`tailwindcss-rails`) + **Heroicons** |
| **Job Queues** | Redis + Sidekiq / Celery | **Solid Queue** (SQLite-backed, runs within Puma) |
| **Caching** | Redis / Memcached | **Solid Cache** (SQLite-backed) |
| **WebSockets** | Redis / AnyCable | **Solid Cable** (SQLite-backed) |
| **Frontend Build** | Node.js + Webpack / Vite | **Import Maps** (Native browser ESM, zero Node.js) |
| **Web Server & Acceleration** | Nginx + Reverse Proxy | **Puma** + **Thruster** (`bin/thrust` HTTP caching/compression) |
| **Deployment** | Kubernetes / AWS ECS | **Kamal 2** (Docker + SSH) |
| **Disaster Recovery** | Cloud DB Snapshots | **Litestream** (Live S3 replication) + **kamal-backup** (Restic) |
| **Quality & Architecture** | ESLint / Custom check scripts | **ArchSpec**, **Herb**, `database_consistency`, **RuboCop Omakase** |

---

## How to Run Locally

Thanks to the **Solid Trifecta** (Solid Queue, Solid Cache, and Solid Cable) running on SQLite and **Import Maps**, there is no need to run PostgreSQL, Redis, or Node.js to get started.

### Prerequisites

- **macOS / Linux / Windows with WSL2**
- **Ruby 4.0.1** (matching [.ruby-version](.ruby-version), recommended via [mise](https://mise.jdx.dev/), `asdf`, or `rbenv`)
- **Rails 8.1**
- **Git** & **SQLite 3**
- Standard Rails image and system dependencies (`libvips`, Google Chrome / Chromium for system tests)

### Get It Running

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ablzh/pasabaya.git
   cd pasabaya
   ```

2. **Run the setup script**:
   ```bash
   bin/setup
   ```
   *This command installs all gems, prepares your SQLite database (including seeding Philippine locations and sample rides), clears logs/tempfiles, and automatically starts the development server.*

3. **Access the app**:
   Open `http://localhost:3000` in your browser.

### Development Commands

- **Start server & asset compilation**:
  ```bash
  bin/dev
  ```
  Runs Puma and the Tailwind CSS compiler watcher concurrently via `Procfile.dev`.
- **Run setup without starting the server**:
  ```bash
  bin/setup --skip-server
  ```
- **Reset local database & re-seed**:
  ```bash
  bin/setup --reset
  # or
  bin/rails db:seed:replant
  ```

---

## Seed Accounts & Test Personas

The seed script (`db/seeds.rb`) populates Philippine regions, provinces, and cities alongside pre-configured accounts:

| Persona | Email | Password | Seeded Activity |
| :--- | :--- | :--- | :--- |
| **Driver** | `driver@example.com` | `password` | 2 active ride offers (Manila → QC, Manila → Baguio) |
| **Passenger** | `passenger@example.com` | `password` | Passenger account for requesting seats |
| **Admin** | `admin@example.com` | `password` | Administrative privileges |

---

## Verification & Testing (`bin/ci`)

Before submitting a Pull Request, run the local CI script to verify that code style, template syntax, database consistency, architecture boundaries, security, and tests pass:

```bash
bin/ci
```

You can also run individual verification steps:

| Check | Command | Description |
| :--- | :--- | :--- |
| **Test Suite** | `bin/rails test` | Runs unit, controller, and integration tests |
| **System Tests** | `bin/rails test:system` | Runs headless browser tests via Cuprite |
| **Ruby Style** | `bin/rubocop` | Checks code against Rails Omakase guidelines |
| **ERB Linting** | `bin/herb lint app/views` | Lints ERB templates |
| **Database Consistency** | `bin/database_consistency` | Validates Active Record model constraints against SQLite schema |
| **Architecture** | `bundle exec archspec check` | Enforces layer boundaries defined in `Archspec.rb` |
| **Security Audits** | `bin/brakeman`<br>`bin/bundler-audit`<br>`bin/importmap audit` | Scans for Rails vulnerabilities and vulnerable dependencies |
| **Seed Replay** | `env RAILS_ENV=test bin/rails db:seed:replant` | Verifies database seed idempotency |

---

## Project Structure

```text
app/
├── components/           # Reusable ViewComponents (Navbar, Card, Combobox, DarkModeSwitcher, etc.)
├── controllers/          # Application controllers (rides, sessions, registrations, settings)
├── javascript/           # Stimulus controllers and vanilla JS (Import Maps)
├── models/               # Active Record models (RidePost, Location, User, Subscriber, Session)
├── views/                # ERB templates and Turbo Streams
config/
├── ci.rb                 # CI verification pipeline definitions (bin/ci)
├── deploy.yml            # Kamal deployment configuration
├── litestream.yml        # Litestream S3 replication configuration
└── database.yml          # Multi-database SQLite configuration (primary, cache, queue, cable)
test/
├── controllers/          # Controller regression & authorization tests
├── system/               # Cuprite headless browser end-to-end user journeys
└── test_helper.rb        # Test configuration (Prosopite N+1 detection, fixtures)
```

---

## Production & Monitoring

- **Deployment:** Containerized deployment managed by **Kamal 2** with zero-downtime rolling deploys.
- **Data Persistence:** SQLite primary database backed up continuously via **Litestream** (live streaming replication to S3) and **kamal-backup** (Restic snapshots).
- **SSL & CDN:** Cloudflare proxy with automatic SSL.
- **Monitoring:** Public performance metrics are available at [Skylight OSS](https://oss.skylight.io/app/applications/6Ku64X6eveQt/recent/6h/endpoints).

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on branch naming, code style, and submitting pull requests.

## License

This project is open-source under the [MIT License](LICENSE).
