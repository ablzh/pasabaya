# frozen_string_literal: true

require "application_system_test_case"
require "json"
require "uri"

class AnalyticsPrivacyTest < ApplicationSystemTestCase
  test "direct reset visits and failed submissions do not contact analytics" do
    with_production_analytics do
      token = users(:one).password_reset_token
      visit edit_password_path(token, email: "private-reset@example.com")
      assert_selector "#password_reset_form"
      page.refresh
      assert_selector "#password_reset_form"
      assert_analytics_paths []

      submit_invalid_password
      assert_analytics_paths []

      within("footer") { click_link "Privacy", exact: true }
      assert_current_path privacy_path
      assert_analytics_paths [ "/privacy" ]
      assert_no_sensitive_data(token, "private-reset@example.com")
    end
  end

  test "public visits count once and Turbo navigation never exposes reset URLs" do
    with_production_analytics do
      token = users(:one).password_reset_token
      visit root_path(token: token, email: "private-query@example.com")
      assert_analytics_paths [ "/" ]
      page.refresh
      assert_analytics_paths [ "/", "/" ]
      page.execute_script("window.analyticsDocumentMarker = 'same-document'")

      page.execute_script("Turbo.visit(arguments[0])", edit_password_path(token, email: "private-reset@example.com"))
      assert_selector "#password_reset_form"
      assert_equal "same-document", page.evaluate_script("window.analyticsDocumentMarker")
      assert_analytics_paths [ "/", "/" ]

      submit_invalid_password
      assert_analytics_paths [ "/", "/" ]

      within("footer") { click_link "Terms", exact: true }
      assert_current_path terms_path
      assert_analytics_paths [ "/", "/", "/terms" ]
      within("footer") { click_link "Privacy", exact: true }
      assert_current_path privacy_path
      assert_analytics_paths [ "/", "/", "/terms", "/privacy" ]
      assert_no_sensitive_data(token, "private-query@example.com", "private-reset@example.com")
    end
  end

  test "route search uses a generic analytics path without search parameters" do
    with_production_analytics do
      origin_slug, destination_slug = Location.limit(2).pluck(:slug)
      visit route_rides_path(origin_slug: origin_slug, destination_slug: destination_slug, email: "private-search@example.com")
      assert_selector "#ride_search_form"
      assert_analytics_paths [ "/rides" ]
      assert_equal "Ride Search", @analytics_requests.sole.fetch(:parameters).fetch("t")
      assert_no_sensitive_data("private-search@example.com", origin_slug, destination_slug)
    end
  end

  test "the existing analytics opt out applies to Turbo visits and reloads" do
    with_production_analytics do
      visit root_path
      assert_analytics_paths [ "/" ]
      page.execute_script("localStorage.setItem('skipgc', 't')")

      within("footer") { click_link "Privacy", exact: true }
      assert_current_path privacy_path
      assert_analytics_paths [ "/" ]
      page.refresh
      assert_analytics_paths [ "/" ]

      page.execute_script("localStorage.removeItem('skipgc')")
      within("footer") { click_link "Terms", exact: true }
      assert_current_path terms_path
      assert_analytics_paths [ "/", "/terms" ]
    end
  end

  private

  def with_production_analytics
    @sdk_requests = []
    @analytics_requests = []
    browser = page.driver.browser
    browser.network.intercept
    browser.on(:request) do |request|
      case URI(request.url).host
      when "gc.zgo.at"
        @sdk_requests << request.url
        request.respond(body: "", responseHeaders: { "Content-Type" => "application/javascript" })
      when "pasabaya.goatcounter.com"
        @analytics_requests << {
          parameters: URI.decode_www_form(URI(request.url).query.to_s).to_h,
          headers: request.headers
        }
        request.respond(body: "", responseHeaders: { "Content-Type" => "image/gif", "Cache-Control" => "no-store" })
      else
        request.continue
      end
    end

    with_stubbed_method(Rails.env, :production?, true) { yield }
  ensure
    page.driver.reset!
  end

  def submit_invalid_password
    fill_in "New Password", with: "synthetic-new-password"
    fill_in "Confirm Password", with: "different-password"
    click_button "Save"
    assert_selector "#password_confirmation_error"
  end

  def assert_analytics_paths(paths)
    page.document.synchronize do
      unless @analytics_requests.size >= paths.size
        raise Capybara::ExpectationNotMet, "Waiting for the expected public pageviews"
      end
    end
    page.driver.wait_for_network_idle
    assert_equal paths, @analytics_requests.map { |request| request.fetch(:parameters).fetch("p") }
    assert_empty @sdk_requests, "The third-party SDK must never load"
  end

  def assert_no_sensitive_data(*values)
    recorded = JSON.generate(@analytics_requests)
    values.each { |value| assert_not_includes recorded, value }
    @analytics_requests.each do |request|
      assert_empty request.fetch(:parameters).keys - %w[p t rnd], "Only public page identifiers and cache-busting data may be sent"
      assert request.fetch(:headers).none? { |name, _| name.casecmp?("referer") }, "Analytics requests must omit the referring URL"
    end
  end
end
