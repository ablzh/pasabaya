class PagesController < ApplicationController
  allow_unauthenticated_access only: %i[ home privacy ]
  def home
    @subscriber = Subscriber.new
  end

  def privacy
  end
end
