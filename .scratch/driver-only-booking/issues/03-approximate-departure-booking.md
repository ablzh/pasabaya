# 03: Book rides with approximate departures

**What to build:** A driver publishes a dated ride using an approximate departure choice or an exact time. Passengers can book approximate departures throughout the selected Philippine date.

**Blocked by:** [02: Explicit publishing with optional arrival](02-explicit-publishing-optional-arrival.md).

**Status:** done

- [x] Every newly published ride requires a departure date and one choice: Morning, Afternoon, Evening, Night, Exact Time or Flexible. Approximate choices do not fabricate a confirmed exact departure timestamp.
- [x] Use SVG Heroicons, not emoji. Display hints are Morning 06:00–12:00, Afternoon 12:00–17:00, Evening 17:00–21:00, Night 21:00–midnight, and Flexible any time on the selected date. Exact Time exposes a precise time picker, including midnight–06:00.
- [x] Approximate choices are descriptive hints: requests and driver acceptance remain open until midnight ending the selected date in Asia/Manila, even if the named period has passed. Exact-time booking closes at the specified departure.
- [x] Drivers can close requests earlier. Past dates and elapsed exact departures cannot be newly published or booked, and the server enforces boundaries even when a browser remains open.
- [x] Cards, details, search dates, upcoming/history classification and completion scheduling consistently use the selected Philippine date and the agreed booking cutoff. Preserve existing exact-time rides.
- [x] After an accepted booking, the departure date and selected approximate choice or exact time are locked. Coordinate within the published choice in chat; moving outside it requires cancellation and a new offer.
- [x] Private trip feedback and no-show reporting become eligible after the selected date ends for approximate rides and after departure for exact-time rides. Preserve participant eligibility and existing manual incident decisions; pending allegations do not create penalties.
- [x] Extend the automatic completion policy from ticket 02 to approximate departures, with no completion before booking cutoff and the no-arrival fallback of cutoff plus 24 hours.
- [x] Do not add an administrative incident interface, new public ratings or analytics as part of this work.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.




## Implementation evidence

Implemented approximate departure choices (morning, afternoon, evening, night, exact_time, flexible) and departure date with Heroicons, booking cutoff at midnight Manila time for approximate choices and departure time for exact departures. Locked schedule attributes on accepted bookings, updated review and completion eligibility, and passed full bin/ci (330 Rails tests, 17 system tests).
