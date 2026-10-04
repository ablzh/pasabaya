# frozen_string_literal: true

require "test_helper"
require "rake"

class RetentionRakeTest < ActiveSupport::TestCase
  setup do
    @original_rake = Rake.application
    @rake = Rake::Application.new
    Rake.application = @rake
    load Rails.root.join("lib/tasks/retention.rake")
    Rake::Task.define_task(:environment)
    Rake::Task.define_task("db:migrate")
  end

  teardown do
    Rake.application = @original_rake
  end

  test "retention:scrub purges chat messages from expired conversations and revokes expired memberships" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted])
    old_msg = ride.chat_messages.create!(user: ride.user, body: "Old message")
    recent_msg = ride.chat_messages.create!(user: ride.user, body: "Recent message")
    ride.update_columns(departure_time: 35.days.ago, expected_arrival_at: 34.days.ago)

    retained_ride = ride_posts(:two)
    Booking.create!(ride_post: retained_ride, passenger: users(:one), status: :accepted)
    retained_msg = retained_ride.chat_messages.create!(user: retained_ride.user, body: "Retained message")
    retained_ride.update_columns(departure_time: 2.days.ago, expected_arrival_at: 1.day.ago)

    membership = community_memberships(:one)
    membership.update_columns(verified_at: 1.month.ago, expires_at: 1.day.ago, revoked_at: nil)

    assert_difference("ChatMessage.count", -2) do
      Rake::Task["retention:scrub"].invoke
    end

    assert_not ChatMessage.exists?(old_msg.id)
    assert_not ChatMessage.exists?(recent_msg.id)
    assert ChatMessage.exists?(retained_msg.id)
    assert membership.reload.revoked_at.present?
  end

  test "retention:scrub reapplies deletion after the primary database loses its tombstone" do
    user = User.create!(
      email_address: "restore_target@example.com",
      password: "password123",
      first_name: "Restored",
      last_name: "User"
    )
    original_attributes = user.attributes
    assert Users::AnonymizeService.call(user)
    AccountDeletionTombstone.where(user_id: user.id).delete_all
    User.where(id: user.id).update_all(original_attributes)
    user.reload

    assert_not user.deleted?

    Rake::Task["retention:scrub"].invoke

    assert user.reload.deleted?
    assert_equal "Deleted", user.first_name
  end

  test "restore fails when anonymization fails" do
    user = users(:one)
    Users::DeletionRegistry.record!(user, deleted_at: Time.current)

    with_stubbed_method(Users::AnonymizeService, :call, false) do
      assert_raises(Users::AnonymizeService::Error) { Rake::Task["db:restore:finish"].invoke }
    end
  end

  test "restore fails when the deletion registry is unavailable" do
    File.delete(Users::DeletionRegistry.path)

    with_stubbed_method(Rails.env, :production?, true) do
      assert_raises(Errno::ENOENT) { Rake::Task["db:restore:finish"].invoke }
    end
  end

  test "restore does not delete a new account which reuses an old user ID" do
    user = users(:one)
    Users::DeletionRegistry.record!(user, deleted_at: Time.current)
    user.update_columns(created_at: user.created_at + 1.second)

    Rake::Task["retention:scrub"].invoke

    assert_not user.reload.deleted?
  end

  test "restore fails when the deletion journal is malformed" do
    File.write(Users::DeletionRegistry.path, "incomplete journal record")

    assert_raises(JSON::ParserError) { Rake::Task["db:restore:finish"].invoke }
  end

  test "db:restore:finish invokes migrations and retention scrubbing" do
    assert_nothing_raised do
      Prosopite.pause do
        Rake::Task["db:restore:finish"].invoke
      end
    end
  end
end
