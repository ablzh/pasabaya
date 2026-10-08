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
