# 18: Make ride cards consistent and clickable

**What to build:** Ride cards align neatly and open ride details from their surface, while drivers retain a separate Edit action and concise trip-note previews.

**Blocked by:** None (can start immediately).

**Status:** in-progress

- [ ] Cards stretch to equal height within each grid row, use a full-height column layout and keep footers aligned at the bottom.
- [ ] Remove the Show button. Clicking the card surface, including the author's name or avatar, opens the ride details.
- [ ] Provide keyboard-accessible ride navigation and a distinct owner Edit action that opens editing without activating ride navigation; avoid invalid nested interactive elements.
- [ ] Show at most two lines of note preview and truncate the preview to 110 characters without modifying stored notes.
- [ ] Require no more than 300 characters for newly created or changed notes, with clear form guidance and server validation.
- [ ] Preserve unchanged historical notes exceeding 300 characters; unrelated edits, cancellation and completion are not blocked, and existing notes are not silently truncated.
- [ ] Keep card destinations, audience visibility and owner controls correct wherever the shared card appears.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



## Implementation evidence

Resumed from integration 802a582 in isolated worktree; card and note behavior under TDD.
