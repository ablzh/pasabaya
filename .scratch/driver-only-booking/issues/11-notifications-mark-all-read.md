# 11: Improve notifications and mark all read

**What to build:** Members clearly distinguish unread notifications and clear all existing unread notifications in one action, with badges synchronized across open sessions.

**Blocked by:** None (can start immediately).

**Status:** in-progress

- [ ] Unread entries have a distinct vibrant blue dot, bold title and sufficient contrast, rather than relying on a faint background alone.
- [ ] Add the recipient/creation composite index for the notification listing while retaining indexes needed for unread counts. Do not promise a hardware-independent sub-millisecond query time.
- [ ] Provide a Mark all as read action with an SVG Heroicon.
- [ ] Mark every unread notification belonging to the current recipient that existed at the operation's snapshot, including entries older than the displayed list. Preserve notifications arriving after that snapshot.
- [ ] Update visible entry styling and unread counts through Turbo across open sessions, including when bulk updates bypass per-record callbacks.
- [ ] The action is authorized for the current recipient only, is safe to repeat, and does not mark another user's notifications read.
- [ ] Cover the older-than-visible-list and concurrent-new-notification cases.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



## Implementation evidence

Isolated implementation started from d2c24db; snapshot and recipient isolation tests passing.
