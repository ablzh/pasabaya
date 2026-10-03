# Driver-only booking specification

**Status:** ready-for-agent
**Tracker:** local `issues/` files beside this specification.
**Authority:** The approved ticket acceptance criteria reproduced below are the agreed requirements. Implementation notes never weaken them.

## Problem Statement

Passengers need reliable booking on driver offers, with honest departure information, safe audience boundaries, and clear coordination deadlines. Drivers need intentional publishing and simple inventory management. The current passenger-post workflow, mandatory arrival estimate, chat retention, and navigation obscure those tasks.

## Solution

Offer driver rides only, with deliberate draft/publish actions and optional arrival. Support exact and approximate Philippine departure dates with one booking cutoff used consistently for booking, expiration, history, reviews, and coordination. Add one-shot route alerts, a secure chats inbox and synchronized reading state, registration attestation, and the approved presentation improvements.

## User Stories

1. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: People browse and publish driver offers only. Passengers continue requesting seats on driver offers; they no longer create separate passenger ride posts.
2. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: A driver deliberately saves a draft or publishes an exact-time ride without being required to predict an arrival time. Elapsed rides move into history reliably.
3. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: A driver publishes a dated ride using an approximate departure choice or an exact time. Passengers can book approximate departures throughout the selected Philippine date.
4. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: Passengers learn when an unanswered seat request expires, and drivers cannot accept requests after the ride's booking deadline.
5. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: Drivers set the number of available passenger seats using buttons or direct typing, with a clear explanation that the driver is excluded.
6. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: When a route search has no rides, a passenger can subscribe once and receive an email and in-app notification when a matching driver offer is first published.
7. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: A waiting passenger can receive their one-shot route alert when an existing ride gains available seats or changes onto their subscribed route.
8. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: Hub discovery presents the University of the Philippines community, explains Pasabaya's independence, and directs suggestions to the existing support channel.
9. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: Signed-in members find a user's Facebook link on that user's profile, with clear visibility guidance when adding the link.
10. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: New users explicitly confirm that they are at least 18 and accept the Terms of Service and Privacy Policy, with acceptance recorded by the app.
11. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: Members clearly distinguish unread notifications and clear all existing unread notifications in one action, with badges synchronized across open sessions.
12. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: Trip participants see exactly when messaging stops and when chat history becomes unavailable, with one retention deadline for the entire conversation.
13. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: The driver and previously accepted passengers can coordinate briefly after an open trip is canceled, then read the conversation until its clearly announced retention deadline.
14. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: Members open a dedicated chats inbox to find their accessible trip conversations and resume a discussion from its latest message preview.
15. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: Members see which conversations need attention and a Chats badge counting unread conversations, with reading state shared across devices.
16. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: On mobile, a trip discussion uses the full available screen with a compact header, scrollable messages and an accessible composer above the keyboard.
17. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: Members use a smaller profile menu with notifications on the avatar, and the profile dropdown opens directly beneath its trigger without sliding across the page.
18. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: Ride cards align neatly and open ride details from their surface, while drivers retain a separate Edit action and concise trip-note previews.
19. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: People search and inspect rides through aligned, readable screens, with owner-specific details and a helpful destination when a ride no longer exists.
20. As a Pasabaya member, I want the following capability, so that trip discovery, booking and coordination are clear and reliable: Members manage their offers, drafts, passenger bookings and history on their own profile, while other members see only eligible upcoming driver offers.

## Implementation Decisions

