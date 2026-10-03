# 02: Explicit publishing with optional arrival

**What to build:** A driver deliberately saves a draft or publishes an exact-time ride without being required to predict an arrival time. Elapsed rides move into history reliably.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Save draft and Publish ride are distinct intentional actions. Editing a draft does not publish it automatically.
- [ ] Publishing requires a valid route, future exact departure and available passenger seats; expected arrival is optional, and its label does not suggest it is required.
- [ ] Incomplete rides can be saved as drafts and cannot become publicly bookable before a successful explicit publish action.
- [ ] With expected arrival supplied, automatic completion occurs at expected arrival plus two hours, but never before the booking cutoff. Without arrival, automatic completion occurs at booking cutoff plus 24 hours.
- [ ] Drafts and canceled rides are not automatically completed. Both normal scheduling and recovery processing handle published rides with no arrival, and repeating completion processing does not duplicate side effects.
- [ ] Automatic completion does not claim verified travel: user-facing history labels use Past for automatically elapsed rides. Full upcoming rides are not mistaken for completed rides.
- [ ] Existing exact-time rides and accepted-booking departure restrictions continue to work.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.

