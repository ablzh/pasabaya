# frozen_string_literal: true

class RetainOnlyUpCommunity < ActiveRecord::Migration[8.1]
  def up
    Community.cleanup_disposable_local_hubs!

    # Ensure University of the Philippines has canonical name and slug
    up_community = Community.find_by(domain: "up.edu.ph")
    if up_community
      up_community.update!(
        name: "University of the Philippines",
        slug: "university-of-the-philippines",
        hub_type: :campus
      )
    end
  end

  def down
    # Irreversible cleanup of local disposable test data
  end
end
