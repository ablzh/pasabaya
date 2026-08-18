class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[ home privacy terms ]
  def home
    @grouped_locations = Location.grouped_by_region
    @popular_routes = RidePost.popular_routes
    set_meta_tags(canonical: root_url)
  end

  def privacy
    set_meta_tags(
      title: "Privacy Policy",
      canonical: privacy_url,
      og: { url: privacy_url }
    )
  end

  def terms
    set_meta_tags(
      title: "Terms of Service",
      canonical: terms_url,
      og: { url: terms_url }
    )
  end
end