- Reuse the existing Rails ride, booking, notification, chat, user and community boundaries. Preserve historical participation, audience restrictions, inventory invariants and manual incident decisions.
- Explicit publish actions control draft transitions; submitted fields alone never publish a draft. Drafts may remain incomplete.
- Keep exact departures compatible. Approximate departure choices store a selected Philippine date without inventing an exact timestamp. Centralize booking cutoff and automatic completion policy.
- Use transactional state changes and unique delivery keys for seat expiration and one-shot route alerts. Recheck visibility before delivery and keep failed deliveries retryable.
- Store registration acceptance on the server and per-member chat reading progress. Conversation-wide send and history deadlines govern every access path and recovery process.
- Keep production migrations conservative: unexpected passenger posts stop migration. Disposable non-UP hub cleanup is local-only and must remove restricted associated records without making them public.
- Keep existing Hotwire/Stimulus, SVG Heroicons and text chat; add no attachment stack, arbitrary seat cap, incident administration or public ratings.

## Testing Decisions

- Confirmed by the user: existing Rails request/integration tests for permissions and flows; public model/service/job tests for booking, inventory, matching, expiration and retention; system tests for the seat stepper, dropdown and chat scrolling/foreground reading behavior.
- Test observable behavior at those boundaries using actual test records and jobs, with time travel for Philippine date boundaries. Include stale browser submissions, retries, authorization loss and concurrency boundaries where applicable.
- Use red → green vertical slices for relevant behavior, then integrated review and the full `bin/ci` gate. Record any blocked check explicitly. Tickets become done only when all their acceptance criteria pass.

## Out of Scope

Anything excluded by the approved tickets, including passenger ride posts, commercial transport promotion, public ratings, analytics, administrative incident UI, attachments, hub request submission or production-wide hub deletion. No push or pull request.

## Further Notes

- Integration branch: `artem/driver-only-booking`, based on the current local checkout including its six existing local commits.
- Each implementer works in an isolated worktree based on the latest integration tip and can read this spec and the shared tracker through absolute paths.
- Dependencies must be complete before a ticket starts. Ready roots: 01, 02, 05, 08, 09, 10, 11, 14, 16, 17, 18, 19. Edges: 02→03; 03→04,06,12,20; 06→07; 12→13; 14→15.
- Runtime: installed mise Ruby 4.0.1; selecting its bin directory in PATH resolves the earlier Ruby/Bundler startup problem. `bundle check` succeeds before implementation.
- Local tracker status, evidence and any blockers remain in ticket files; unchanged acceptance criteria are authoritative.

## Approved tickets and acceptance criteria (verbatim)

# 01: Remove passenger ride posts

**What to build:** People browse and publish driver offers only. Passengers continue requesting seats on driver offers; they no longer create separate passenger ride posts.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Passenger-request ride posts, their search tabs and offering/requesting card badges are removed from the user experience; driver offers remain searchable and bookable.
- [ ] Forms, accepted parameters, validations, database rules, sample data and product documentation consistently support driver offers only.
- [ ] Preserve positive offered-seat totals and inventory constraints, including valid sold-out rides and protection against negative or excessive remaining inventory.
- [ ] The supplied production assumption is that no passenger-request ride posts exist. Stop any destructive migration if unexpected passenger-request records are present rather than relabeling or deleting them silently.
- [ ] Seeds remain repeatable and no longer create passenger-request ride posts. Passenger accounts and seat requests remain supported.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 02: Explicit publishing with optional arrival

**What to build:** A driver deliberately saves a draft or publishes an exact-time ride without being required to predict an arrival time. Elapsed rides move into history reliably.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Save draft and Publish ride are distinct intentional actions. Editing a draft does not publish it automatically.
- [ ] Publishing requires a valid route, future exact departure and available passenger seats; expected arrival is optional, and its label does not suggest it is required.
- [ ] Incomplete rides can be saved as drafts and cannot become publicly bookable before a successful explicit publish action.
- [ ] With expected arrival supplied, automatic completion occurs at expected arrival plus two hours, but never before the booking cutoff. Without arrival, automatic completion occurs at booking cutoff plus 24 hours.
- [ ] Drafts and canceled rides are not automatically completed. Both normal scheduling and recovery processing handle published rides with no arrival, and repeating completion processing does not duplicate side effects.
- [ ] Automatic completion does not claim verified travel: user-facing history labels use Past for automatically elapsed rides. Full upcoming rides are not mistaken for completed rides.
- [ ] Existing exact-time rides and accepted-booking departure restrictions continue to work.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 03: Book rides with approximate departures

