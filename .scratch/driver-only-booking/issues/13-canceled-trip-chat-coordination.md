# 13: Preserve coordination after trip cancellation

**What to build:** The driver and previously accepted passengers can coordinate briefly after an open trip is canceled, then read the conversation until its clearly announced retention deadline.

**Blocked by:** [12: Give chats explicit expiration deadlines](12-chat-expiration-deadlines-retention.md).

**Status:** ready-for-agent

- [ ] Canceling a trip with an open chat preserves access for its driver and previously accepted passengers instead of immediately hiding the conversation.
- [ ] Messaging remains available for 24 hours after cancellation, followed by 30 more days of read-only history and scheduled live-database deletion.
- [ ] Cancellation never reopens a chat whose messaging window is already closed or restores history that has become unavailable.
- [ ] Pending, declined or unrelated users cannot gain access through cancellation; existing authorization rules for individually canceled bookings remain intact.
- [ ] Bans, account deletion and loss of required hub access still revoke access immediately; historical participation does not bypass these restrictions.
- [ ] Participants see the cancellation state and the revised messaging and history deadlines in Philippine time, consistently in the chat and any inbox entry.
- [ ] Repeated cancellation processing does not extend deadlines or duplicate retention jobs.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.

