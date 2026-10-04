# frozen_string_literal: true

module RouteSubscriptions
  class MatchService
    def self.call(...)
      new(...).call
    end

    def initialize(ride_post)
      @ride_post = ride_post
    end

    def call
      ride_post.reload if ride_post&.persisted?
      return unless ride_post&.offering? && ride_post.published? && ride_post.bookable?

      candidates = RouteSubscription.active.where(
        origin_id: ride_post.origin_id,
        destination_id: ride_post.destination_id
      )

      candidates.find_each do |sub|
        next unless sub.matches?(ride_post)

        fulfill_subscription(sub)
      end
    end

    private

    attr_reader :ride_post

    def fulfill_subscription(subscription)
      ActiveRecord::Base.transaction do
        sub = RouteSubscription.lock.find_by(id: subscription.id)
        ride_post.reload
        return unless sub && sub.active? && sub.matches?(ride_post)

        sub.update!(status: :fulfilled, consumed_at: Time.current, ride_post: ride_post)

        delivery_key = "route_alert:#{sub.id}:#{ride_post.id}"
        Notification.find_or_create_by!(delivery_key: delivery_key) do |n|
          n.recipient = sub.user
          n.actor = ride_post.user
          n.notifiable = ride_post
          n.route_subscription = sub
          n.event_name = "route.alert"
          n.delivery_status = :pending
        end
      end
    end
  end
end
