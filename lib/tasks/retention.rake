# frozen_string_literal: true

namespace :retention do
  desc "Initialize an empty deletion registry on a new installation only (never after restoring a backup)"
  task initialize_registry: :environment do
    Users::DeletionRegistry.initialize!
    User.where.not(deleted_at: nil).find_each do |user|
      Users::DeletionRegistry.record!(user, deleted_at: user.deleted_at)
    end
  end

  desc "Scrub expired data (chat messages > 30 days, expired memberships) and re-apply account deletions after database snapshot restoration"
  task scrub: :environment do
    count = ChatMessage.purge_expired!(30.days.ago).count
    puts "Retention scrub complete. Purged #{count} chat messages older than 30 days."

    CommunityMembership.revoke_expired!
    puts "Revoked expired community memberships."

    # Close the journal before replaying: anonymization may append to it.
    deletions = []
    Users::DeletionRegistry.each { |entry| deletions << entry }
    reapplied_count = 0
    deletions.uniq.each do |user_id, created_at, _deleted_at|
      user = User.find_by(id: user_id)
      next unless user && user.created_at.iso8601(6) == created_at && !user.deleted?

      unless Users::AnonymizeService.call(user)
        raise Users::AnonymizeService::Error, "Restored User##{user.id} could not be anonymized"
      end
      reapplied_count += 1
    end
    puts "Re-applied anonymization for #{reapplied_count} restored user account(s)."
    AccountDeletionTombstone.where.not(avatar_blob_id: nil).find_each(&:enqueue_avatar_purge)
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
