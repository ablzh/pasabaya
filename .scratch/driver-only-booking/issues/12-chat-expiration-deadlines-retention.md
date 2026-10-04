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

Added chat expiration deadlines (chat_messaging_closes_at 24h after booking cutoff, chat_history_unavailable_at 30 days later) and conversation-wide retention. Updated RidePost#chat_writable?, chat_readable?, chat_expired?, user_authorized_for_chat? to enforce read-only and expiration boundaries. Displayed separate full-date deadlines in Philippine time (UTC+8) and distinct closure/deletion messaging notices in show and form views. Implemented ChatRetentionJob, updated PurgeOldChatMessagesJob, TripAuditRecoveryJob, and retention:scrub for conversation-wide purging. Updated privacy policy sections 5 and 7. Added unit, controller, and job tests. Full bin/ci passed (372 Rails tests, 17 system tests).
