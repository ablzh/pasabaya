# 02: Explicit publishing with optional arrival

**What to build:** A driver deliberately saves a draft or publishes an exact-time ride without being required to predict an arrival time. Elapsed rides move into history reliably.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] Save draft and Publish ride are distinct intentional actions. Editing a draft does not publish it automatically.
- [x] Publishing requires a valid route, future exact departure and available passenger seats; expected arrival is optional, and its label does not suggest it is required.
- [x] Incomplete rides can be saved as drafts and cannot become publicly bookable before a successful explicit publish action.
- [x] With expected arrival supplied, automatic completion occurs at expected arrival plus two hours, but never before the booking cutoff. Without arrival, automatic completion occurs at booking cutoff plus 24 hours.
- [x] Drafts and canceled rides are not automatically completed. Both normal scheduling and recovery processing handle published rides with no arrival, and repeating completion processing does not duplicate side effects.
- [x] Automatic completion does not claim verified travel: user-facing history labels use Past for automatically elapsed rides. Full upcoming rides are not mistaken for completed rides.
- [x] Existing exact-time rides and accepted-booking departure restrictions continue to work.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.





## Implementation evidence

Implemented explicit Save draft and Publish ride actions, optional expected arrival, draft incomplete persistence with nullable route, automatic completion at arrival+2h or cutoff+24h, Past history labeling, and prevented draft intent from reopening canceled or completed rides. Passing full bin/ci.

Final integrated review and bin/ci passed at code commit 9c27ee66e6e2742cc536bb60ac5f96e21a9c946f: 424 Rails tests/2026 assertions and 31 system tests/2067 assertions; zero failures, errors or skips. Setup, Ruby style, templates, database consistency, ArchSpec, gem/importmap audits, Brakeman and seed replant all passed. No blocked automated checks. All 178 acceptance criteria are preserved verbatim.
