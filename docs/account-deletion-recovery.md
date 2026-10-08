# Account deletion and database recovery

Account deletion writes a minimal deletion-intent journal (user ID, account
creation time, deletion time) before changing the primary database. In production,
`ACCOUNT_DELETION_REGISTRY_PATH` points to `/rails/deletion_registry/accounts.jsonl`
on the separate `pasabaya_deletion_registry` volume. Account creation time prevents
an ID reused after restoration from being mistaken for the deleted account.

On the first installation or upgrade to this registry, while the current database
is still authoritative, run `bin/rails retention:initialize_registry` once before
starting the web server. This creates the journal and imports existing deleted
accounts. Initialization refuses to overwrite an existing journal. Never use this
command to bypass a missing journal after restoring a backup.

For database recovery:

1. Stop the web server and workers before restoring anything.
2. Preserve the current deletion-registry volume. Restore database files and
   uploaded files without replacing `/rails/deletion_registry` with an older copy.
   Restic backs up the registry separately from database snapshots; after a host
   loss, recover the latest available journal first. If the current deletion
   history cannot be recovered, keep the application offline until it is reconciled.
3. Run `bin/rails db:restore:finish`. A missing or invalid journal, or a failed
   anonymization, causes the command to fail. Do not serve traffic on failure.
4. Start the application. The container entrypoint also runs retention scrubbing
   before starting Rails.

Detached avatar blob IDs, storage keys, and service names remain in database
cleanup records until their files are removed. This also allows recovery when
storage deletion fails after a blob row has already been removed. Cleanup enqueue
failures do not undo account deletion; the hourly cleanup task and retention scrub
retry pending purges.
