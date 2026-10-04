# 12: Give chats explicit expiration deadlines

**What to build:** Trip participants see exactly when messaging stops and when chat history becomes unavailable, with one retention deadline for the entire conversation.

**Blocked by:** [03: Book rides with approximate departures](03-approximate-departure-booking.md).

**Status:** done

- [x] For an ordinary trip, messaging closes 24 hours after the booking cutoff, regardless of earlier automatic completion. Reading remains available for another 30 days to authorized participants.
- [x] Show separate full-date deadlines for messaging closure and history unavailability/scheduled deletion, explicitly labeled Philippine time (UTC+8).
- [x] Explain the distinction between inability to send messages and inability to read history; avoid an ambiguous single chat-closes label.
- [x] All messages in one conversation share its retention deadline instead of disappearing individually based on each message's age.
- [x] At the history deadline, the conversation and messages are inaccessible through inbox, direct navigation and submissions; schedule permanent deletion from the live database and make purge/recovery processing safe to repeat.
- [x] Describe the deletion deadline as scheduled live-database deletion; queue delays and backup retention must not be represented as exact erasure of every copy at that instant.
- [x] Update privacy and retention wording to reflect conversation-wide retention and the separate backup policy.
- [x] An already open chat cannot bypass send/read deadlines, and the composer and notices reflect expiry appropriately.
- [x] Existing conversations receive consistent deadlines without prematurely deleting still-retained history.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.






## Implementation evidence

Review fix 105f79a enforces exact send/history deadlines, scheduled message/read-state purge, open-browser and foreground-resume deadline transitions. Conversation-wide retention remains consistent.

Final integrated review and bin/ci passed at code commit 9c27ee66e6e2742cc536bb60ac5f96e21a9c946f: 424 Rails tests/2026 assertions and 31 system tests/2067 assertions; zero failures, errors or skips. Setup, Ruby style, templates, database consistency, ArchSpec, gem/importmap audits, Brakeman and seed replant all passed. No blocked automated checks. All 178 acceptance criteria are preserved verbatim.
