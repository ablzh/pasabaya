require "test_helper"

class SessionTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  test "destroying a session disconnects its live connections without reconnecting" do
    session = users(:one).sessions.create!
    remote = ActionCable.server.remote_connections.where(current_user: session.user, current_session: session)
    stream = remote.send(:internal_channel)

    assert_broadcast_on(stream, { type: "disconnect", reconnect: false }) do
      session.destroy!
    end
  end
end
