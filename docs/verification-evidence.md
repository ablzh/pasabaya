# Local verification evidence — October 21, 2026

These results use generated accounts, locations, conversations and bookings only.
No production database, journal, backup credentials or user content was read.
The [engineering walkthrough](engineering-walkthrough.md) links the decisions,
implementation and regressions behind them.

The complete `bin/ci` gate passed for this working tree on October 21: 676
application tests (seed 38108) and 75 browser tests (seed 32620), with zero failures,
errors or skips. Ruby style, template lint, database consistency, architecture,
Docker context, dependency audits, Brakeman and seed loading also passed.
Historical remediation suites were consolidated by behavior; a duplicate smoke
flow and overlapping mobile-form check were removed, and a nested-background
contrast regression was added. The snapshot workflow adds an application
regression without imposing performance timing thresholds.

## Reproduce

From the repository root, with the locked gems installed:

```bash
mise exec -- ruby script/verification/restore_drill.rb
mise exec -- ruby script/verification/performance_baseline.rb
```

Run these as standalone Ruby scripts. They choose a temporary SQLite database and
deletion journal before booting Rails in `test`, override inherited database and
journal paths, and remove their temporary directory afterward. They print one
JSON report as the final line and exit unsuccessfully if a required check fails.
Do not use `rails runner`. The restore drill also runs in CI; the timed baseline
is an explicitly invoked measurement without timing thresholds in CI.

Environment: ARM64 macOS 27.0.1, Ruby 4.0.5, Rails 8.1.3.1, bundled SQLite 3.53.2,
local temporary files, test job/Cable/mail adapters, sequential in-process requests.
CPU model and RAM were not captured. Both measurements include test instrumentation;
they do not represent production latency or capacity.

## Snapshot restore drill

Recorded at 13:02:44 UTC. [Raw result](verification/restore-drill-2026-10-21.json).

The script used a clock set 48 hours earlier to create a pre-deletion account,
accepted participation, a session and chat history, then took a consistent SQLite
snapshot with `VACUUM INTO`. After returning to the current clock, it deleted the
account through the normal service and preserved the resulting journal. With
connections closed, it copied the snapshot over the disposable primary database,
confirmed that the account, session and expired content had returned, and ran
`db:restore:finish`.

| Measurement or check | Result |
| --- | --- |
| Logical backup age | 48 hours, simulated; 172,801.84 seconds at report time |
| Physical snapshot age | 1.099 seconds at report time |
| Restore and reconciliation | 0.499 seconds, monotonic elapsed time from file copy through restore task |
| Deletion replay | One restored account anonymized; latest journal preserved |
| Old credentials and sessions | Credentials rejected; sessions removed |
| Deleted account messages | Removed |
| Expired chat | One expired message purged; chat URL redirects to trip details with no conversation |
| Unexpired survivor history | Retained |
| Historical acceptance | Retained |

The two-day logical data loss window is constructed for this exercise. The physical
snapshot was made locally seconds before restoration. This verifies application
reconciliation after a file restore, including HTTP denial of expired chat. It
does not measure Litestream/Restic retrieval, production RPO/RTO, host loss, upload
restoration or physical avatar purge. The current journal remains a required
recovery dependency. Follow the [production procedure](account-deletion-recovery.md)
and record an actual provider-backed restore before claiming those guarantees.

## History request baseline

Recorded at 13:02:50 UTC. [Raw result](verification/performance-baseline-2026-10-21.json).

One driver, one passenger, two locations and one active offer. The driver owns
either 200 or 2,000 completed rides, each with an accepted passenger booking.
Creation timestamps tie to exercise the ID ordering. Each workload has three warmup
requests followed by 20 measured GETs of its first 20-record page. Requests include
controller, SQL and HTML rendering through Rails' integration session; there is
no network server or browser. Sign-in and dataset creation are outside the timing.

| History | Rides / bookings | Median | p95 | SQL queries/request | RidePost objects/request |
| --- | ---: | ---: | ---: | ---: | ---: |
| Driver `/trips` | 200 / 200 | 37.69 ms | 56.34 ms | 23 | 21 |
| Joined `/trips?tab=bookings` | 200 / 200 | 31.12 ms | 49.31 ms | 17 | 20 |
| Driver `/trips` | 2,000 / 2,000 | 35.85 ms | 45.62 ms | 23 | 21 |
| Joined `/trips?tab=bookings` | 2,000 / 2,000 | 32.22 ms | 52.27 ms | 17 | 20 |

SQL counts exclude schema, cached queries and transaction control. p95 uses the
19th sorted sample (nearest rank). The driver page instantiates 20 historical rides
and the active offer. The joined page instantiates 20 historical rides. Query
counts and loaded history remain fixed in this workload; totals still require
database counts. The script fails if a request loads more than 21 ride objects.
The [query regression](../test/integration/trip_presentation_queries_test.rb) also
checks avatar query growth and all 11 pages of a 205-ride tied-timestamp history.

This small, warmed, single-process sample has scheduling and GC noise. Timing
differences are not evidence that a larger dataset is faster. It measures first
pages only, with no uploads, unread chat backlog, overdue pending requests or
concurrent writers. It does not measure deep-offset cost, job delivery, Cable,
production memory use or an end-to-end browser experience. Use it as a reproducible
local reference when changing query preparation, not a service-level objective.
