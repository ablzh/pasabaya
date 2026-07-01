require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "should get sitemap xml" do
    get sitemap_url
    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type
    # Проверяем, что в теле ответа сгенерировался XML-тег <loc>
    assert_match "<loc>", response.body
  end
end
