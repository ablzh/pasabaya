# 15: Track unread conversations across devices

**What to build:** Members see which conversations need attention and a Chats badge counting unread conversations, with reading state shared across devices.

**Blocked by:** [14: Add the chats inbox](14-chats-inbox.md).

**Status:** in progress

- [x] Persist per-user conversation reading state. The navbar badge counts unread conversations, not total unread messages, and the inbox identifies those conversations.
- [x] Add a Chats navigation link with an SVG message icon and unread-conversation badge.
- [ ] A conversation becomes read when it is in the foreground and the user reaches its latest message; merely opening a background tab or remaining scrolled above the latest message does not clear it.
- [x] Incoming messages update unread state and counts; a user's own messages do not mark that user's conversation unread.
- [x] Reading state and badge changes synchronize across open sessions and devices through the existing real-time mechanisms.
- [x] Only authorized, retained conversations contribute to the inbox and badge. Expired history and revoked access do not leave phantom unread counts.
- [ ] Read updates racing with incoming messages do not incorrectly clear a newer unseen message.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.







## Implementation evidence

Review fix 105f79a validates real conversation message IDs, atomically advances monotonic markers, synchronizes author badges and shares latest-message query. Race and background/scroll regressions pass.

Final integrated review and bin/ci passed at code commit 9c27ee66e6e2742cc536bb60ac5f96e21a9c946f: 424 Rails tests/2026 assertions and 31 system tests/2067 assertions; zero failures, errors or skips. Setup, Ruby style, templates, database consistency, ArchSpec, gem/importmap audits, Brakeman and seed replant all passed. No blocked automated checks. All 178 acceptance criteria are preserved verbatim.