**What to build:** A driver publishes a dated ride using an approximate departure choice or an exact time. Passengers can book approximate departures throughout the selected Philippine date.

**Blocked by:** [02: Explicit publishing with optional arrival](02-explicit-publishing-optional-arrival.md).

**Status:** ready-for-agent

- [ ] Every newly published ride requires a departure date and one choice: Morning, Afternoon, Evening, Night, Exact Time or Flexible. Approximate choices do not fabricate a confirmed exact departure timestamp.
- [ ] Use SVG Heroicons, not emoji. Display hints are Morning 06:00–12:00, Afternoon 12:00–17:00, Evening 17:00–21:00, Night 21:00–midnight, and Flexible any time on the selected date. Exact Time exposes a precise time picker, including midnight–06:00.
- [ ] Approximate choices are descriptive hints: requests and driver acceptance remain open until midnight ending the selected date in Asia/Manila, even if the named period has passed. Exact-time booking closes at the specified departure.
- [ ] Drivers can close requests earlier. Past dates and elapsed exact departures cannot be newly published or booked, and the server enforces boundaries even when a browser remains open.
- [ ] Cards, details, search dates, upcoming/history classification and completion scheduling consistently use the selected Philippine date and the agreed booking cutoff. Preserve existing exact-time rides.
- [ ] After an accepted booking, the departure date and selected approximate choice or exact time are locked. Coordinate within the published choice in chat; moving outside it requires cancellation and a new offer.
- [ ] Private trip feedback and no-show reporting become eligible after the selected date ends for approximate rides and after departure for exact-time rides. Preserve participant eligibility and existing manual incident decisions; pending allegations do not create penalties.
- [ ] Extend the automatic completion policy from ticket 02 to approximate departures, with no completion before booking cutoff and the no-arrival fallback of cutoff plus 24 hours.
- [ ] Do not add an administrative incident interface, new public ratings or analytics as part of this work.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 04: Expire unanswered seat requests

**What to build:** Passengers learn when an unanswered seat request expires, and drivers cannot accept requests after the ride's booking deadline.

**Blocked by:** [03: Book rides with approximate departures](03-approximate-departure-booking.md).

**Status:** ready-for-agent

- [ ] Pending seat requests expire at the ride's booking cutoff for both exact and approximate departures, rather than waiting for automatic trip completion.
- [ ] The passenger receives the message Your seat request expired without confirmation through the existing notification flow.
- [ ] Pending requests reserve no inventory. Expiring them does not release or subtract seats, and accepted or declined requests are not changed.
- [ ] An acceptance racing with expiry cannot succeed after cutoff, oversell seats or produce conflicting terminal states.
- [ ] Repeated processing and recovery runs produce no duplicate expiry notifications and leave no overdue request displayed as pending.
- [ ] Existing earlier closure and cancellation behavior continues to resolve requests consistently.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 05: Clarify available passenger seats

**What to build:** Drivers set the number of available passenger seats using buttons or direct typing, with a clear explanation that the driver is excluded.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Label the field Available passenger seats and explicitly explain that the count excludes the driver and represents passenger places offered.
- [ ] Minus and plus controls change the value by one; the center remains an editable number input with keyboard support.
- [ ] Require a positive whole number through server validation. Do not introduce a 7-seat limit or another arbitrary business cap, and permit direct entry of larger values.
- [ ] Reject zero, negative, fractional and malformed values; minus cannot decrement below one, and stepper buttons do not submit the form.
- [ ] Seat counts on the ride continue to distinguish seats offered from remaining seats after accepted bookings.
- [ ] Keep messaging focused on individual drivers with passenger cars rather than promoting buses or transport businesses.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



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



