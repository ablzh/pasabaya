class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[ home privacy terms ]
  def home
  end

  def privacy
  end

  def terms
  end
end
