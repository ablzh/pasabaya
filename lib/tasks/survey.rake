# frozen_string_literal: true

namespace :survey do
  desc "Broadcast community survey email to all active users (DRY RUN by default, pass EXECUTE=1 to send)"
  task broadcast: :environment do
    dry_run = ENV["EXECUTE"] != "1"
    active_users = User.where(banned_at: nil, deleted_at: nil).where.not(email_address: [ nil, "" ]).order(:id)
    total_count = active_users.count

    puts "============================================================"
    puts "COMMUNITY SURVEY EMAIL BROADCAST"
    puts "============================================================"
    puts "Mode: #{dry_run ? 'DRY RUN (Preview only, no emails will be sent)' : 'EXECUTE (Queueing emails for sending)'}"
    puts "Total active recipients: #{total_count}"
    puts "Subject: Help shape what we build next for Pasabaya (10-min survey)"
    puts "============================================================"

    if total_count.zero?
      puts "No active users found."
      next
    end

    puts "\nSample recipients (first 5):"
    active_users.limit(5).each do |user|
      puts " - [##{user.id}] #{user.first_name} <#{user.email_address}>"
    end

    if dry_run
      puts "\n[DRY RUN COMPLETE] No emails were queued or sent."
      puts "To actually queue emails for all #{total_count} users, run:"
      puts "  EXECUTE=1 bin/rails survey:broadcast"
      puts "============================================================"
    else
      puts "\nQueueing emails..."
      enqueued_count = 0
      active_users.find_each do |user|
        UserMailer.with(user_id: user.id).community_survey.deliver_later
        enqueued_count += 1
        print "." if (enqueued_count % 10).zero?
      end
      puts "\nDone! Successfully enqueued #{enqueued_count} emails into background queue."
      puts "============================================================"
    end
  end
end
