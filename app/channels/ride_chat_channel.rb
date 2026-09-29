# frozen_string_literal: true

class RideChatChannel < ActionCable::Channel::Base
  extend Turbo::Streams::Broadcasts, Turbo::Streams::StreamName
  include Turbo::Streams::StreamName::ClassMethods

  def subscribed
    if (stream_name = verified_stream_name_from_params).present?
      ride = locate_ride(stream_name)

      if ride && current_user && ride.user_authorized_for_chat?(current_user)
        stream_from stream_name
      else
        reject
      end
    else
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
