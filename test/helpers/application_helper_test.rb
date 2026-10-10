# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "user_avatar renders fallback initials when avatar not attached" do
    user = users(:one)
    avatar = Nokogiri::HTML.fragment(user_avatar(user, classes: "w-32 h-32 text-3xl")).at_css("span[role='img']")

    assert_equal [ user.first_name, user.last_name ].compact.join(" "), avatar["aria-label"]
    assert_equal user.initials, avatar.at_css("[aria-hidden='true']").text
    %w[w-32 h-32 text-3xl].each { |css_class| assert_includes avatar["class"].split, css_class }
  end

  test "user_avatar uses the thumbnail variant and an accessible name for uploaded photos" do
    user = users(:one)
    user.avatar.attach(io: StringIO.new(Vips::Image.black(2, 2).pngsave_buffer), filename: "avatar.png", content_type: "image/png")

    avatar = Nokogiri::HTML.fragment(user_avatar(user, classes: "size-7")).at_css("span")
    image = avatar.at_css("img")

    assert_equal [ user.first_name, user.last_name ].compact.join(" "), image["alt"]
    assert_equal url_for(user.avatar.variant(:thumb)), image["src"]
    assert_includes avatar["class"].split, "size-7"
    assert_nil avatar["role"]
  end

  test "user_avatar returns nil when user is blank" do
    assert_nil user_avatar(nil)
  end
end
