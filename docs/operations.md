# Operating Pasabaya

This guide describes the repository's single-server deployment. It does not
establish that external firewall rules, alert routes, or backup restore drills
have been configured; an operator must verify those outside the repository.

## Credentials and deployment host

Rails encrypted credentials are the source of truth. Edit them with
`bin/rails credentials:edit`. The application reads mail and Skylight credentials
directly; `.kamal/secrets` maps credential paths to the environment names required
by Kamal, Netdata, Litestream, and Restic. It stores commands rather than duplicate
secret values. Required deployment paths are:

- `kamal.registry_password`
- `netdata.claim_token` and `netdata.claim_rooms`
- `r2.endpoint`, `r2.access_key_id`, and `r2.secret_access_key`
- `restic.password`
- `mailtrap.user_name` and `mailtrap.password` for production email
- `skylight.authentication_token` for performance monitoring

Supply the decryption key through `RAILS_MASTER_KEY` or an untracked
`config/master.key`. Do not print resolved credentials or include them in build
logs. `.kamal/secrets` prefers an existing key in the process environment.

Set `DEPLOY_HOST` in the shell or deployment job before invoking Kamal:

```bash
export DEPLOY_HOST=your-deployment-host
```

The same value configures the web server and accessories. Kamal evaluates
deployment ERB before reading `.kamal/secrets`, so placing `DEPLOY_HOST` only in
that secrets file does not supply it to the YAML. Removing an address from current
files does not remove it from Git history or change origin network exposure.

## Local email

Development writes email to `tmp/mails` without SMTP credentials. Use that output
for confirmation and reset links, or inspect the password and welcome mailer
previews at `/rails/mailers`. Set `USE_MAILTRAP_SANDBOX=1` only when intentionally
using sandbox SMTP, with `mailtrap_sandbox.user_name` and
`mailtrap_sandbox.password` in your local credentials. Missing sandbox settings
are an error rather than silently discarding mail. Never copy production keys
into a contributor's setup.

## Abuse protection

Registration uses an `invisible_captcha` honeypot. The field is hidden from users,
keyboard navigation, and assistive technology. Timing and spinner checks are
disabled so autofill and Turbo-restored forms remain usable. No interactive
CAPTCHA provider is configured.

Rack::Attack and Rails controller limits use the application cache, which is
shared Solid Cache in production. Recipient keys use a SHA-256 digest of the
trimmed, lowercase email address; raw addresses are not counter keys.

| Operation | Limits |
| --- | --- |
| Registration | 5 attempts/minute and 20/hour per IP |
| Login | Rack::Attack: 5 attempts/20 seconds per IP and normalized email; Rails: 10/3 minutes per IP |
| Password reset | 10 attempts/3 minutes per IP; 1/minute and 5/hour per recipient |
| Membership verification email | 5 attempts/10 minutes per account; 1/minute and 5/hour per recipient |
| Email change confirmation | 5 attempts/10 minutes per account; 1/minute and 5/hour per recipient |
| New ride offers | 10 attempts/10 minutes per account |
| Seat requests | 20 attempts/minute per account |
| Route alerts | 20 attempts/10 minutes per account |
| Trip reviews | 10 attempts/10 minutes per account |
| Chat messages | 30 attempts/minute per account |

Limits count attempts, including invalid submissions. Password reset recipient
limits return the same generic acknowledgement as successful or unknown-account
requests. Authenticated forms receive a 429 response; Turbo displays a toast and
leaves the unsent form intact. Cancellation, leaving a hub, and account deletion
have no new account quota.

Blocked requests produce JSON application log records for
`rate_limit.action_controller`, `invisible_captcha.spam_detected`, and
`throttle.rack_attack`. These structured records contain only the event and known
controller, action, or limiter names; they omit IPs, email addresses, counter keys,
form data, honeypot contents, request URLs, referrers, and user agents. The deprecated
`rack.attack` event is not subscribed to, avoiding duplicate throttle records.
This describes the added metrics records, not a redaction policy for ordinary
Rails, proxy, or dependency logs. Inspect their logging and retention separately.

Use `bin/kamal logs` and the configured log collection to compare event counts by
operation or limiter. Treat these initial thresholds as a policy to tune against
actual usage, especially registration from shared university or office IPs. Verify
trusted client IP handling and origin restrictions before relying on IP quotas
behind Cloudflare. Honeypots and rate limits do not establish email ownership;
registration's existing immediate sign-in behavior is unchanged.

## Deployment and rollback

1. Run `bin/ci` and review migrations for data loss and compatibility with the
   previous application version.
2. Verify a recent backup, current deletion journal, free disk space, and access
   to the deployment host. Record the previous deployed image version.
