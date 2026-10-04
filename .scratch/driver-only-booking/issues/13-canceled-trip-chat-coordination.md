# 13: Preserve coordination after trip cancellation

**What to build:** The driver and previously accepted passengers can coordinate briefly after an open trip is canceled, then read the conversation until its clearly announced retention deadline.

**Blocked by:** [12: Give chats explicit expiration deadlines](12-chat-expiration-deadlines-retention.md).

**Status:** done

- [x] Canceling a trip with an open chat preserves access for its driver and previously accepted passengers instead of immediately hiding the conversation.
- [x] Messaging remains available for 24 hours after cancellation, followed by 30 more days of read-only history and scheduled live-database deletion.
- [x] Cancellation never reopens a chat whose messaging window is already closed or restores history that has become unavailable.
- [x] Pending, declined or unrelated users cannot gain access through cancellation; existing authorization rules for individually canceled bookings remain intact.
- [x] Bans, account deletion and loss of required hub access still revoke access immediately; historical participation does not bypass these restrictions.
- [x] Participants see the cancellation state and the revised messaging and history deadlines in Philippine time, consistently in the chat and any inbox entry.
- [x] Repeated cancellation processing does not extend deadlines or duplicate retention jobs.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.






## Implementation evidence

Review fix 105f79a provides full24h after cancellation of an open chat without reopening closed/expired history; required hub access applies to drivers too; live cancellation refresh updates notices/deadlines.

Final integrated review and bin/ci passed at code commit 9c27ee66e6e2742cc536bb60ac5f96e21a9c946f: 424 Rails tests/2026 assertions and 31 system tests/2067 assertions; zero failures, errors or skips. Setup, Ruby style, templates, database consistency, ArchSpec, gem/importmap audits, Brakeman and seed replant all passed. No blocked automated checks. All 178 acceptance criteria are preserved verbatim.

### Audit follow-up — 2026-10-04

Future canceled trips retain coordination and read-only history until their deadlines. Deletion is blocked during retention; revoked membership, unrelated participants, deleted rides and expired history cannot receive queued private previews.

Integrated code: `a131b2173b02a6cff1973bfd655cd75ffb650d6d`. Full `bin/ci`: 450 Rails tests / 2188 assertions and 32 system tests / 2082 assertions, no failures, errors or skips. Spec and Standards re-reviews have no remaining actionable findings. Historical TDD execution cannot be independently verified; new behavior fixes have recorded red/green evidence.
