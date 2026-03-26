class PagesController < ApplicationController
  def home
    @subscriber = Subscriber.new
  end

  def privacy
  end
end
