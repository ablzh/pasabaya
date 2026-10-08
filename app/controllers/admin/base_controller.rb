# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :require_active_admin
    after_action :prevent_admin_caching

    private

    def require_active_admin
      head :forbidden unless Current.user.reload.active_admin?
    end

    def prevent_admin_caching
      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
    end

    def filter_id(records, parameter, column)
      value = @filters[parameter]
      return records if value.blank?

      if value.to_s.match?(/\A[0-9]+\z/) && value.to_i.between?(1, 9_223_372_036_854_775_807)
        Array(column).map { |name| records.where(name => value.to_i) }.reduce(&:or)
      else
        @filter_errors << "#{parameter.to_s.humanize} must be a positive number."
        records
      end
    end

    def filter_dates(records, column)
      dates = %i[from to].to_h do |parameter|
        value = @filters[parameter]
        if value.present?
          raise Date::Error unless value.to_s.match?(/\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/)
          date = Date.iso8601(value.to_s)
        end
        [ parameter, date ]
      rescue Date::Error
        @filter_errors << "#{parameter.to_s.humanize} date must use YYYY-MM-DD."
        [ parameter, nil ]
      end

      if dates[:from] && dates[:to] && dates[:from] > dates[:to]
        @filter_errors << "From date cannot be after To date."
        return records
      end

      records = records.where(column => dates[:from].in_time_zone.beginning_of_day..) if dates[:from]
      records = records.where(column => ...dates[:to].next_day.in_time_zone.beginning_of_day) if dates[:to]
      records
    end
  end
end
