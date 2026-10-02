module ApplicationHelper
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
    when "communities" then @community&.name || "Hubs"
    when "settings/profiles", "settings/emails", "settings/passwords", "settings/users" then "Account"
    when "trip_reviews" then "Trip Feedback"
    when "pages" then { "privacy" => "Privacy Policy", "terms" => "Terms of Service" }.fetch(action_name, "Pasabaya")
    else "Pasabaya"
    end
  end

  # Renders a user's avatar or falls back to their initials.
  # We pass a `classes` argument to allow the caller to define the size (e.g. "w-10 h-10")
  # because Tailwind's JIT compiler needs to see complete class names in the code.

  def user_avatar(user, classes: "w-10 h-10")
    base_classes = "rounded-full object-cover flex items-center justify-center font-medium bg-neutral-200 text-neutral-600 #{classes}"
    if user.avatar.attached?
      # Uses the optimized :thumb variant we defined in the model!
      image_tag user.avatar.variant(:thumb), class: base_classes
    else
      tag.div user.initials, class: base_classes
    end
  end

  def possessive(word)
    return "" if word.blank?
    str = word.to_s

    if str.end_with?("s", "S")
      "#{str}'"
    else
      "#{str}'s"
    end
  end
end
