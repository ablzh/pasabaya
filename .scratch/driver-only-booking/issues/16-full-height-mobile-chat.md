# 16: Make mobile chats full height

**What to build:** On mobile, a trip discussion uses the full available screen with a compact header, scrollable messages and an accessible composer above the keyboard.

**Blocked by:** None (can start immediately).

**Status:** in-progress

- [ ] Mobile chat detail uses a 100dvh layout and hides global headers and footers while the discussion is open.
- [ ] The compact header includes a back action, trip route and relevant participant/driver context.
- [ ] The message stream uses the remaining height, reaches the latest messages initially, and follows new messages when already at the bottom without pulling someone away from older history.
- [ ] The composer stays reachable above the mobile keyboard and respects safe-area insets, orientation changes and changing viewport height.
- [ ] Read-only or unavailable chats show their applicable state rather than an active composer; existing deadline notices remain readable.
- [ ] Desktop navigation and trip-detail chat access continue to work.
- [ ] Use the existing text chat stack; do not add file/image upload infrastructure.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



## Implementation evidence

Resumed from integration 802a582 in isolated worktree; relevant browser behavior under TDD.
