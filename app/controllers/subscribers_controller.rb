# frozen_string_literal: true

class SubscribersController < ApplicationController
  invisible_captcha only: [:create],
                    honeypot: :nickname,
                    timestamp_enabled: true,
                    timestamp_threshold: 2

  def create
    raw_email = subscriber_params[:email].to_s.downcase.strip

    @subscriber = Subscriber.find_or_initialize_by(email: raw_email)

    if @subscriber.persisted? && @subscriber.unsubscribed_at.nil?
      @already_subscribed = true
      flash.now[:notice] = "You're already subscribed! Thank you! No further action needed."
      return respond_to do |format|
        format.turbo_stream { render :create } # This will use the same success view
        format.html { redirect_to root_path, notice: flash[:notice] }
      end
    end

    is_resubscribing = @subscriber.persisted? && @subscriber.unsubscribed_at.present?

    @subscriber.assign_attributes(subscriber_params)
    @subscriber.unsubscribed_at = nil

    if @subscriber.save
      UserMailer.welcome_email(@subscriber).deliver_later

      message = is_resubscribing ?
                  "Welcome back! Your subscription has been reactivated." :
                  "You've successfully subscribed for updates! The email is on its way."

      flash.now[:notice] = message

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to root_path, notice: flash[:notice] }
      end
    else
      render "pages/home", status: :unprocessable_entity
    end
  end

  def unsubscribe
    @subscriber = Subscriber.find_signed(params[:id], purpose: :unsubscribe)
    if @subscriber
      @subscriber.update(unsubscribed_at: Time.current)
      render :unsubscribe_success
    else
      render plain: "Invalid link or already unsubscribed", status: :not_found
    end
  end

  private

  def subscriber_params
    params.require(:subscriber).permit(:name, :email)
  end
end
