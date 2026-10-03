# 20: Organize profile trips and drafts

**What to build:** Members manage their offers, drafts, passenger bookings and history on their own profile, while other members see only eligible upcoming driver offers.

**Blocked by:** [03: Book rides with approximate departures](03-approximate-departure-booking.md).

**Status:** ready-for-agent

- [ ] The owner sees active rides as full cards, including full upcoming offers. Departed rides still awaiting automatic completion remain distinguishable from completed history.
- [ ] Show drafts only to the owner in a compact management section with explicit Publish and Delete actions; incomplete drafts display actionable publish validation.
- [ ] Show past and canceled rides in a compact list with date, route, appropriate Past/Canceled status and a View action where the retained trip is accessible.
- [ ] Do not describe a full ride as completed or an automatically elapsed ride as verified travel.
- [ ] Keep the owner's passenger bookings in a separate section rather than mixing them with driver offers.
- [ ] Other signed-in members see only eligible upcoming published offers, subject to audience authorization. Drafts, history and passenger bookings remain owner-only.
- [ ] Profile actions honor booking/deletion restrictions and the explicit publishing, departure-date and automatic-completion behavior from tickets 02 and 03.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.

