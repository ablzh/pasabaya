class SitemapsController < ApplicationController
  allow_unauthenticated_access only: :show

  def show
    @static_pages = [ root_url, privacy_url, terms_url ]

    active_rides = RidePost.active.includes(:origin, :destination)
    @ride_posts = active_rides.select { |r| r.origin.present? && r.destination.present? }

    location_pairs = active_rides.pluck(:origin_id, :destination_id).uniq
    location_ids = location_pairs.flatten.uniq
    locations_by_id = Location.where(id: location_ids).index_by(&:id)

    @routes = location_pairs.filter_map do |origin_id, destination_id|
      origin = locations_by_id[origin_id]
      destination = locations_by_id[destination_id]
      next unless origin&.slug.present? && destination&.slug.present?

      route_rides_url(origin_slug: origin.slug, destination_slug: destination.slug)
    end.uniq

    respond_to do |format|
      format.xml
    end
  end
end
