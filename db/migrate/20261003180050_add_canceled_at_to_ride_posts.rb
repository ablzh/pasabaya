# frozen_string_literal: true

class AddCanceledAtToRidePosts < ActiveRecord::Migration[8.1]
  def change
    add_column :ride_posts, :canceled_at, :datetime

    reversible do |dir|
      dir.up do
        execute("UPDATE ride_posts SET canceled_at = updated_at WHERE status = 2 AND canceled_at IS NULL")
      end
    end
  end
end