# 07: Alert when existing rides become bookable

**What to build:** A waiting passenger can receive their one-shot route alert when an existing ride gains available seats or changes onto their subscribed route.

**Blocked by:** [06: Subscribe to newly published matching rides](06-one-shot-route-alert-subscriptions.md).

**Status:** ready-for-agent

- [ ] Restoring available seats on a previously full ride can trigger a matching active subscription.
- [ ] Changing a ride's route or other matching criteria can trigger a subscription that the ride newly satisfies.
- [ ] Only currently published, visible, bookable offers match; canceled, drafted, expired or still-full rides do not generate alerts.
- [ ] Reuse the saved route/date/audience matching, delivery-time access checks, one-shot consumption and cancellation/expiry behavior from ticket 06.
- [ ] Concurrent inventory changes, route edits and retry processing cannot notify a consumed subscription twice or repeatedly alert for an unchanged match.
- [ ] Cover at least the reopened-seat and route-change scenarios as behavior regressions.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 08: Keep only the UP community hub

**What to build:** Hub discovery presents the University of the Philippines community, explains Pasabaya's independence, and directs suggestions to the existing support channel.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Retain only University of the Philippines, using institutional email domain up.edu.ph. Do not claim that this domain alone verifies Diliman campus affiliation.
- [ ] Remove unwanted locally created hubs, including commercial and test hubs, and their disposable local-only associated data safely. This is authorized local cleanup, not a blanket production-data deletion.
- [ ] Seed replay recreates the intended UP hub without duplicate hubs or reintroducing removed organizations.
- [ ] Show: Pasabaya is an independent community platform and is not officially affiliated with, endorsed by, or partnered with any listed university or institution. Hubs are community-led spaces verified via institutional email domains.
- [ ] Request a Community Hub opens the existing Pasabaya Facebook support page and explains that users should send the institution name and email domain.
- [ ] Keep UP institutional-email verification working, and never silently turn an existing restricted ride into a public ride during cleanup.
- [ ] No hub request submission system or retirement workflow is required for these disposable local hubs.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 09: Limit Facebook links to member profiles

**What to build:** Signed-in members find a user's Facebook link on that user's profile, with clear visibility guidance when adding the link.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Remove Facebook buttons and links from ride board cards and ride detail pages.
- [ ] A member profile with a configured URL has View Facebook Profile opening in a new tab with appropriate external-link attributes.
- [ ] When no URL is configured, show the subtle Facebook profile not linked label.
- [ ] Profile access and Facebook URL visibility remain restricted to signed-in users; guests cannot retrieve the URL through the profile.
- [ ] Settings explicitly state that a linked Facebook profile is visible to other signed-in members.
- [ ] Continue validating acceptable Facebook links and preserving existing profile data.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 10: Record registration self-attestation

**What to build:** New users explicitly confirm that they are at least 18 and accept the Terms of Service and Privacy Policy, with acceptance recorded by the app.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] The required checkbox reads I confirm that I am at least 18 years old and agree to the Terms of Service and Privacy Policy, with working links to both policies.
- [ ] The server rejects omitted or false acceptance, including requests that bypass browser validation, with: You must be at least 18 years old and agree to the Terms of Service and Privacy Policy to register.
- [ ] Store the acceptance timestamp and the applicable policy version for successful new registrations; neither value is trusted from client-supplied timestamps or version strings.
- [ ] Treat this as self-attestation, without collecting a birth date or adding identity/age verification.
- [ ] Existing users are not forced to reaffirm, and normal profile updates do not require a registration-only checkbox.
- [ ] Failed registrations preserve useful form input and display the acceptance error.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 11: Improve notifications and mark all read

