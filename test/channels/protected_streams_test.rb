require "test_helper"

class ProtectedStreamsTest < ActionCable::Channel::TestCase
  tests Turbo::StreamsChannel

  test "generic streams cannot bypass ride chat authorization" do
    stub_connection current_user: users(:one), current_session: users(:one).sessions.create!
    subscribe signed_stream_name: Turbo::StreamsChannel.signed_stream_name([ ride_posts(:one), :chat ])
    assert subscription.rejected?
  end
end
