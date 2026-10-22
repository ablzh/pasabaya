# Architecture and domain rules

Pasabaya is a Rails monolith deployed on one server. Browser and Hotwire Native
clients share HTML, sessions, authorization, and domain logic. Native navigation
configuration is implemented; native applications and offline persistence are not.

## Domain

`RidePost` is a driver's offer for a route and departure. A draft can be incomplete;
publishing requires a valid future departure and a complete offer. Closing requests
prevents new bookings without canceling accepted participation. Cancellation is a
separate event with its own chat coordination deadline.

`RideSchedule` is a recurring driver offer with weekdays and Philippine departure
time, optional end date, and draft/active/paused/archived states. Publishing without
an end date explicitly repeats until paused or ended. Its materializer maintains
the next 14 Manila calendar dates, also refreshing when an authorized viewer opens
the schedule. Each occurrence remains a normal `RidePost` with independent seats,
conditions, audience, chat and reviews. A unique schedule/date key and retained
canceled records prevent regeneration of a skipped date; occurrence dates cannot
be moved. Missed refreshes only create future departures, never historical ones.

Schedule edits reconcile only untouched future occurrences. Pending and accepted
requests, manually closed departures, canceled dates and history preserve their
existing conditions. A pause atomically expires pending requests and closes new
admission while honoring accepted participation. Resume preserves manual closures
and does not revive expired requests or canceled dates. Ending a series explicitly
cancels future departures using the same cancellation transition as a single ride.
Both request creation and acceptance enforce schedule admission inside the primary
SQLite transaction. Account deletion and audience eligibility loss stop future
generation; deletion also scrubs schedule notes. Normal draft conversion requires
the owner and a source without bookings, preserving any original departure date.
Schema migrations do not publish drafts. The separately invoked, reviewed legacy
import uses the October 20 snapshot and explicit rollout defaults; see
[the transition procedure](operations.md#legacy-ride-transition).

`Booking` is one passenger's seat request. Pending requests do not consume seats.
Acceptance consumes one seat, and cancellation of accepted participation restores
it. A passenger can have only one pending or accepted request for a ride. Acceptance
must recheck capacity, departure, participant eligibility, and ride visibility
inside the database transaction. The driver's own account cannot book its offer.

New admission uses the same availability decision for request creation and
acceptance. Discovery queries apply the equivalent driver, capacity, closure,
departure and schedule rules before audience visibility. Driver eligibility
requires an undeleted, unbanned account without a current booking freeze, plus
current membership and gender eligibility for the offer's audience. Scheduled
departures also require their series to remain eligible. Full rides can still
appear on profiles, and management, accepted participation and history remain
accessible under their existing authorization rules.

An ordinary offer can admit new requests again when its driver's restriction is
revoked or expires, provided its other conditions still allow admission.
Automatically paused regular schedules require explicit resume; expired requests
are not revived. Bans and booking freezes do not cancel accepted bookings or alter
their inventory or history. Existing chat rules still apply: a booking freeze permits
coordination, while a banned account itself cannot use chat.

Booking creation records its notification in the same primary database transaction.
Save validations reload the account and trip state to reject objects loaded before
cancellation or account deletion. SQLite's immediate write transactions serialize
these checks with competing writes; changing database adapters requires revisiting
that locking guarantee. Final-seat acceptance has a regression using simultaneous
threads and separate connections to an isolated database.

Hub-only rides require an active verified membership. Public listings, route
alerts, notifications, and chat each apply their own visibility checks. A signed
stream name is not sufficient authorization: channels validate the user, session,
and current trip access before subscribing and transmitting.

Trip chat belongs to the driver and accepted participants. Messaging and history
have separate deadlines. Reviews and no-show decisions retain historical
participation; deleting records must not erase review eligibility. No-show outcome
categories must match the subject's role on the trip. The private `/admin` area
shows reviews and the incident queue. Administrator rights are checked against
the current account state, and console access is required to grant or revoke them.

`NoShowIncidents::AdjudicateService` owns confirmation, dismissal, and reversal of
decisions. It requires an active administrator who was not involved in the trip,
checks the displayed incident version, and records each changed decision in
`NoShowIncidentDecision`. The incident's reviewer, reason, and resolution time
describe the latest decision; its history preserves earlier outcomes. The same
transaction updates strike restrictions and records a result notification keyed
by the decision. Repeated submissions of an unchanged result do not add another
decision or notification. Existing appealed cases can be reviewed, but there is
no user appeal submission workflow. See [operations](operations.md#moderation).

Account deletion scrubs reasons from the decision history as well as review notes
and the latest incident reason. Later decisions on anonymized cases preserve
objective outcomes without restoring personal commentary. Administrative access
does not extend the chat retention deadline or grant routine access to private
trip conversations.

## Boundaries

- Controllers own request authentication, authorization, parameters, and response
  formats. They call domain transitions rather than managing seat inventory.
- Models own domain predicates, validations, database associations, and reusable
  scopes. Services under `app/services` coordinate transitions spanning records.
- Jobs receive durable IDs, reload records, and recheck eligibility. They cannot
  rely on request-local `Current`. Delivery recovery and recurring sweeps support
  missed or failed background work.
- Components and templates present already-authorized state. Stimulus handles
  browser interaction; it does not grant access or decide persisted eligibility.

`Archspec.rb` enforces the component-to-controller and job-to-`Current`
boundaries. Database indexes and constraints complement model validations.
Concurrency and authorization regression tests establish the important behavior;
an architecture lint passing does not prove every domain rule.

Shared UI components preserve native control semantics: destinations render as
links, while actions render as buttons. Card provides page panels and ride-card
sections; Badge presents status and audience labels. Toast controls have stable
IDs and retain focus across page-refresh morphing. Keyboard focus expands the
stack, focus and pointer interaction pause dismissal, and incoming notifications
preserve the toast being used. Ordinary navigation clears the transient stack.

Trip detail controllers prepare pending and accepted bookings, the viewer's
current booking, chat state and participant counts before rendering the focused
driver-request, passenger-action and chat partials. Passenger avatar attachments
and blobs are preloaded together for the driver's active requests. Other viewers
fetch only their own current request; guests load no bookings. Chat eligibility
and counts query the relevant historical participation without loading inactive
request history. Presentation does not construct booking collections.

Profile and My Trips collections are filtered in SQL and paginated independently
at 20 records, ordered by creation time and ID descending. Only the selected tab's
collections are rendered; tab totals use database counts. Converted drafts stay
excluded even when their schedule is on another page, and regular occurrences
enter driver history only when they have bookings. The query regression uses 205
historical rides with tied timestamps: the first page instantiates at most 21 rides
(20 historical records and one current offer), then verifies all 11 pages without
missing or repeated records. A separate 45-trip booking history retains canceled
acceptance records. These bounds describe loaded history records; aggregate counts
and overdue-request maintenance still perform database work.

## Persistence and recovery

Production uses separate SQLite databases for application data, jobs, cache, and
Cable, with local upload storage on a persistent volume. Transactional changes to
application data cannot assume an atomic commit across these databases; recovery
jobs repair eligible work that was not delivered.

Route-relevant ride changes record a `RidePostDispatch` in the same primary
transaction as the ride. Its after-commit enqueue is an optimization; a recurring
sweep retries every outstanding dispatch. Matching snapshots the work IDs before
reloading the ride and rechecking subscription eligibility, so completion cannot
erase work from a concurrent edit. Subscription fulfillment and its uniquely
keyed notification remain atomic and safe to repeat.

Cancellation records a dispatch with the driver and accepted participant IDs in
the transaction that cancels the ride and bookings and creates notifications.
Its worker refreshes the trip conversation and those participants' chat lists
after the outermost commit, including cancellations nested in schedule changes
or account deletion. Queue and Cable failures retain the work for retry without
undoing cancellation. Successful work is removed; outstanding rows retain failure
counts, error class names and failure times. Refresh publication is at least once,
so a partial publication can repeat refreshes safely.

Notification enqueue failures leave committed pending rows for the notification
recovery sweep and do not fail the originating request. A missed chat-retention
enqueue is logged; the recurring purge and startup scrub still remove expired
conversations, and access deadlines apply independently of physical cleanup.

Account deletion records intent in a separate persistent journal before primary
data is anonymized. Restoration reapplies that journal and scrubs expired data
before serving requests. See [the recovery procedure](account-deletion-recovery.md).
Reference seeds are additive and contain no accounts; optional demo seeds cannot
run in production or staging.

The current deployment is intentionally single-server. Replication freshness,
disk capacity, database contention, and job delay are operating constraints to
measure before changing its topology.
