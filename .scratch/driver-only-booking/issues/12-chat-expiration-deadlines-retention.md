# 12: Give chats explicit expiration deadlines

**What to build:** Trip participants see exactly when messaging stops and when chat history becomes unavailable, with one retention deadline for the entire conversation.

**Blocked by:** [03: Book rides with approximate departures](03-approximate-departure-booking.md).

**Status:** ready-for-agent

- [ ] For an ordinary trip, messaging closes 24 hours after the booking cutoff, regardless of earlier automatic completion. Reading remains available for another 30 days to authorized participants.
- [ ] Show separate full-date deadlines for messaging closure and history unavailability/scheduled deletion, explicitly labeled Philippine time (UTC+8).
- [ ] Explain the distinction between inability to send messages and inability to read history; avoid an ambiguous single chat-closes label.
- [ ] All messages in one conversation share its retention deadline instead of disappearing individually based on each message's age.
- [ ] At the history deadline, the conversation and messages are inaccessible through inbox, direct navigation and submissions; schedule permanent deletion from the live database and make purge/recovery processing safe to repeat.
- [ ] Describe the deletion deadline as scheduled live-database deletion; queue delays and backup retention must not be represented as exact erasure of every copy at that instant.
- [ ] Update privacy and retention wording to reflect conversation-wide retention and the separate backup policy.
- [ ] An already open chat cannot bypass send/read deadlines, and the composer and notices reflect expiry appropriately.
- [ ] Existing conversations receive consistent deadlines without prematurely deleting still-retained history.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.

