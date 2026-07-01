xml.instruct! :xml, version: "1.0"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  @static_pages.each do |url|
    xml.url do
      xml.loc url
      xml.changefreq "daily"
      xml.priority 1.0
    end
  end

  @routes.each do |url|
    xml.url do
      xml.loc url
      xml.changefreq "hourly"
      xml.priority 0.8
    end
  end

  @ride_posts.each do |ride|
    xml.url do
      xml.loc ride_post_url(ride)
      xml.lastmod ride.updated_at.iso8601
      xml.changefreq "weekly"
      xml.priority 0.6
    end
  end
end
