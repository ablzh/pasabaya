xml.instruct! :xml, version: "1.0"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  @static_pages.each do |url|
    xml.url do
      xml.loc url
      xml.changefreq "weekly"
      xml.priority 0.9
    end
  end

  @routes.each do |url|
    xml.url do
      xml.loc url
      xml.changefreq "daily"
      xml.priority 0.9
    end
  end
end
