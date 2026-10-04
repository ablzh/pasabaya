# frozen_string_literal: true

class RetainOnlyUpCommunity < ActiveRecord::Migration[8.1]
  def up
    # Clean up non-UP communities and their disposable local associated data
    non_up_communities = Community.where.not(domain: "up.edu.ph")
    non_up_communities.find_each do |community|
      # Destroy any ride posts associated with this unwanted hub to avoid turning them public
      community.ride_posts.destroy_all
      community.route_subscriptions.destroy_all
      community.community_memberships.destroy_all
      community.destroy!
    end

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
