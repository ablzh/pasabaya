# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home with active carpool routes" do
    get root_url
    assert_response :success
    assert_select "a[href='#{route_rides_path(origin_slug: locations(:one).slug, destination_slug: locations(:two).slug)}']"
  end

  test "home preserves the community introduction and explains available and upcoming features" do
    get root_url
    assert_response :success

    assert_equal "Carpooling for the Community, Not for Profit.", css_select("#home-introduction h1").first.text.squish
    assert_equal "A smarter, social way to find travel companions in the Philippines. No fees. No commissions. Just people helping people beat the traffic.", css_select("#home-introduction > p").first.text.squish
    assert_select "a#home_passenger_start[href='#{ride_posts_path}']"
    assert_select "a#home_regular_ride[href='#{new_ride_post_path(ride_type: 'regular')}']"
    assert_select "a#home_community_hubs[href='#{communities_path}']"
    assert_select "#home-chat", text: /Once a seat request is accepted.*private chat/m
    assert_select "#home-apps", text: /Coming soon.*iOS and Android/m
  end

  test "privacy page is available with contact and material privacy disclosures" do
    get privacy_url
    assert_response :success

    assert_select "h1", text: "Privacy Policy"

    # Disclosures
    assert_select "li", text: /Public Visitors.*first name, last name, and profile avatar/
    assert_select "a[href='mailto:privacy@pasabaya.app']"
    assert_select "li", text: /six monthly, and two yearly snapshots/
    assert_select "li", text: /separate persistent deletion registry/
    assert_select "li", text: /At the history deadline.*inaccessible.*scheduled for permanent deletion/
    assert_select "li", text: /Queue delays.*physical deletion/
    assert_select "li", text: /canceled while messaging is open.*24 hours after cancellation/
    assert_select "li", text: /GoatCounter \(goatcounter\.com\)/
  end

  test "terms page is available with contact and booking restriction disclosures" do
    get terms_url
    assert_response :success

    assert_select "h1", text: "Terms of Service"

    assert_select "li", text: /rolling 60-day window/
    assert_select "li", text: /7-day freeze/
    assert_select "a[href='mailto:legal@pasabaya.app']"
  end
end