**What to build:** Members clearly distinguish unread notifications and clear all existing unread notifications in one action, with badges synchronized across open sessions.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Unread entries have a distinct vibrant blue dot, bold title and sufficient contrast, rather than relying on a faint background alone.
- [ ] Add the recipient/creation composite index for the notification listing while retaining indexes needed for unread counts. Do not promise a hardware-independent sub-millisecond query time.
- [ ] Provide a Mark all as read action with an SVG Heroicon.
- [ ] Mark every unread notification belonging to the current recipient that existed at the operation's snapshot, including entries older than the displayed list. Preserve notifications arriving after that snapshot.
- [ ] Update visible entry styling and unread counts through Turbo across open sessions, including when bulk updates bypass per-record callbacks.
- [ ] The action is authorized for the current recipient only, is safe to repeat, and does not mark another user's notifications read.
- [ ] Cover the older-than-visible-list and concurrent-new-notification cases.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 12: Give chats explicit expiration deadlines

**What to build:** Trip participants see exactly when messaging stops and when chat history becomes unavailable, with one retention deadline for the entire conversation.

**Blocked by:** [03: Book rides with approximate departures](03-approximate-departure-booking.md).

**Status:** ready-for-agent

- [ ] For an ordinary trip, messaging closes 24 hours after the booking cutoff, regardless of earlier automatic completion. Reading remains available for another 30 days to authorized participants.
- [ ] Show separate full-date deadlines for messaging closure and history unavailability/scheduled deletion, explicitly labeled Philippine time (UTC+8).
- [ ] Explain the distinction between inability to send messages and inability to read history; avoid an ambiguous single chat-closes label.
- [ ] All messages in one conversation share its retention deadline instead of disappearing individually based on each message's age.
- [ ] At the history deadline, the conversation and messages are inaccessible through inbox, direct navigation and submissions; schedule permanent deletion from the live database and make purge/recovery processing safe to repeat.
- [ ] Describe the deletion deadline as scheduled live-database deletion; queue delays and backup retention must not be represented as exact erasure of every copy at that instant.
- [ ] Update privacy and retention wording to reflect conversation-wide retention and the separate backup policy.
- [ ] An already open chat cannot bypass send/read deadlines, and the composer and notices reflect expiry appropriately.
- [ ] Existing conversations receive consistent deadlines without prematurely deleting still-retained history.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



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



# 14: Add the chats inbox

**What to build:** Members open a dedicated chats inbox to find their accessible trip conversations and resume a discussion from its latest message preview.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] A dedicated chats destination lists conversations the current user is authorized to access.
- [ ] Each entry shows the trip route, latest-message preview and timestamp, with a clear link into the discussion and sensible latest-activity ordering.
- [ ] Include currently accessible read-only conversations with an appropriate state label; honor the applicable cancellation and retention rules as those rules evolve.
- [ ] Provide a useful empty state for members with no conversations.
- [ ] Both inbox queries and direct chat navigation enforce participation and audience access; previews do not leak private messages from inaccessible trips.
- [ ] Message activity updates previews and ordering appropriately without producing per-conversation query growth.
- [ ] Keep the inbox and existing trip chat text-only; attachment preparation is outside this release.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 15: Track unread conversations across devices

**What to build:** Members see which conversations need attention and a Chats badge counting unread conversations, with reading state shared across devices.

**Blocked by:** [14: Add the chats inbox](14-chats-inbox.md).

**Status:** ready-for-agent

- [ ] Persist per-user conversation reading state. The navbar badge counts unread conversations, not total unread messages, and the inbox identifies those conversations.
- [ ] Add a Chats navigation link with an SVG message icon and unread-conversation badge.
- [ ] A conversation becomes read when it is in the foreground and the user reaches its latest message; merely opening a background tab or remaining scrolled above the latest message does not clear it.
- [ ] Incoming messages update unread state and counts; a user's own messages do not mark that user's conversation unread.
- [ ] Reading state and badge changes synchronize across open sessions and devices through the existing real-time mechanisms.
- [ ] Only authorized, retained conversations contribute to the inbox and badge. Expired history and revoked access do not leave phantom unread counts.
- [ ] Read updates racing with incoming messages do not incorrectly clear a newer unseen message.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 16: Make mobile chats full height

