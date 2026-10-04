# 11: Improve notifications and mark all read

**What to build:** Members clearly distinguish unread notifications and clear all existing unread notifications in one action, with badges synchronized across open sessions.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] Unread entries have a distinct vibrant blue dot, bold title and sufficient contrast, rather than relying on a faint background alone.
- [x] Add the recipient/creation composite index for the notification listing while retaining indexes needed for unread counts. Do not promise a hardware-independent sub-millisecond query time.
- [x] Provide a Mark all as read action with an SVG Heroicon.
- [x] Mark every unread notification belonging to the current recipient that existed at the operation's snapshot, including entries older than the displayed list. Preserve notifications arriving after that snapshot.
- [x] Update visible entry styling and unread counts through Turbo across open sessions, including when bulk updates bypass per-record callbacks.
- [x] The action is authorized for the current recipient only, is safe to repeat, and does not mark another user's notifications read.
- [x] Cover the older-than-visible-list and concurrent-new-notification cases.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.





## Implementation evidence

Added User#mark_all_notifications_as_read! capturing MAX id snapshot and broadcasting list/count streams, vibrant blue unread dot with bold font styling, composite listing index on recipient_id and created_at, Mark all as read collection action, and regression tests for older-than-50 entries and concurrent new notification isolation. Passing full bin/ci with 315 Rails tests and 17 system tests.

Final integrated review and bin/ci passed at code commit 9c27ee66e6e2742cc536bb60ac5f96e21a9c946f: 424 Rails tests/2026 assertions and 31 system tests/2067 assertions; zero failures, errors or skips. Setup, Ruby style, templates, database consistency, ArchSpec, gem/importmap audits, Brakeman and seed replant all passed. No blocked automated checks. All 178 acceptance criteria are preserved verbatim.
