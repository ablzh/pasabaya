# frozen_string_literal: true

class RouteSubscriptionsController < ApplicationController
  before_action :require_authentication
  rate_limit to: 20, within: 10.minutes, name: "account", only: :create,
    by: -> { Current.user.id }, with: :reject_rate_limited_request

  def create
    @subscription = Current.user.route_subscriptions.find_or_create_by(
      origin_id: route_subscription_params[:origin_id],
      destination_id: route_subscription_params[:destination_id],
      departure_date: route_subscription_params[:departure_date].presence,
      community_id: route_subscription_params[:community_id].presence,
      ladies_only: ActiveModel::Type::Boolean.new.cast(route_subscription_params[:ladies_only]) || false,
      status: :active
    )

    if @subscription.persisted?
      redirect_back fallback_location: ride_posts_path, notice: "You will be notified when a matching ride is posted.", status: :see_other
    else
      redirect_back fallback_location: ride_posts_path, alert: model_error_feedback(@subscription, title: "Your route alert wasn’t created. Check the cities and departure date in your search."), status: :see_other
    end
  end

  def destroy
    @subscription = Current.user.route_subscriptions.find(params[:id])
    @subscription.cancel!

    redirect_back fallback_location: ride_posts_path, notice: "Route alert canceled.", status: :see_other
  end

  private

  def route_subscription_params
    params.expect(route_subscription: [ :origin_id, :destination_id, :departure_date, :community_id, :ladies_only ])
  end
end
