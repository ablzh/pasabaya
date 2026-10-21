require "test_helper"
require Rails.root.join("script/legacy_rides_upgrade")

class LegacyRidesUpgradeTest < ActiveSupport::TestCase
  # This operator batch intentionally repeats independent domain transitions;
  # request-level query repetition is not a regression signal for this script.
  setup do
    Prosopite.pause
    travel_to Time.zone.local(2026, 10, 20, 10)
    @directory = Dir.mktmpdir("legacy-rides-upgrade-")
    @receipt_path = File.join(@directory, "receipt.json")
    @driver = users(:one)
    @sources = [ 9, 13, 17, 8, 15, 10 ].map do |id|
      @driver.ride_posts.create!(id: id, status: :draft, origin: locations(:one), destination: locations(:two), seats: 3, notes: "Original description for #{id}. " * 20)
    end
    @sources.find { |source| source.id == 15 }.update_columns(departure_date: Date.new(2026, 10, 5), departure_choice: RidePost.departure_choices[:exact_time], departure_time: Time.zone.local(2026, 10, 5, 6, 30))
    entries = @sources.map do |source|
      [ source.id, source.user_id, source.origin_id, source.destination_id, source.seats, source.created_at.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"), Digest::SHA256.hexdigest(source.notes) ]
    end
    @upgrade = LegacyRidesUpgrade.new(receipt_path: @receipt_path, output: StringIO.new, sources: entries, audience_ids: [ @driver.id, users(:two).id ])
  end

  teardown do
    FileUtils.remove_entry(@directory)
    travel_back
    Prosopite.resume
  end

  test "preview validates the import without saving schedules or sending mail" do
    assert_no_difference [ "RideSchedule.count", "RidePost.count", "ActionMailer::Base.deliveries.size" ] do
      @upgrade.import
    end
    assert_not File.exist?(@receipt_path)
    assert @driver.reload.unspecified?
  end

  test "import preserves originals and creates reviewed directions times and full descriptions" do
    originals = @sources.map(&:attributes)
    receipt = @upgrade.import(dry_run: false)
    schedules = receipt.fetch("groups").transform_values { |ids| RideSchedule.find(ids) }
    assert_equal 8, schedules.values.flatten.size
    assert_equal originals, @sources.map { |source| source.reload.attributes }
    assert_equal [ "05:00", "17:30" ], schedules.fetch("9").map(&:departure_clock)
    assert_equal [ "06:30", "17:00" ], schedules.fetch("17").map(&:departure_clock)
    assert_equal [ (0..6).to_a ], schedules.fetch("17").map(&:weekday_ids).uniq
    friday = schedules.fetch("13").first
    assert_equal [ 5 ], friday.weekday_ids
    assert_equal "05:00", friday.departure_clock
    assert_equal locations(:two), friday.origin
    assert_equal locations(:one), friday.destination
    flexible = schedules.fetch("10").first
    assert_equal [ 1, 2, 3, 4, 5 ], flexible.weekday_ids
    assert flexible.flexible?
    schedules.values.flatten.each do |schedule|
      assert_equal Date.new(2026, 11, 19), schedule.end_date
      assert_operator schedule.notes.length, :>, 300
      assert schedule.ride_posts.all? { |ride| ride.departure_date >= Date.current && ride.notes == schedule.notes }
    end
    dated = schedules.fetch("15").first
    RideSchedules::ConfigureService.call(schedule: dated, actor: @driver, attributes: { departure_clock: "07:00" })
    assert_equal "07:00", dated.reload.departure_clock
  end

  test "the explicit profile choice publishes the ladies only schedule with its restriction" do
    @upgrade.import(dry_run: false)
    schedule = RideSchedule.find_by!(source_ride_post_id: 8)
    assert schedule.ladies_only?
    assert schedule.active?
    assert_equal [ 1, 2, 3, 4, 5 ], schedule.weekday_ids
    assert_equal "12:30", schedule.departure_clock
    assert @driver.reload.female?
    assert_not_empty schedule.ride_posts
    assert_not schedule.authorized_viewer?(nil)
    assert schedule.ride_posts.all?(&:ladies_only?)
  end

  test "a later profile choice is not overwritten by the reviewed assignment" do
    @driver.update!(gender: :male)
    assert_no_difference [ "RideSchedule.count", "RidePost.count" ] do
      assert_raises(LegacyRidesUpgrade::Error) { @upgrade.import(dry_run: false) }
    end
    assert @driver.reload.male?
  end

  test "a replay preserves driver edits expiry and return schedules" do
    @upgrade.import(dry_run: false)
    schedule = RideSchedule.find_by!(source_ride_post_id: 9)
    RideSchedules::ConfigureService.call(schedule: schedule, actor: @driver, attributes: { departure_clock: "06:00", end_date: Date.new(2026, 11, 10) })
    travel_to Time.zone.local(2026, 10, 22, 10)
    assert_no_difference [ "RideSchedule.count", "RidePost.count" ] do
      @upgrade.import(dry_run: false)
    end
    assert_equal "06:00", schedule.reload.departure_clock
    assert_equal Date.new(2026, 11, 10), schedule.end_date
  end

  test "a changed reviewed source rolls back all schedules and leaves no receipt" do
    @sources.last.update!(notes: "Changed after the snapshot")
    assert_no_difference [ "RideSchedule.count", "RidePost.count" ] do
      assert_raises(LegacyRidesUpgrade::Error) { @upgrade.import(dry_run: false) }
    end
    assert_not File.exist?(@receipt_path)
  end

  test "sources with bookings cannot be imported" do
    bookings(:one).update_columns(ride_post_id: @sources.last.id)
    assert_no_difference "RideSchedule.count" do
      assert_raises(LegacyRidesUpgrade::Error) { @upgrade.import(dry_run: false) }
    end
  end

  test "post deployment notification is explicit and successful sends are not repeated" do
    @upgrade.import(dry_run: false)
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      @upgrade.notify
    end
    assert_difference "ActionMailer::Base.deliveries.size", 2 do
      @upgrade.notify(dry_run: false)
      @upgrade.notify(dry_run: false)
    end
    mail_by_recipient = ActionMailer::Base.deliveries.last(2).index_by { |mail| mail.to.first }
    assert_includes mail_by_recipient.fetch(@driver.email_address).subject, "regular rides"
    general = mail_by_recipient.fetch(users(:two).email_address)
    assert_includes general.subject, "updated"
    assert_not_includes general.text_part.body.decoded, "moved your previous ride posts"
  end

  test "the campaign excludes later signups and rechecks account deletion and bans" do
    @upgrade.import(dry_run: false)
    User.create!(first_name: "New", last_name: "User", email_address: "later@example.com", password: "password123")
    @driver.update_column(:banned_at, Time.current)
    users(:two).update_column(:deleted_at, Time.current)
    assert_no_difference "ActionMailer::Base.deliveries.size" do
      @upgrade.notify(dry_run: false)
    end
  end
end
