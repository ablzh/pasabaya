# frozen_string_literal: true

class RideChatChannel < ApplicationCable::Channel
  extend Turbo::Streams::Broadcasts, Turbo::Streams::StreamName
  include Turbo::Streams::StreamName::ClassMethods

  def subscribed
    if (stream_name = verified_stream_name_from_params).present?
      ride = locate_ride(stream_name)

      if active_session? && ride && current_user && ride.user_authorized_for_chat?(current_user)
        stream_from stream_name, coder: ActiveSupport::JSON do |data|
          deliver_or_reject(ride, stream_name, data)
        end
      else
        reject
      end
    else
      reject
    end
  end

  def deliver_or_reject(ride, stream_name, data)
    user = begin
      current_user&.reload
    rescue ActiveRecord::RecordNotFound
      nil
    end

    if active_session? && user && ride.reload.user_authorized_for_chat?(user)
      transmit data
    else
      stop_stream_from stream_name
      reject
    end
  end

  private

  def locate_ride(stream_name)
    gid_part = stream_name.to_s.split(":").first
    return unless gid_part

    decoded = begin
      Base64.urlsafe_decode64(gid_part)
    rescue ArgumentError
      Base64.decode64(gid_part)
    end

    GlobalID::Locator.locate(decoded)
  rescue StandardError
    nil
  end
end
