# 16: Make mobile chats full height

**What to build:** On mobile, a trip discussion uses the full available screen with a compact header, scrollable messages and an accessible composer above the keyboard.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] Mobile chat detail uses a 100dvh layout and hides global headers and footers while the discussion is open.
- [x] The compact header includes a back action, trip route and relevant participant/driver context.
- [x] The message stream uses the remaining height, reaches the latest messages initially, and follows new messages when already at the bottom without pulling someone away from older history.
- [x] The composer stays reachable above the mobile keyboard and respects safe-area insets, orientation changes and changing viewport height.
- [x] Read-only or unavailable chats show their applicable state rather than an active composer; existing deadline notices remain readable.
- [x] Desktop navigation and trip-detail chat access continue to work.
- [x] Use the existing text chat stack; do not add file/image upload infrastructure.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.





## Implementation evidence

Feature bc953d9; ready tip a694647 integrated at 8f5c586. Worker full bin/ci passed: 402 Rails tests/1904 assertions and 23 system tests/1992 assertions, all other checks passed. Combined integration 17c4c73 mobile/chat/unread/navbar/card/ride system checks passed 11 tests/155 assertions. Physical iOS keyboard/device safe-area behavior was not exercised; synthetic visualViewport/orientation and CSS safe-area coverage passed. Final all-ticket CI and review tracked separately.

Final integrated review and bin/ci passed at code commit 9c27ee66e6e2742cc536bb60ac5f96e21a9c946f: 424 Rails tests/2026 assertions and 31 system tests/2067 assertions; zero failures, errors or skips. Setup, Ruby style, templates, database consistency, ArchSpec, gem/importmap audits, Brakeman and seed replant all passed. No blocked automated checks. All 178 acceptance criteria are preserved verbatim. Physical iOS keyboard/device safe-area testing remains unverified; synthetic viewport/orientation/safe-area and browser regressions passed.

### Audit follow-up — 2026-10-04

Full system CI passes, including viewport/orientation and simulated keyboard behavior. Physical iOS keyboard and device safe-area behavior has not been verified.

Integrated code: `a131b2173b02a6cff1973bfd655cd75ffb650d6d`. Full `bin/ci`: 450 Rails tests / 2188 assertions and 32 system tests / 2082 assertions, no failures, errors or skips. Spec and Standards re-reviews have no remaining actionable findings. Historical TDD execution cannot be independently verified; new behavior fixes have recorded red/green evidence.
