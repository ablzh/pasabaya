require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "should get sitemap xml with all expected urls" do
    get sitemap_url
    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type

    # Verify static pages
    assert_includes response.body, root_url
    assert_includes response.body, privacy_url
    assert_includes response.body, terms_url

    # Verify active ride posts
    ride_post = ride_posts(:one)
    assert_includes response.body, ride_post_url(ride_post)
    assert_includes response.body, "<lastmod>#{ride_post.updated_at.iso8601}</lastmod>"

    # Verify route pages
    route_url = route_rides_url(origin_slug: ride_post.origin.slug, destination_slug: ride_post.destination.slug)
    assert_includes response.body, route_url
  end
end
