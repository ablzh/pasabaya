# 06: Subscribe to newly published matching rides

**What to build:** When a route search has no rides, a passenger can subscribe once and receive an email and in-app notification when a matching driver offer is first published.

**Blocked by:** [03: Book rides with approximate departures](03-approximate-departure-booking.md).

**Status:** ready-for-agent

- [ ] A signed-in user's empty route search shows No rides found for this route yet and a Notify me when a driver posts this route action.
- [ ] A guest sees the searched origin and destination plus a sign-in/create-account action that preserves the search context.
- [ ] Subscribe to the exact ordered origin/destination pair, preserving a selected date and audience filters. With no date selected, match upcoming rides. Explain the one-shot behavior before subscribing.
- [ ] A newly published matching, bookable driver offer produces an email and an in-app notification with a usable ride link. Exclude the subscriber's own offers and rides they cannot book.
- [ ] Recheck audience access and booking eligibility when matching and before delivery, including hub membership and ladies-only restrictions; do not disclose a private ride after access has been lost.
- [ ] End the subscription after its first successfully recorded notification event. Make retries safe, avoid duplicate subscriptions and notifications, and preserve retryability when delivery fails.
- [ ] The subscriber can cancel their own subscriptions. A dated subscription expires once that Philippine date has ended and cannot notify about a different date.
- [ ] Repeated publication processing or edits that do not create a newly eligible match do not duplicate alerts.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.

