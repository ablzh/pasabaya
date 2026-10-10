module ApplicationHelper
  def current_unread_chats_count
    @current_unread_chats_count ||= Current.user.unread_chats_count
  end

  def native_page_title
    case controller_path
    when "ride_posts"
      case action_name
      when "show" then "#{@ride_post.origin.name} → #{@ride_post.destination.name}"
      when "new", "create" then "Post a Ride"
      when "edit", "update" then "Edit Ride"
      else "Search"
      end
    when "users" then action_name == "trips" ? "My Trips" : "Profile"
    when "sessions" then "Sign in"
    when "registrations" then "Sign up"
    when "passwords" then "Reset Password"
    when "notifications" then "Notifications"
    when "chats" then "Chats"
    when "communities" then @community&.name || "Hubs"
    when "settings/profiles", "settings/emails", "settings/passwords", "settings/users" then "Account"
    when "trip_reviews" then "Trip Feedback"
    when "pages" then { "privacy" => "Privacy Policy", "terms" => "Terms of Service" }.fetch(action_name, "Pasabaya")
    else "Pasabaya"
    end
  end

  # Renders a user's avatar or falls back to their initials.
  def user_avatar(user, classes: "w-10 h-10")
    return if user.blank?

    render Avatar::Component.new(
      alt: [ user.first_name, user.last_name ].compact.join(" "),
      src: user.avatar.attached? ? url_for(user.avatar.variant(:thumb)) : nil,
      fallback: user.initials,
      classes: "font-medium text-neutral-600 #{classes}",
      fallback_text_classes: "text-[length:inherit] text-inherit"
    )
  end
end