3. On the first installation, initialize the deletion registry before starting
   the web server using `bin/rails retention:initialize_registry` in a maintenance
   container with the production environment and persistent volumes. Follow
   [the recovery guide](account-deletion-recovery.md); initialization must never
   bypass a missing journal after restoration.
4. Run `bin/kamal deploy` with the host and decryption key available. The web
   entrypoint prepares databases and performs retention scrubbing before boot.
5. Check `/up`, sign-in, an authorized listing, and background delivery. `/up`
   confirms Rails boot health; it does not prove backups, queue processing, or
   outgoing email are healthy.

Use `bin/kamal logs` to inspect application failures. Roll back with
`bin/kamal rollback <previous-version>` only after confirming the previous image
works with the current database schema. Image rollback does not undo migrations;
a data restore requires the separate procedure below.

Keep access restricted to trusted operators. The origin firewall/proxy must
enforce the intended Cloudflare-only access policy and trusted forwarding headers.
Verify those rules externally before treating the origin as protected. Do not
assume a repository host change applies network restrictions.

### Legacy ride transition

The October 20, 2026 snapshot has 14 active offers from 11 drivers. The one-off
`script/legacy_rides_upgrade.rb` imports those reviewed records into 16 ordinary
regular schedules, including the two return directions explicitly described by
drivers. It is not invoked by schema migrations, requests, or recurring jobs.

Run the import in the deployment environment after `db:migrate`, before reopening
the updated app to users. Keep the original database backup. Source IDs, owners,
routes, seats, creation timestamps and description hashes must still match the
reviewed snapshot. Changed or already-booked sources stop the entire import for
inspection. New posts and genuine private drafts outside this manifest stay private.

```bash
bin/rails legacy_rides:import
EXECUTE=1 bin/rails legacy_rides:import
```

The first command previews and rolls back the entire import. The second saves it.
Known schedules come from descriptions; unspecified days become Monday–Friday,
and unspecified times become Flexible. Old calendar dates are preserved on the
original records, while their recurring offers use the known Philippine clock
time. For source 7 the departure starts at 17:30. Source 13 follows the description's
Bulacan → Makati direction, Friday at 05:00. The original 17:30–18:00 and 05:00–06:00
ranges remain in the full descriptions; the initial exact departure is the start
of the range. Source 17 and its return run daily. All descriptions are preserved
in full; list previews remain shortened.

Schedules initially end 30 days after the import. For source 8, the operator
explicitly instructed setting the reviewed owner's profile to female. The import
applies that choice only while the profile is unspecified, retaining an existing
female value and stopping for review if the user has selected a different value.
It never infers gender from names or descriptions. Source 8 is published as a
ladies-only schedule, Monday–Friday at 12:30, keeping the existing audience rules.
The snapshot therefore produces 16 active schedules. They create bookable departures through
the normal materializer; driver confirmation is still required for each seat request.

After checking the deployed search, schedule editing and outgoing email setup,
preview the campaign and explicitly send it:

```bash
bin/rails legacy_rides:notify
EXECUTE=1 bin/rails legacy_rides:notify
```

The snapshot has 48 registered users, including 11 owners and 37 members without
ride posts. The campaign records these account IDs at import and sends each
eligible account exactly one of two messages:

- The 11 owners receive `UserMailer#ride_upgrade`, listing only their imported
  schedules, review links, current end dates and the defaults to check.
- The other 37 members receive `UserMailer#platform_update`, explaining ride
  search, seat requests, driver acceptance, private trip chat, and how to publish
  one-time or regular offers. It makes no claim about transferred rides or expiry.

The legacy subscribers table is empty, so there is no separate waitlist campaign.
New registrations after this snapshot receive their normal welcome email and are
excluded from this one-off campaign. Both mailers reload the current account and
address, skipping deleted or banned users. An owner receives the personalized
message instead of also receiving the general announcement.

Preview HTML and text at `/rails/mailers/user_mailer/ride_upgrade` and
`/rails/mailers/user_mailer/platform_update` in development with imported schedules.
Neither import command sends emails. Notification preview sends nothing. The
explicit send command delivers synchronously and records each success.

Both commands use `storage/legacy_rides_upgrade.json` on the persistent volume,
with an exclusive lock. Preserve this receipt with the database. Repeating the
import retains schedules, return directions, driver edits and original expiry;
repeating notification skips recorded successful sends. If receipt validation
fails, stop and inspect the receipt and database together. If a transaction failed
after writing the receipt but before commit, move that receipt aside only after
verifying no schedules committed and no reviewed source was converted;
then retry. If SMTP accepted a message but the process stopped before recording
success, confirm delivery with the provider before retrying that recipient.

