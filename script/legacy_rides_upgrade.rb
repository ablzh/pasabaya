require_relative "../config/environment"

require "digest"
require "json"

# Reviewed against the October 22 production snapshot. This is an operational
# import, never part of request handling or automatic database migrations.
class LegacyRidesUpgrade
  class Error < StandardError; end

  WEEKDAYS = [ 1, 2, 3, 4, 5 ].freeze
  # id, owner, origin, destination, seats, creation timestamp (UTC), notes SHA-256
  SOURCES = [
    [ 3, 2, 9, 5, 3, "2026-06-08 14:03:42.364003", "594faa30fa231f10a02b887f8a4d612cc30ae584a39708b0816d2f79b013dfe0" ],
    [ 4, 3, 42, 15, 6, "2026-06-09 05:47:34.564063", "558e102e806575449e3388af502874d9e5aa4e09cdc50994d6eb3126f4898ff1" ],
    [ 6, 3, 15, 42, 6, "2026-06-09 11:47:43.987977", "93fb552e4d17911cd2cd7734e4e68e3a12d901a9c8f59c226f9d53d0a331c610" ],
    [ 7, 5, 17, 51, 4, "2026-06-10 00:16:54.149902", "2fa29901b1dcdd92b7004cdcc192ec345960e7089d2c16c74de01846fd46bba2" ],
    [ 8, 6, 51, 10, 2, "2026-06-12 01:22:35.549754", "5ecc194fe5293ec4b8a43823551151622c7f946ee37a481f809d5c67ca02cd10" ],
    [ 9, 7, 15, 5, 4, "2026-06-12 10:45:26.236929", "6ff8b222e63c8ad6933f5b6a48e61a4951e719d1d95b87aa3ce17c3427c5b244" ],
    [ 10, 2, 54, 5, 3, "2026-06-15 04:58:43.755431", "be2a3a8fa257354677a20b7b99e76d2a929cfb187ebac8d1900b521b4650be43" ],
    [ 11, 10, 44, 32, 4, "2026-06-29 03:31:53.491981", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ],
    [ 12, 18, 8, 5, 3, "2026-09-07 08:25:59.227816", "a1b509a1e9ca6f38e03939dd4e1825d72226c479c78792109442d16ae85e6e25" ],
    [ 13, 19, 5, 42, 3, "2026-09-09 04:48:58.526736", "3a8bc44b3aa8fae599b341c0a29929749826163b38c92cd0ebfcd8e21bc5fa66" ],
    [ 14, 33, 5, 15, 4, "2026-09-28 10:33:23.660429", "f37036848f6d12696d702764c5a07e71cb82a9bb7083d189b263e42aee71bdff" ],
    [ 15, 38, 54, 5, 3, "2026-10-04 16:50:25.072379", "d480f409ca9f434094e2cc33fe2f46f41ccaf0fe27334db12e2bf490c951f9d0" ],
    [ 16, 38, 5, 54, 3, "2026-10-04 16:51:38.200042", "204236fc82fa1f87e5dcf5cba0b96943a0fdb316e4c5a59b5d682817f94c645d" ],
    [ 17, 43, 124, 129, 3, "2026-10-12 23:28:37.926933", "48ea82ecee6846b20dc31c7349dae40aa79ee08ff449f1f624a460e2c31e65ab" ]
  ].freeze

  # Time ranges retain their full wording in notes; the start is the initial
  # exact departure. Drivers can review these choices in the upgrade email.
  TIMES = { 3 => "06:30", 4 => "22:30", 6 => "00:30", 7 => "17:30", 8 => "12:30", 9 => "05:00", 12 => "04:45", 13 => "05:00", 15 => "06:30", 16 => "19:00", 17 => "06:30" }.freeze
  DAYS = { 4 => [ 1, 3, 4 ], 6 => [ 2, 4, 5 ], 13 => [ 5 ], 17 => (0..6).to_a }.freeze
  RETURN_TIMES = { 9 => "17:30", 17 => "17:00" }.freeze
  # These recent offers have real future dates, rather than recurring intent.
  # The final two fields pin their Philippine departure date and clock time.
  SINGLE_SOURCES = [
    [ 18, 50, 52, 50, 5, "2026-10-21 21:41:40.936218", "4b35ac7fdd64ba37ba153bd1f769bffec08190f2bd0a5f71a8bd0f07e89a5b83", "2026-10-23", "05:00" ],
    [ 19, 50, 10, 51, 5, "2026-10-21 21:47:41.862418", "8c0d3b670fb837ff70542b4bce008ed61954ad3236cfde98038b22a5da4f7847", "2026-10-25", "12:00" ]
  ].freeze
  AUDIENCE_IDS = (1..50).to_a.freeze

  def initialize(receipt_path: Rails.root.join("storage/legacy_rides_upgrade.json"), output: $stdout, sources: SOURCES, single_sources: SINGLE_SOURCES, audience_ids: AUDIENCE_IDS)
    @receipt_path = Pathname(receipt_path)
    @output = output
    @sources = sources
    @single_sources = single_sources
    @audience_ids = audience_ids
  end

  def import(dry_run: true)
    with_lock do
      receipt = @receipt_path.exist? ? read_receipt(complete: false) : { "groups" => {}, "audience_ids" => [], "notified" => {} }
      receipt["rides"] ||= []
      receipt["audience_ids"] |= @audience_ids
      RideSchedule.transaction do
        @sources.each do |entry|
          next if receipt.fetch("groups").key?(entry.first.to_s)

          source = checked_source(entry)
          apply_profile_choice(source) if source.id == 8
          schedules = [ create_schedule(source, end_date: Date.current + 30.days) ]
          if (clock = RETURN_TIMES[source.id])
            schedules << create_schedule(source, end_date: schedules.first.end_date, return_clock: clock)
          end
          receipt["groups"][source.id.to_s] = schedules.map(&:id)
          schedules.each { |schedule| @output.puts "Source ##{source.id}: #{schedule.origin.name} -> #{schedule.destination.name}; #{schedule.schedule_display}; #{schedule.status}; ends #{schedule.end_date}" }
        end
        @single_sources.each do |entry|
          next if receipt.fetch("rides").include?(entry.first)

          source = checked_source(entry)
          date, clock = entry.last(2)
          unless source.departure_date&.iso8601 == date && source.departure_time&.strftime("%H:%M") == clock
            raise Error, "Source ##{source.id} departure changed since review; inspect it before importing."
          end
          departure = Time.zone.parse("#{date} #{clock}")
          if departure.future?
            source.update!(status: :active, departure_choice: :exact_time, exact_departure_time: clock, remaining_seats: source.seats)
          end
          receipt["rides"] << source.id
          @output.puts "Source ##{source.id}: #{source.origin.name} -> #{source.destination.name}; #{date} #{clock} Philippine time; #{source.status}#{' (departure has passed; driver must choose a new date)' unless departure.future?}"
        end
        raise ActiveRecord::Rollback if dry_run
      end
      # Only acknowledge publication once its database transaction succeeds.
      write_receipt(receipt) unless dry_run
      @output.puts dry_run ? "Preview only: no rides saved or emails sent. Set EXECUTE=1 to import." : "Imported; previously imported rides and driver edits preserved. Review the site, then run legacy_rides:notify after deployment."
      receipt
    end
  end

  def notify(dry_run: true)
    with_lock do
      receipt = read_receipt
      schedules = RideSchedule.where(id: receipt.fetch("groups").values.flatten).group_by(&:user_id)
      rides = RidePost.where(id: receipt.fetch("rides", [])).group_by(&:user_id)
      receipt.fetch("audience_ids").each do |user_id|
        next if receipt.fetch("notified").key?(user_id.to_s)

        user = User.find_by(id: user_id)
        next unless user && !user.deleted? && user.banned_at.nil?

        offers = schedules.fetch(user_id, [])
        dated_offers = rides.fetch(user_id, [])
        owner = offers.any? || dated_offers.any?
        audience = owner ? "ride owner (#{offers.size} schedules, #{dated_offers.size} dated rides)" : "account update"
        @output.puts "#{dry_run ? 'Would email' : 'Emailing'} user ##{user_id}: #{audience}."
        next if dry_run

        delivery = if owner
          UserMailer.with(user_id: user_id, schedule_ids: offers.map(&:id), ride_ids: dated_offers.map(&:id)).ride_upgrade
        else
          UserMailer.with(user_id: user_id).platform_update
        end
        next if delivery.message.to.blank?

        delivery.message.raise_delivery_errors = true
        delivery.deliver_now
        receipt["notified"][user_id.to_s] = Time.current.iso8601
        write_receipt(receipt)
      end
      @output.puts dry_run ? "Preview only: no emails sent. Set EXECUTE=1 to send after deployment." : "Upgrade emails completed; successful sends recorded in the receipt."
    end
  end

  private

  def apply_profile_choice(source)
    # Explicit operator instruction for the reviewed owner of source 8.
    # This value is not inferred from names, photos, or ride descriptions.
    user = source.user
    raise Error, "Driver ##{user.id} has already selected a different gender; review before importing." unless user.unspecified? || user.female?

    user.update!(gender: :female) if user.unspecified?
  end

  def checked_source(entry)
    id, user_id, origin_id, destination_id, seats, created_at, digest = entry
    source = RidePost.lock.find(id)
    actual = [ source.user_id, source.origin_id, source.destination_id, source.seats, source.created_at.utc.strftime("%Y-%m-%d %H:%M:%S.%6N"), Digest::SHA256.hexdigest(source.notes.to_s) ]
    raise Error, "Source ##{id} changed since review; inspect it before importing." unless actual == [ user_id, origin_id, destination_id, seats, created_at, digest ]
    raise Error, "Source ##{id} must be a private draft without bookings after db:migrate." unless source.draft? && source.bookings.empty?
    raise Error, "Source ##{id} was already converted; restore its import receipt instead of importing again." if RideSchedule.exists?(source_ride_post_id: id)
    raise Error, "Driver ##{user_id} is no longer eligible." unless source.user.eligible_for_offering?

    source
  end

  def create_schedule(source, end_date:, return_clock: nil)
    clock = return_clock || TIMES[source.id]
    attributes = source.attributes.slice(*RideSchedule::OFFER_FIELDS).merge(
      weekday_ids: DAYS.fetch(source.id, WEEKDAYS), departure_choice: clock ? :exact_time : :flexible,
      departure_clock: clock, end_date: end_date, ladies_only: source.id == 8 || source.ladies_only?, status: :active
    )
    if return_clock || source.id == 13
      attributes.merge!("origin_id" => source.destination_id, "destination_id" => source.origin_id)
    end
    attributes[:status] = :draft if attributes[:ladies_only] && !source.user.female?
    schedule = source.user.ride_schedules.build(source_ride_post: return_clock ? nil : source)
    RideSchedules::ConfigureService.call(schedule: schedule, actor: source.user, attributes: attributes)
  end

  def with_lock
    File.open("#{@receipt_path}.lock", File::RDWR | File::CREAT, 0o600) do |file|
      file.flock(File::LOCK_EX)
      yield
    end
  end

  def read_receipt(complete: true)
    raise Error, "Run legacy_rides:import first; the saved receipt is required." unless @receipt_path.exist?

    receipt = JSON.parse(@receipt_path.read)
    groups = receipt.fetch("groups")
    linked = RideSchedule.where(source_ride_post_id: groups.keys).pluck(:source_ride_post_id, :id).to_h
    expected_groups = @sources.map { |entry| entry.first.to_s }
    valid = (groups.keys - expected_groups).empty? && groups.all? { |id, ids| ids.present? && linked[id.to_i] == ids.first }
    valid &&= groups.keys.sort == expected_groups.sort if complete
    valid &&= RideSchedule.where(id: groups.values.flatten).count == groups.values.flatten.size
    rides = receipt.fetch("rides", [])
    reviewed_rides = @single_sources.index_by(&:first)
    expected_rides = reviewed_rides.keys
    valid &&= (rides - expected_rides).empty? && rides.uniq == rides
    # Ordinary one-time offers can be deleted. Keep their IDs acknowledged so a
    # replay never restores them, and verify the identity of surviving offers.
    valid &&= RidePost.where(id: rides).pluck(:id, :user_id, :created_at).all? do |id, user_id, created_at|
      entry = reviewed_rides.fetch(id)
      user_id == entry[1] && created_at.utc.strftime("%Y-%m-%d %H:%M:%S.%6N") == entry[5]
    end
    valid &&= rides.sort == expected_rides.sort if complete
    raise Error, "Import receipt does not match this database; inspect it before continuing." unless valid

    receipt
  end

  def write_receipt(receipt)
    temporary_path = "#{@receipt_path}.tmp"
    File.write(temporary_path, JSON.pretty_generate(receipt), mode: "w", perm: 0o600)
    File.rename(temporary_path, @receipt_path)
  end
end
