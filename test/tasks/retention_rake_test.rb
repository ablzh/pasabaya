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

  test "retention:scrub purges chat messages older than 30 days and revokes expired memberships" do
    ride = ride_posts(:one)
    booking = bookings(:one)
    booking.update_columns(status: Booking.statuses[:accepted])

    old_msg = ride.chat_messages.create!(user: ride.user, body: "Old message")
    old_msg.update_columns(created_at: 31.days.ago)

    recent_msg = ride.chat_messages.create!(user: ride.user, body: "Recent message")
    recent_msg.update_columns(created_at: 1.day.ago)

    membership = community_memberships(:one)
    membership.update_columns(verified_at: 1.month.ago, expires_at: 1.day.ago, revoked_at: nil)

    assert_difference("ChatMessage.count", -1) do
      Rake::Task["retention:scrub"].invoke
    end

    assert_not ChatMessage.exists?(old_msg.id)
    assert ChatMessage.exists?(recent_msg.id)
    assert membership.reload.revoked_at.present?
  end

  test "db:restore:finish invokes migrations and retention scrubbing" do
    assert_nothing_raised do
      Prosopite.pause do
        Rake::Task["db:restore:finish"].invoke
      end
    end
  end
end
