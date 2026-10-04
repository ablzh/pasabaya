# 18: Make ride cards consistent and clickable

**What to build:** Ride cards align neatly and open ride details from their surface, while drivers retain a separate Edit action and concise trip-note previews.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] Cards stretch to equal height within each grid row, use a full-height column layout and keep footers aligned at the bottom.
- [x] Remove the Show button. Clicking the card surface, including the author's name or avatar, opens the ride details.
- [x] Provide keyboard-accessible ride navigation and a distinct owner Edit action that opens editing without activating ride navigation; avoid invalid nested interactive elements.
- [x] Show at most two lines of note preview and truncate the preview to 110 characters without modifying stored notes.
- [x] Require no more than 300 characters for newly created or changed notes, with clear form guidance and server validation.
- [x] Preserve unchanged historical notes exceeding 300 characters; unrelated edits, cancellation and completion are not blocked, and existing notes are not silently truncated.
- [x] Keep card destinations, audience visibility and owner controls correct wherever the shared card appears.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.





## Implementation evidence

Feature c3ad31a and corrections 675b85e/c7a7770; ready tip e3fecd7 integrated at 17c4c73. Worker full bin/ci passed: 407 Rails tests/1933 assertions and 21 system tests/1945 assertions, all other checks passed. Combined integration system checks passed 11 tests/155 assertions; ride model/request tests passed 70 tests/277 assertions, covering changed-note limits, unchanged legacy notes, and navigation. Final all-ticket CI and review tracked separately.

Final integrated review and bin/ci passed at code commit 9c27ee66e6e2742cc536bb60ac5f96e21a9c946f: 424 Rails tests/2026 assertions and 31 system tests/2067 assertions; zero failures, errors or skips. Setup, Ruby style, templates, database consistency, ArchSpec, gem/importmap audits, Brakeman and seed replant all passed. No blocked automated checks. All 178 acceptance criteria are preserved verbatim.
