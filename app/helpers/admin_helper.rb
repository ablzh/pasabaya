# frozen_string_literal: true

module AdminHelper
  def admin_user_name(user)
    return "Unknown account" unless user
    return "Deleted account (##{user.id})" if user.deleted?

    "#{user.first_name} #{user.last_name} (##{user.id})"
  end

  def admin_route_name(ride)
    "#{ride.origin&.name || 'Unspecified origin'} → #{ride.destination&.name || 'Unspecified destination'}"
  end

  def admin_timestamp(value)
    value ? value.in_time_zone("Asia/Manila").strftime("%b %-d, %Y, %-I:%M %p") : "Not recorded"
  end

  def admin_field_classes
    "mt-1 w-full rounded-lg border border-neutral-300 bg-white px-3 py-2 text-sm text-neutral-900 dark:border-neutral-600 dark:bg-neutral-900 dark:text-neutral-100"
  end

  def admin_status_badge(status)
    variant = { "pending" => :yellow, "appealed" => :yellow, "upheld" => :red, "dismissed" => :green }.fetch(status, :neutral)
    render Badge::Component.new(text: status.humanize, variant: variant)
  end
end
