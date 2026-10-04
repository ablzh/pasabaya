# 20: Organize profile trips and drafts

**What to build:** Members manage their offers, drafts, passenger bookings and history on their own profile, while other members see only eligible upcoming driver offers.

**Blocked by:** [03: Book rides with approximate departures](03-approximate-departure-booking.md).

**Status:** done

- [x] The owner sees active rides as full cards, including full upcoming offers. Departed rides still awaiting automatic completion remain distinguishable from completed history.
- [x] Show drafts only to the owner in a compact management section with explicit Publish and Delete actions; incomplete drafts display actionable publish validation.
- [x] Show past and canceled rides in a compact list with date, route, appropriate Past/Canceled status and a View action where the retained trip is accessible.
- [x] Do not describe a full ride as completed or an automatically elapsed ride as verified travel.
- [x] Keep the owner's passenger bookings in a separate section rather than mixing them with driver offers.
- [x] Other signed-in members see only eligible upcoming published offers, subject to audience authorization. Drafts, history and passenger bookings remain owner-only.
- [x] Profile actions honor booking/deletion restrictions and the explicit publishing, departure-date and automatic-completion behavior from tickets 02 and 03.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.




## Implementation evidence

Implementation 2a06311 integrated at c03c47f. Upcoming full offers stay full cards; owner-only compact drafts have authorized Publish/Delete with actionable validation; departed pending-completion rides and Past/Canceled history are separate; passenger bookings remain separate and private. 20 targeted request tests/199 assertions, 43 related request/model tests/288 assertions, and full bin/ci green (402 Rails, 19 system). No blocked CI checks.
