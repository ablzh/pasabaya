class SitemapsController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    @static_pages = [ root_url, privacy_url, terms_url ]

    @ride_posts = RidePost.active.includes(:origin, :destination)

    @routes = RidePost.active
                      .group(:origin_id, :destination_id)
                      .includes(:origin, :destination)
                      .map { |ride| route_rides_url(origin_slug: ride.origin.slug, destination_slug: ride.destination.slug) }
                      .uniq

    respond_to do |format|
      format.xml
    end
  end
end