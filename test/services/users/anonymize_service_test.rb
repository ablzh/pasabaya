# frozen_string_literal: true

require "test_helper"

class Users::AnonymizeServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  setup do
    @user = User.create!(
      email_address: "anonymize_target@example.com",
      unconfirmed_email: "pending_change@example.com",
      password: "password123",
      first_name: "OriginalFirst",
      last_name: "OriginalLast",
      gender: :female,
      facebook_profile_url: "https://facebook.com/originalprofile"
    )
  end

  test "scrubs all direct personal identifiers and marks user as deleted" do
    orig_id = @user.id
    result = Users::AnonymizeService.call(@user)

    assert result
    @user.reload

    assert @user.deleted?
    assert_equal "Deleted", @user.first_name
    assert_equal "User", @user.last_name
    assert_match(/\Adeleted-#{orig_id}-[a-f0-9]{24}@deleted\.pasabaya\.app\z/, @user.email_address)
    assert_nil @user.unconfirmed_email
    assert_nil @user.facebook_profile_url
    assert_equal "unspecified", @user.gender
    assert_not_nil @user.deleted_at
    assert_not @user.eligible_for_booking?
    assert_not @user.eligible_for_offering?
  end

  test "cancels active bookings and ride posts before anonymization" do
    ride = ride_posts(:one)
    booking = Booking.create!(ride_post: ride, passenger: @user, status: :accepted)

    driver_ride = RidePost.create!(
      user: @user,
      origin: locations(:one),
      destination: locations(:two),
      post_type: :offering,
      seats: 3,
      departure_time: 2.days.from_now,
      expected_arrival_at: 2.days.from_now + 2.hours,
      remaining_seats: 3,
      status: :active
    )

    Users::AnonymizeService.call(@user)

    assert booking.reload.canceled?
    assert driver_ride.reload.canceled?
  end

  test "scrubs free-form notes from departed ride posts, bookings, and reviews" do
    driver = users(:one)
    ride = ride_posts(:one)
    booking = Booking.create!(
      ride_post: ride,
      passenger: @user,
      status: :accepted,
      pickup_notes: "Personal pickup instructions: call 0917-123-4567"
    )
    ride.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)

    review = TripReview.create!(
      ride_post: ride,
      reporter: @user,
      reported_user: driver,
      outcome: :passenger_no_show,
      notes: "Driver never arrived at the meeting location."
    )

    incident = NoShowIncident.create!(
      ride_post: ride,
      user: driver,
      occurred_at: ride.departure_time,
      status: :pending,
      decision_reason: "Reported by #{@user.first_name}: #{review.notes}"
    )

    # Departed ride created by @user with notes
    my_departed_ride = RidePost.create!(
      user: @user,
      origin: locations(:one),
      destination: locations(:two),
      post_type: :offering,
      seats: 2,
      departure_time: 3.days.from_now,
      expected_arrival_at: 3.days.from_now + 2.hours,
      remaining_seats: 2,
      status: :active,
      notes: "My private route notes: meeting at home address"
    )
    my_departed_ride.update_columns(departure_time: 3.days.ago, expected_arrival_at: 3.days.ago + 2.hours, status: RidePost.statuses[:completed])

    Users::AnonymizeService.call(@user)

    assert_nil booking.reload.pickup_notes
    assert_nil review.reload.notes
    assert_nil my_departed_ride.reload.notes
    assert_match(/Reported by former user/, incident.reload.decision_reason)
    assert_no_match(/OriginalFirst/, incident.decision_reason)
  end

  test "destroys ephemeral records including sessions, chats, notifications, memberships, and subscribers" do
    @user.sessions.create!(ip_address: "127.0.0.1", user_agent: "TestAgent")

    ride = ride_posts(:one)
    ride.update_columns(departure_time: 1.day.from_now, expected_arrival_at: 1.day.from_now + 2.hours)
    Booking.create!(ride_post: ride, passenger: @user, status: :accepted)
    ride.chat_messages.create!(user: @user, body: "Private chat message")

    Notification.create!(
      recipient: @user,
      actor: users(:one),
      notifiable: ride,
      event_name: "booking.requested",
      delivery_key: "test_del_key_#{@user.id}"
    )

    Subscriber.create!(name: "Test Sub", email: @user.email_address, terms_accepted: true)

    Users::AnonymizeService.call(@user)

    assert_equal 0, @user.sessions.count
    assert_equal 0, @user.chat_messages.count
    assert_equal 0, @user.received_notifications.count
    assert_not Subscriber.exists?(email: "anonymize_target@example.com")
  end

  test "records tombstone entry for post-restore idempotence" do
    Users::AnonymizeService.call(@user)

    tombstone = AccountDeletionTombstone.find_by(user_id: @user.id)
    assert_not_nil tombstone
    assert_equal @user.reload.email_address, tombstone.anonymized_email
  end

  test "is idempotent and safe when called multiple times" do
    assert Users::AnonymizeService.call(@user)
    assert Users::AnonymizeService.call(@user)
    assert @user.reload.deleted?
  end

  test "scrubs reviews and incidents about the deleted passenger without changing same-name reports" do
    ride = ride_posts(:one)
    Booking.create!(ride_post: ride, passenger: @user, status: :accepted)
    ride.update_columns(departure_time: 2.hours.ago, expected_arrival_at: 1.hour.ago)
    review = TripReview.create!(ride_post: ride, reporter: ride.user, reported_user: @user,
                               outcome: :passenger_no_show, notes: "Their phone is 0917-123-4567")
    incident = NoShowIncident.create!(ride_post: ride, user: @user, occurred_at: ride.departure_time,
                                      decision_reason: review.notes)
    unrelated = NoShowIncident.create!(ride_post: ride, user: users(:two), occurred_at: ride.departure_time,
                                       decision_reason: "Reported by #{@user.first_name}: Unrelated evidence")

    assert Users::AnonymizeService.call(@user)

    assert_nil review.reload.notes
    assert_no_match(/0917/, incident.reload.decision_reason)
    assert_equal "Reported by OriginalFirst: Unrelated evidence", unrelated.reload.decision_reason
  end

  test "commits deletion and retries avatar purge after the job queue fails" do
    @user.avatar.attach(io: StringIO.new("avatar image"), filename: "avatar.png", content_type: "image/png", identify: false)
    blob_id = @user.avatar.blob.id

    with_stubbed_method(ActiveStorage::PurgeJob, :perform_later, ->(*) { raise "queue unavailable" }) do
      assert Users::AnonymizeService.call(@user)
    end

    assert @user.reload.deleted?
    assert_not @user.avatar.attached?
    tombstone = AccountDeletionTombstone.find_by!(user_id: @user.id)
    assert_equal blob_id, tombstone.avatar_blob_id

    assert_enqueued_with(job: ActiveStorage::PurgeJob) do
      assert Users::AnonymizeService.call(@user)
    end

    ActiveStorage::Blob.find(blob_id).purge
    tombstone.enqueue_avatar_purge
    assert_nil tombstone.reload.avatar_blob_id
  end

  test "rejects stale profile and email updates after deletion" do
    stale_user = User.find(@user.id)
    assert Users::AnonymizeService.call(@user)

    assert_not stale_user.update(first_name: "Restored name")
    assert_not stale_user.confirm_email
    assert_equal "Deleted", @user.reload.first_name
    assert_match(/@deleted\.pasabaya\.app\z/, @user.email_address)
    assert_nil @user.unconfirmed_email
  end

  test "retries physical avatar deletion even after the blob row has been removed" do
    @user.avatar.attach(io: StringIO.new("avatar image"), filename: "avatar.png", content_type: "image/png", identify: false)
    blob = @user.avatar.blob
    service = blob.service
    key = blob.key
    assert Users::AnonymizeService.call(@user)

    with_stubbed_method(service, :delete, ->(*) { raise "storage unavailable" }) do
      assert_raises(RuntimeError) { blob.purge }
    end

    assert_not ActiveStorage::Blob.exists?(blob.id)
    assert service.exist?(key)
    tombstone = AccountDeletionTombstone.find_by!(user_id: @user.id)
    tombstone.enqueue_avatar_purge
    assert_not service.exist?(key)
    assert_nil tombstone.reload.avatar_blob_id
    assert_nil tombstone.avatar_key
  end

  test "does not mutate the account when the deletion registry cannot be written" do
    with_stubbed_method(Users::DeletionRegistry, :record!, ->(*) { raise IOError, "registry unavailable" }) do
      assert_not Users::AnonymizeService.call(@user)
    end

    assert_not @user.reload.deleted?
    assert_equal "OriginalFirst", @user.first_name
    assert_equal "anonymize_target@example.com", @user.email_address
    assert_not AccountDeletionTombstone.exists?(user_id: @user.id)
  end
end
