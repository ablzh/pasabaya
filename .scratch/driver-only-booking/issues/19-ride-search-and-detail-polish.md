# 19: Polish ride search and detail pages

**What to build:** People search and inspect rides through aligned, readable screens, with owner-specific details and a helpful destination when a ride no longer exists.

**Blocked by:** None (can start immediately).

**Status:** in-progress

- [ ] Allow the ride-board subtitle to use its header container width without the previous narrow desktop limit.
- [ ] Align origin/destination/date labels at the top of the search grid and show Leave blank to see all upcoming rides on this route below the optional date field.
- [ ] The Request a Seat card, pickup-notes input and submission button follow the app's light theme and retain appropriate dark-theme styling.
- [ ] A driver viewing their own trip does not see their own driver introduction card; label notes Your Trip Notes for the owner and Driver's Notes for others.
- [ ] Navigating to a deleted or missing ride redirects to the Ride Board with The trip is no longer available, including entry from an old ride notification.
- [ ] Keep missing-ride handling scoped to ride resolution: do not swallow unrelated missing-record exceptions or turn authorization failures into permission to view a ride.
- [ ] Preserve accepted-booking/history protections on deletion and do not delete a retained trip simply to satisfy the redirect behavior.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



## Implementation evidence

Implementation commit 388f223 integrated; 33 request tests pass. Serialized full CI verification pending.
