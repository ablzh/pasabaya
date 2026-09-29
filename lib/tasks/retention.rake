# frozen_string_literal: true

namespace :retention do
  desc "Scrub expired data (chat messages > 30 days, expired memberships) after database snapshot restoration"
  task scrub: :environment do
    count = ChatMessage.purge_expired!(30.days.ago).count
    puts "Retention scrub complete. Purged #{count} chat messages older than 30 days."

    CommunityMembership.revoke_expired!
    puts "Revoked expired community memberships."
  end
end
