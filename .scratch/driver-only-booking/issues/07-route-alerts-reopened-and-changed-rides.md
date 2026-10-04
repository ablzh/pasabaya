# 07: Alert when existing rides become bookable

**What to build:** A waiting passenger can receive their one-shot route alert when an existing ride gains available seats or changes onto their subscribed route.

**Blocked by:** [06: Subscribe to newly published matching rides](06-one-shot-route-alert-subscriptions.md).

**Status:** done

- [x] Restoring available seats on a previously full ride can trigger a matching active subscription.
- [x] Changing a ride's route or other matching criteria can trigger a subscription that the ride newly satisfies.
- [x] Only currently published, visible, bookable offers match; canceled, drafted, expired or still-full rides do not generate alerts.
- [x] Reuse the saved route/date/audience matching, delivery-time access checks, one-shot consumption and cancellation/expiry behavior from ticket 06.
- [x] Concurrent inventory changes, route edits and retry processing cannot notify a consumed subscription twice or repeatedly alert for an unchanged match.
- [x] Cover at least the reopened-seat and route-change scenarios as behavior regressions.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.




## Implementation evidence

Implemented reopened seat and route/criteria change alert triggers in RidePost, covered with regression tests in CancelServiceTest and MatchServiceTest. Verified full clean bin/ci.
