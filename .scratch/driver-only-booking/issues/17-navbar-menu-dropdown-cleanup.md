# 17: Clean up navbar and dropdown behavior

**What to build:** Members use a smaller profile menu with notifications on the avatar, and the profile dropdown opens directly beneath its trigger without sliding across the page.

**Blocked by:** None (can start immediately).

**Status:** in-progress

- [ ] Remove the standalone notification bell from the top bar and display the unread notification badge on the avatar with accessible notification-count information.
- [ ] The profile dropdown contains Profile, Settings, Notifications with unread count, and Sign out.
- [ ] Remove duplicate My Trips and Hubs dropdown entries; retain the top-level Hubs destination and a working Profile link.
- [ ] Notification counts remain synchronized when notifications become read or arrive, including Mark all as read once ticket 11 lands.
- [ ] On first opening, the dropdown fades/scales at its correctly positioned location; changes in horizontal placement do not animate from the origin.
- [ ] Keyboard operation, focus handling, dismissal and responsive positioning remain functional.
- [ ] Preserve the Chats navigation added by ticket 15 when it is present; this cleanup does not depend on unread-chat implementation.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



## Implementation evidence

Resumed from integration 802a582 in isolated worktree; navbar behavior under TDD.
