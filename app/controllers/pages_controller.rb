class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[ home privacy ]
  def home
  end

  def privacy
  end
end
