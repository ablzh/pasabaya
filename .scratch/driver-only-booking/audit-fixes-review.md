# Driver-only booking audit fixes

This report supersedes the earlier completion assessment at `e6dd779`. The audit found requirements not covered by the earlier green CI. The fixes below are integrated locally on `artem/driver-only-booking`; the original checkout and unrelated work are preserved. No push or PR was performed.

Tested code commit: `a131b2173b02a6cff1973bfd655cd75ffb650d6d`.

## Fixes and evidence

| Finding | Final behavior | Regression evidence |
| --- | --- | --- |
| Incomplete drafts crash chats | Drafts are excluded from chat authorization and inbox candidates | Chat request: missing-route draft no longer raises |
| Retained canceled history can be deleted | Owner deletion is blocked during conversation retention; permanent historical protections take precedence | Owner DELETE preserves future canceled trip and messages |
| Queued private previews bypass fresh access | Delivery rechecks participation, hub access and retention | Subscribed channel transport before/after revocation, expiry and ride deletion |
| Exact-time dates use UTC | Search uses departure_date; old and corrective migrations convert UTC timestamps to Philippine dates | Early-morning exact search and legacy migration repair |
| Queued route alerts lose saved filters | Notification retains its originating subscription; delivery rechecks its ordered route/date/audience and eligibility | Legitimate route/date/audience edits suppress delivery; restored match permits one delivery |
| Subscription uniqueness breaks repeated use | Active-only index normalizes nullable filters; terminal history may repeat | Repeated cancellation/fulfillment and database uniqueness bypassing validation |
| Drivers cannot close requests early | Dedicated operation expires pending requests while preserving accepted riders, inventory, trip and chat | Request and browser closure, stale booking attempts, idempotency |
| Replies clear unseen messages | Only explicit reading advances markers; unread considers all unseen incoming messages | Foreground above latest → incoming → reply stays unread → reach latest clears |
| Cleanup runs before dependent schema | Historical cleanup is deferred to the final booking-schema migration | Populated pre-feature schema upgrades successfully; production/staging preserve data |
| Already-booked subscribers receive alerts | Matching and delivery exclude pending/accepted requests; cancellation restores eligibility | Public matching red/green and queued job eligibility/retry |
| Sending before cable connects hides saved message | Successful Turbo response appends the saved message directly; stable IDs deduplicate broadcasts | Request red/green and browser rendering exactly one message |

The duplicated past-validation checks were removed as maintenance. The audit's duplicate visible-error assertion was incorrect: Rails already deduplicates identical errors before returning them. Public validation regressions were green before and after; no failing red is claimed.

The optional repeated expiration rule was consolidated into RidePost#booking_requests_closed?. Existing public expiry/closure behavior and concurrent processing tests pass.

## Standards

Read-only review of `e6dd779...a131b21`: no documented-standard violations or remaining heuristic findings. Native Rails facilities are used; no dependencies were added. The review's repeated-rule suggestion was resolved.

## Spec

Read-only review of `e6dd779...a131b21`: no remaining actionable spec findings. The additional existing-booking eligibility gap identified during re-review was fixed and tested before completion.

## Verification

Full bin/ci passed on the tested code commit:

- Setup, Ruby style, template lint, database consistency, ArchSpec, gem audit, importmap audit, Brakeman and seeds passed.
- Rails: 450 tests, 2188 assertions, zero failures/errors/skips.
- System: 32 tests, 2082 assertions, zero failures/errors/skips.
- CI log: /Users/uzver/Documents/Codex/2026-10-03/use-to-spec-to-create-a/outputs/driver-only-booking-audit-fixes-ci.log
- First integrated failure log retained separately as driver-only-booking-audit-fixes-ci-first-failure.log; its failures were resolved before the final gate.
- Red/green logs: outputs/audit-fixes/chat/, outputs/audit-fixes/departure/, outputs/audit-route/, and outputs/audit-migration-{red,green}.log. Booking concurrency, direct send response and integration regression logs are also under outputs/.

All 20 local tickets are done. Their 178 acceptance criteria remain verbatim, and the original tracker and committed copies are byte-identical. Isolated implementation worktrees provided each worker the tracked spec and tickets. New fixes have genuine behavior-failure evidence where a defect was reproducible; concurrent/recovery coverage added to already-correct behavior is recorded as passing coverage, not invented red.

The old serial expiry test was renamed and supplemented by three workers using separate database connections and a start barrier. Concurrent route-alert workers overlap at the SQL boundary and record one event. The full local database backup has mode 0600, verified after the permission change.

## Unverified checks

No automated CI check remains blocked. The worker's npm DNS failure was resolved for integrated CI; Herb passed. Physical iOS keyboard and device safe-area behavior remains unverified; browser viewport/orientation and simulated keyboard coverage passed. Historical TDD execution for the original implementation cannot be independently established from the surviving logs; one old red log contains an invalid test invocation. This completion record does not retroactively claim that every original ticket was implemented test-first.

Standards: 0 findings (no remaining worst issue). Spec: 0 findings (no remaining worst issue).
