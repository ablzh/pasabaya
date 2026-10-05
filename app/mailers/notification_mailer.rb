# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  def event_notification
    @notification = params[:notification]
    @recipient = @notification.recipient
    @actor = @notification.actor
    @notifiable = @notification.notifiable
    @event_name = @notification.event_name

    subject = case @event_name
    when "booking.requested"
                "New seat request on Pasabaya"
    when "booking.accepted"
                "Your seat request has been confirmed on Pasabaya"
    when "booking.expired"
                "Your seat request expired on Pasabaya"
    when "booking.canceled"
                "A booking was canceled on Pasabaya"
    when "ride.canceled"
                "Your upcoming ride has been canceled on Pasabaya"
    when "route.alert"
                "New ride offer matching your route alert on Pasabaya"
    when "incident.resolved"
                @notification.incident_decision ? "Decision on a no-show report on Pasabaya" : "Update on your reported incident on Pasabaya"
    else
                "Notification from Pasabaya"
    end

    mail(to: @recipient.email_address, subject: subject)
  end
end
