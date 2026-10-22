# Engineering walkthrough

Start with three failure scenarios that shape the application. Each has a small
implementation path and an executable regression. The [architecture guide](architecture.md)
describes the surrounding domain; the [verification record](verification-evidence.md)
contains measured local recovery and request results.

## Two passengers compete for the last seat

Pending requests reserve no inventory. Acceptance reloads the booking, driver and
ride inside a primary transaction, checks admission again, and changes the booking,
seat count and notification together. SQLite's immediate write transactions
serialize competing writers. This is an intentional single-server tradeoff;
changing adapters requires revisiting the locking guarantee.

Read [AcceptService](../app/services/bookings/accept_service.rb), the
[Booking invariants](../app/models/booking.rb), and the
[database constraints](../db/schema.rb). Then run the
[final-seat race](../test/services/bookings/concurrent_acceptance_test.rb): two
threads use separate connections to a temporary database and must produce one
accepted booking, one pending booking, zero remaining seats and one acceptance
notification. The [acceptance tests](../test/services/bookings/accept_service_test.rb)
also cover stale caller objects and newly applied driver restrictions.

## A connected passenger loses chat access

A signed stream name identifies a conversation; it does not confer lasting
permission. [RideChatChannel](../app/channels/ride_chat_channel.rb) checks the
connecting session and participant on subscription, then reloads both user and
ride before each delivery. Revocation stops the stream and rejects the
subscription. The generic Turbo stream channel is disabled by the
[protected-stream initializer](../config/initializers/protected_streams.rb), closing
an alternate subscription route.

The [channel regressions](../test/channels/ride_chat_channel_test.rb) connect first,
then cancel participation, ban the account, or destroy the session before sending
another payload. Each must transmit nothing. The
[generic-stream regression](../test/channels/protected_streams_test.rb) verifies
that a valid signature cannot bypass that boundary. Domain chat deadlines and
historical participation remain in [RidePost](../app/models/ride_post.rb).

## Restoring a snapshot would resurrect a deleted account

[AnonymizeService](../app/services/users/anonymize_service.rb) records deletion
intent in a separately persisted [journal](../app/services/users/deletion_registry.rb)
before changing primary data. Replay matches both ID and account creation time,
so a reused ID does not erase a different account. The
[restore task](../lib/tasks/retention.rake) migrates and scrubs expired data, then
reapplies deletions before traffic resumes. A missing or malformed production
journal, or failed anonymization, keeps restoration unsuccessful.

The [retention task tests](../test/tasks/retention_rake_test.rb) protect those
failure cases. The [snapshot drill](../script/verification/restore_drill.rb) goes
further: it physically restores a SQLite snapshot containing a live account after
deletion, keeps the latest journal, and runs the actual restore task. It verifies
credentials, sessions, messages, expired chat access and retained history. The
[workflow regression](../test/integration/verification_workflows_test.rb) runs the
drill and guards existing database and journal paths from modification.
The [operator procedure](account-deletion-recovery.md) also covers uploads and
production backup recovery, which this synthetic local drill does not measure.

## Follow the evidence

```bash
bin/rails test test/services/bookings/concurrent_acceptance_test.rb
bin/rails test test/channels/ride_chat_channel_test.rb test/channels/protected_streams_test.rb
bin/rails test test/tasks/retention_rake_test.rb test/integration/verification_workflows_test.rb
```

Browser suites are named for behavior: content readability, form feedback, route
search, home navigation and UI components. Shared
[presentation assertions](../test/test_helpers/browser_presentation_helper.rb)
check containment and composite solid/translucent ancestor backgrounds for text
contrast. Known passing and failing nested surfaces are verified in
[UiComponentsTest](../test/system/ui_components_test.rb). Images, gradients,
group opacity, filters and blending require pixel-based review; the helper rejects
them rather than reporting a ratio. Browser checks retain keyboard focus, touch
targets, long-content overflow and Turbo morph preservation without prescribing
incidental alignment. The complete repository gate remains `bin/ci`.