## Backups and operational checks

`config/litestream.yml` configures primary database replication with a one-minute
sync interval. `config/kamal-backup.yml` configures daily Restic snapshots of the
databases, uploads, and deletion registry, with repository checking and retention.
These are configured schedules, not measured recovery guarantees.

Check replication freshness, last successful Restic snapshot/check, disk usage,
overdue/failed Solid Queue jobs, and undelivered notifications. Verify Netdata alert
delivery and an external uptime check through their actual provider settings.
Skylight measures request performance; it does not replace these checks.

Before relying on a backup, restore it into an isolated maintenance environment,
preserve the latest deletion journal, run `bin/rails db:restore:finish`, and verify
deleted accounts remain anonymized and expired chat content is unavailable.
Record the backup date, restore duration, data loss window, and result. Keep the
application offline if reconciliation fails. See the complete
[account deletion recovery procedure](account-deletion-recovery.md).

Accessory images currently retain their existing `latest` tags. Pinning them
requires verifying compatible Litestream/Restic formats and a successful restore;
do not select replacement versions from tag names alone.

## Moderation

Administrators sign in with the existing application account and open `/admin`.
The area provides read-only trip reviews and a no-show incident queue. Review
filters distinguish trip outcomes; incident filters distinguish pending,
confirmed, dismissed, and existing appealed cases. Lists are not paginated.
An incident's detail page brings together the reported participant, route and
departure, historical participation, related reviews, current restrictions, and
decision history. Reports are evidence to review, not confirmed strikes.

The migration preserves the latest known pre-history decision, including its
operator, reason, and recorded time. Its previous outcome and booking restriction
are unknown; earlier unrecorded decisions are not reconstructed.

The available actions confirm or dismiss a no-show, including correcting a
previous decision. Each requires a meaningful reason and an active administrator
who was not involved in that trip. The service records the operator and result,
updates the existing 60-day strike count and booking freeze policy, and notifies
the reported user of either result. The recipient can read the result through
their own notification. Deleted accounts are not notified or restricted again;
anonymized evidence and reasons remain scrubbed.

This area does not edit or delete reviews, grant roles, manage other accounts,
change bookings, or provide a user appeal submission workflow. Existing appealed
records remain readable and can receive a final decision. Private chats keep
their existing access and retention rules. Infrastructure, recovery, and queue
operations continue to use the tools described above.

### Granting and revoking access

Use `bin/kamal console` in production. Identify the intended existing account
before setting its ID below; production seeds do not create operator accounts.
The `admin` attribute is read-only for ordinary model updates, and HTTP forms do
not accept it. A targeted console update deliberately bypasses that protection:

```ruby
admin_user_id = 123 # Replace with the verified operator account ID.
changed = User.where(id: admin_user_id, deleted_at: nil, banned_at: nil)
              .update_all(admin: true, updated_at: Time.current)
raise "Expected exactly one active operator account" unless changed == 1
User.find(admin_user_id).admin?
```

Revoke access from the specific account with the same console boundary:

```ruby
changed = User.where(id: admin_user_id)
              .update_all(admin: false, updated_at: Time.current)
raise "Expected exactly one operator account" unless changed == 1
```

Administrator access is rechecked on each request; revocation applies to an
already signed-in account on its next request. Decisions also recheck the
operator's current eligibility inside the write transaction. Demo moderator
accounts are local-only. Production seeds do not remove accounts that may exist
from older deployments; an operator must review those separately.

### Console decisions

The console may use the same domain service. Check the trip's review evidence and
historical participation before deciding; do not change incident status directly.
Use a real, active administrator account independent of the trip:

```ruby
incident = NoShowIncident.find(incident_id)
reviewer = User.find(reviewer_id)
incident = NoShowIncidents::AdjudicateService.call(
  incident, status: :upheld, reviewer: reviewer,
  reason: "Reviewed participant reports and acceptance/cancellation timestamps.",
  expected_version: incident.lock_version
)
```

Use `:dismissed` for a dismissed case. `expected_version` defaults to the supplied
incident's `lock_version`; a stale case raises
`NoShowIncidents::AdjudicateService::Conflict`. Reload the incident and review the
new decision before deciding again. Do not automatically retry a conflict.
The service returns a fresh incident; keep that return value or reload before
another transition. Changed decisions append history and use a distinct
notification key, so confirmation, dismissal, and a later correction are each
reported once. An unchanged result adds no new decision.

The old waitlist no longer accepts subscriptions. Existing Subscriber records
and anonymous signed unsubscribe links are retained for compatibility and account
deletion cleanup; this is not an active newsletter signup feature.
