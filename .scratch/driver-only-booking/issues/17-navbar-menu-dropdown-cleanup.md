# 17: Clean up navbar and dropdown behavior

**What to build:** Members use a smaller profile menu with notifications on the avatar, and the profile dropdown opens directly beneath its trigger without sliding across the page.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] Remove the standalone notification bell from the top bar and display the unread notification badge on the avatar with accessible notification-count information.
- [x] The profile dropdown contains Profile, Settings, Notifications with unread count, and Sign out.
- [x] Remove duplicate My Trips and Hubs dropdown entries; retain the top-level Hubs destination and a working Profile link.
- [x] Notification counts remain synchronized when notifications become read or arrive, including Mark all as read once ticket 11 lands.
- [x] On first opening, the dropdown fades/scales at its correctly positioned location; changes in horizontal placement do not animate from the origin.
- [x] Keyboard operation, focus handling, dismissal and responsive positioning remain functional.
- [x] Preserve the Chats navigation added by ticket 15 when it is present; this cleanup does not depend on unread-chat implementation.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.





## Implementation evidence

Implementation 840500a plus 025e8e2 integrated at 2f949aa. Bell removed; live accessible avatar count and exact four-link menu; top-level Hubs and Chats retained. First-frame placement, keyboard focus/Escape/dismissal, resize and streaming/read-all behavior covered. Full combined bin/ci green: 403 Rails tests/1922 assertions, 21 system tests/1961 assertions; all checks passed without skips or blockers.

Final integrated review and bin/ci passed at code commit 9c27ee66e6e2742cc536bb60ac5f96e21a9c946f: 424 Rails tests/2026 assertions and 31 system tests/2067 assertions; zero failures, errors or skips. Setup, Ruby style, templates, database consistency, ArchSpec, gem/importmap audits, Brakeman and seed replant all passed. No blocked automated checks. All 178 acceptance criteria are preserved verbatim.
