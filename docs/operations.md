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

There is no administrative web UI. A trusted operator uses `bin/kamal console`
and the domain service to review pending or appealed no-show incidents. Check the
trip's review evidence and historical participation before deciding. The service
records the reviewer and reason and maintains strikes, booking freezes, and
notifications; changing `status` directly bypasses that behavior.

```ruby
incident = NoShowIncident.find(incident_id)
reviewer = User.find(reviewer_id)
NoShowIncidents::AdjudicateService.call(
  incident, status: :upheld, reviewer: reviewer,
  reason: "Document the evidence and decision here"
)
```

Use `:dismissed` for a dismissed case, including reversing an earlier decision.
Record a real operator account and a meaningful reason. Console access is the
authorization boundary; the `admin` flag does not expose a moderation interface.
Demo moderator accounts are local-only. Production seeds do not provision users
and do not remove any demo accounts that may exist from older deployments; an
operator must review those separately.

The old waitlist no longer accepts subscriptions. Existing Subscriber records
and anonymous signed unsubscribe links are retained for compatibility and account
deletion cleanup; this is not an active newsletter signup feature.
