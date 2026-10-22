class AddRequestsClosedAtToRidePosts < ActiveRecord::Migration[8.1]
  def change
    add_column :ride_posts, :requests_closed_at, :datetime
  end
end
