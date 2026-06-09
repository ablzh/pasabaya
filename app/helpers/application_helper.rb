module ApplicationHelper
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
