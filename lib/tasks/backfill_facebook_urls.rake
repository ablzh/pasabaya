# frozen_string_literal: true

namespace :users do
  desc "Clean up and backfill legacy Facebook profile URLs (DRY_RUN=1 by default, set DRY_RUN=0 or EXECUTE=1 to apply)"
  task backfill_facebook_urls: :environment do
    dry_run = ENV["EXECUTE"] != "1" && ENV["DRY_RUN"] != "0"
    puts dry_run ? "Running Facebook URL cleanup in DRY RUN mode..." : "Applying Facebook URL cleanup..."

    result = Users::BackfillFacebookUrlsService.run(dry_run: dry_run)

    puts "Total users checked: #{result.counts[:total]}"
    puts "Unchanged:           #{result.counts[:unchanged]}"
    puts "Repairable:          #{result.counts[:repairable]}"
    puts "Unrepairable (cleared): #{result.counts[:unrepairable]}"

    if dry_run
      puts "Dry run complete. No records modified. Set EXECUTE=1 or DRY_RUN=0 to apply changes."
    else
      puts "Cleanup completed successfully."
      puts "Backup saved to: #{result.backup_path}" if result.backup_path
    end
  end
end
