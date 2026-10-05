# Architecture and domain rules

Pasabaya is a Rails monolith deployed on one server. Browser and Hotwire Native
clients share HTML, sessions, authorization, and domain logic. Native navigation
configuration is implemented; native applications and offline persistence are not.

## Domain

`RidePost` is a driver's offer for a route and departure. A draft can be incomplete;
publishing requires a valid future departure and a complete offer. Closing requests
prevents new bookings without canceling accepted participation. Cancellation is a
separate event with its own chat coordination deadline.

`Booking` is one passenger's seat request. Pending requests do not consume seats.
Acceptance consumes one seat, and cancellation of accepted participation restores
it. A passenger can have only one pending or accepted request for a ride. Acceptance
must recheck capacity, departure, participant eligibility, and ride visibility
inside the database transaction. The driver's own account cannot book its offer.

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
participation; deleting records must not erase review eligibility. No-show
adjudication is currently a trusted console operation, documented in
[operations](operations.md#moderation).

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

## Persistence and recovery

Production uses separate SQLite databases for application data, jobs, cache, and
Cable, with local upload storage on a persistent volume. Transactional changes to
application data cannot assume an atomic commit across these databases; recovery
jobs repair eligible work that was not delivered.

Account deletion records intent in a separate persistent journal before primary
data is anonymized. Restoration reapplies that journal and scrubs expired data
before serving requests. See [the recovery procedure](account-deletion-recovery.md).
Reference seeds are additive and contain no accounts; optional demo seeds cannot
run in production or staging.

The current deployment is intentionally single-server. Replication freshness,
disk capacity, database contention, and job delay are operating constraints to
measure before changing its topology.
