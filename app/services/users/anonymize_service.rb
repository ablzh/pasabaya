# frozen_string_literal: true

module Users
  class AnonymizeService
    class Error < StandardError; end

    def self.call(user)
      new(user).call
    end

    def initialize(user)
      @user = user
    end

    def call
      User.transaction do
        user.lock!
        unless user.deleted?
          original_email = user.email_address
          original_unconfirmed = user.unconfirmed_email
          avatar_blob = user.avatar.blob if user.avatar.attached?
          deleted_at = Time.current

          # Persist deletion intent outside database snapshots before changing any records.
          Users::DeletionRegistry.record!(user, deleted_at: deleted_at)
          cancel_active_commitments!
          scrub_user_profile!(deleted_at)
          deidentify_retained_history!
          destroy_ephemeral_associations!(original_email, original_unconfirmed)
          record_tombstone!(avatar_blob)
        end
      end

      AccountDeletionTombstone.find_by(user_id: user.id)&.enqueue_avatar_purge

      true
    rescue StandardError => e
      Rails.logger.error("[Users::AnonymizeService] Failed to anonymize User##{user.id}: #{e.message}")
      false
    end

    private

    attr_reader :user

    def cancel_active_commitments!
      # Cancel pending and accepted passenger bookings
      user.bookings.active.find_each do |b|
        Bookings::CancelService.call(b, actor: user)
      end

      # Cancel active and fulfilled driver rides
      user.ride_posts.where(status: %i[active fulfilled]).find_each do |ride|
        RidePosts::CancelService.call(ride, actor: user)
      end
    end

    def scrub_user_profile!(deleted_at)
      # Collision-resistant unique email using cryptographic randomness
      collision_safe_email = "deleted-#{user.id}-#{SecureRandom.hex(12)}@deleted.pasabaya.app"

      user.update_columns(
        first_name: "Deleted",
        last_name: "User",
        email_address: collision_safe_email,
        unconfirmed_email: nil,
        password_digest: BCrypt::Password.create(SecureRandom.hex(32)),
        facebook_profile_url: nil,
        gender: User.genders[:unspecified],
        banned_at: nil,
        booking_freeze_until: nil,
        deleted_at: deleted_at,
        updated_at: Time.current
      )

      # Detach avatar attachment in database (physical file deleted post-commit)
      user.avatar.detach if user.avatar.attached?
    end

    def deidentify_retained_history!
      # Scrub free-form notes from all departed ride offers created by this user
      user.ride_posts.where.not(notes: nil).find_each do |ride|
        ride.update_columns(notes: nil)
      end

      # Scrub passenger pickup notes from all bookings made by this user
      user.bookings.where.not(pickup_notes: nil).find_each do |booking|
        booking.update_columns(pickup_notes: nil)
      end

      reviews = TripReview.where(reporter_id: user.id).or(TripReview.where(reported_user_id: user.id))

      # Link reporters through the review's trip and subject, never through their names.
      reported_incident_ids = NoShowIncident.joins("INNER JOIN trip_reviews ON trip_reviews.ride_post_id = no_show_incidents.ride_post_id AND trip_reviews.reported_user_id = no_show_incidents.user_id")
                                            .where(trip_reviews: { reporter_id: user.id }).pluck(:id)
      driver_incident_ids = NoShowIncident.joins(:ride_post).where(ride_posts: { user_id: user.id }).pluck(:id)
      historic_reviewed_incident_ids = user.incident_decisions.pluck(:no_show_incident_id)
      all_incident_ids = reported_incident_ids + driver_incident_ids + user.no_show_incidents.ids + user.adjudicated_incidents.ids + historic_reviewed_incident_ids

      NoShowIncident.where(id: all_incident_ids).find_each do |incident|
        incident.update_columns(decision_reason: "Reported by former user (account deleted); outcome preserved for safety records.")
      end
      NoShowIncidentDecision.where(no_show_incident_id: all_incident_ids).update_all(reason: nil)

      reviews.update_all(notes: nil)
    end

    def destroy_ephemeral_associations!(orig_email, orig_unconfirmed)
      # Terminate active sessions immediately
      user.sessions.destroy_all

      # Purge user chat messages
      user.chat_messages.destroy_all

      # Purge received and acted notifications
      user.received_notifications.destroy_all
      Notification.where(actor_id: user.id).update_all(actor_id: nil)

      # Remove institutional community memberships
      user.community_memberships.destroy_all

      # Remove route alert subscriptions
      user.route_subscriptions.destroy_all

      # Remove newsletter / waitlist subscriptions
      Subscriber.where(email: [ orig_email, orig_unconfirmed ].compact).destroy_all
    end

    def record_tombstone!(avatar_blob)
      AccountDeletionTombstone.find_or_create_by!(user_id: user.id) do |tombstone|
        tombstone.anonymized_email = user.email_address
        tombstone.deleted_at = user.deleted_at
        tombstone.avatar_blob_id = avatar_blob&.id
        tombstone.avatar_key = avatar_blob&.key
        tombstone.avatar_service_name = avatar_blob&.service_name
      end
    end
  end
end