**What to build:** On mobile, a trip discussion uses the full available screen with a compact header, scrollable messages and an accessible composer above the keyboard.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Mobile chat detail uses a 100dvh layout and hides global headers and footers while the discussion is open.
- [ ] The compact header includes a back action, trip route and relevant participant/driver context.
- [ ] The message stream uses the remaining height, reaches the latest messages initially, and follows new messages when already at the bottom without pulling someone away from older history.
- [ ] The composer stays reachable above the mobile keyboard and respects safe-area insets, orientation changes and changing viewport height.
- [ ] Read-only or unavailable chats show their applicable state rather than an active composer; existing deadline notices remain readable.
- [ ] Desktop navigation and trip-detail chat access continue to work.
- [ ] Use the existing text chat stack; do not add file/image upload infrastructure.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 17: Clean up navbar and dropdown behavior

**What to build:** Members use a smaller profile menu with notifications on the avatar, and the profile dropdown opens directly beneath its trigger without sliding across the page.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Remove the standalone notification bell from the top bar and display the unread notification badge on the avatar with accessible notification-count information.
- [ ] The profile dropdown contains Profile, Settings, Notifications with unread count, and Sign out.
- [ ] Remove duplicate My Trips and Hubs dropdown entries; retain the top-level Hubs destination and a working Profile link.
- [ ] Notification counts remain synchronized when notifications become read or arrive, including Mark all as read once ticket 11 lands.
- [ ] On first opening, the dropdown fades/scales at its correctly positioned location; changes in horizontal placement do not animate from the origin.
- [ ] Keyboard operation, focus handling, dismissal and responsive positioning remain functional.
- [ ] Preserve the Chats navigation added by ticket 15 when it is present; this cleanup does not depend on unread-chat implementation.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 18: Make ride cards consistent and clickable

**What to build:** Ride cards align neatly and open ride details from their surface, while drivers retain a separate Edit action and concise trip-note previews.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Cards stretch to equal height within each grid row, use a full-height column layout and keep footers aligned at the bottom.
- [ ] Remove the Show button. Clicking the card surface, including the author's name or avatar, opens the ride details.
- [ ] Provide keyboard-accessible ride navigation and a distinct owner Edit action that opens editing without activating ride navigation; avoid invalid nested interactive elements.
- [ ] Show at most two lines of note preview and truncate the preview to 110 characters without modifying stored notes.
- [ ] Require no more than 300 characters for newly created or changed notes, with clear form guidance and server validation.
- [ ] Preserve unchanged historical notes exceeding 300 characters; unrelated edits, cancellation and completion are not blocked, and existing notes are not silently truncated.
- [ ] Keep card destinations, audience visibility and owner controls correct wherever the shared card appears.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



# 19: Polish ride search and detail pages

**What to build:** People search and inspect rides through aligned, readable screens, with owner-specific details and a helpful destination when a ride no longer exists.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Allow the ride-board subtitle to use its header container width without the previous narrow desktop limit.
- [ ] Align origin/destination/date labels at the top of the search grid and show Leave blank to see all upcoming rides on this route below the optional date field.
- [ ] The Request a Seat card, pickup-notes input and submission button follow the app's light theme and retain appropriate dark-theme styling.
- [ ] A driver viewing their own trip does not see their own driver introduction card; label notes Your Trip Notes for the owner and Driver's Notes for others.
- [ ] Navigating to a deleted or missing ride redirects to the Ride Board with The trip is no longer available, including entry from an old ride notification.
- [ ] Keep missing-ride handling scoped to ride resolution: do not swallow unrelated missing-record exceptions or turn authorization failures into permission to view a ride.
- [ ] Preserve accepted-booking/history protections on deletion and do not delete a retained trip simply to satisfy the redirect behavior.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



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



