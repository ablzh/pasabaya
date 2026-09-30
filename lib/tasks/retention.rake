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

namespace :db do
  namespace :restore do
    desc "Post-restoration workflow: run migrations and automated retention scrubbing before serving traffic"
    task finish: :environment do
      Rake::Task["db:migrate"].invoke if Rake::Task.task_defined?("db:migrate")
      Rake::Task["retention:scrub"].invoke
    end
  end
end
