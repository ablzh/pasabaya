class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[ home privacy terms ]
  def home
    @grouped_locations = Location.grouped_by_region
  end

  def privacy
  end

  def terms
  end
end
