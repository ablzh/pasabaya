# 13: Preserve coordination after trip cancellation

**What to build:** The driver and previously accepted passengers can coordinate briefly after an open trip is canceled, then read the conversation until its clearly announced retention deadline.

**Blocked by:** [12: Give chats explicit expiration deadlines](12-chat-expiration-deadlines-retention.md).

**Status:** done

- [x] Canceling a trip with an open chat preserves access for its driver and previously accepted passengers instead of immediately hiding the conversation.
- [x] Messaging remains available for 24 hours after cancellation, followed by 30 more days of read-only history and scheduled live-database deletion.
- [x] Cancellation never reopens a chat whose messaging window is already closed or restores history that has become unavailable.
- [x] Pending, declined or unrelated users cannot gain access through cancellation; existing authorization rules for individually canceled bookings remain intact.
- [x] Bans, account deletion and loss of required hub access still revoke access immediately; historical participation does not bypass these restrictions.
- [x] Participants see the cancellation state and the revised messaging and history deadlines in Philippine time, consistently in the chat and any inbox entry.
- [x] Repeated cancellation processing does not extend deadlines or duplicate retention jobs.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.




## Implementation evidence

Preserved chat coordination access for driver and previously accepted passengers upon trip cancellation. Added canceled_at column to ride_posts via migration 20261003180050. Computed chat_messaging_closes_at as min(ordinary_close, canceled_at + 24.hours) and chat_history_unavailable_at as chat_messaging_closes_at + 30.days, preventing reopening closed chats or restoring expired history. Updated RidePost#previously_accepted_bookings, participants, chat_unlocked?, and user_authorized_for_chat? to preserve access while keeping individually canceled bookings, pending requesters, and banned/revoked members excluded. Updated RidePosts::CancelService to set canceled_at, eliminate N+1 queries, and avoid extending deadlines or duplicating jobs on repeated runs. Updated chat inbox and ride show views to clearly show cancellation state and revised deadlines in Philippine time (UTC+8). Added model and controller tests. Full bin/ci passed (383 Rails tests, 17 system tests).
