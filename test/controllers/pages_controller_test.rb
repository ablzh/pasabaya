# frozen_string_literal: true

require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home with active carpool routes" do
    get root_url
    assert_response :success
    assert_select "a[href='#{route_rides_path(origin_slug: locations(:one).slug, destination_slug: locations(:two).slug)}']"
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
