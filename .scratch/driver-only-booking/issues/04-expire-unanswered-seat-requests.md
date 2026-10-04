# 04: Expire unanswered seat requests

**What to build:** Passengers learn when an unanswered seat request expires, and drivers cannot accept requests after the ride's booking deadline.

**Blocked by:** [03: Book rides with approximate departures](03-approximate-departure-booking.md).

**Status:** done

- [x] Pending seat requests expire at the ride's booking cutoff for both exact and approximate departures, rather than waiting for automatic trip completion.
- [x] The passenger receives the message Your seat request expired without confirmation through the existing notification flow.
- [x] Pending requests reserve no inventory. Expiring them does not release or subtract seats, and accepted or declined requests are not changed.
- [x] An acceptance racing with expiry cannot succeed after cutoff, oversell seats or produce conflicting terminal states.
- [x] Repeated processing and recovery runs produce no duplicate expiry notifications and leave no overdue request displayed as pending.
- [x] Existing earlier closure and cancellation behavior continues to resolve requests consistently.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.




## Implementation evidence

Implemented pending seat request expiry at booking cutoff for exact and approximate departures with Bookings::ExpireService, scheduled BookingCutoffJob, TripAuditRecoveryJob sweep, and on-demand expiry guards in show actions. Passenger receives 'Your seat request expired without confirmation' notification with unique delivery keys preventing duplicates. Preserved inventory and existing cancellation flows, passing full bin/ci (338 Rails tests, 17 system tests).
