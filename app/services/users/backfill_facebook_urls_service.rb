# frozen_string_literal: true

require "uri"
require "json"
require "fileutils"

module Users
  class BackfillFacebookUrlsService
    ALLOWED_HOSTS = %w[facebook.com www.facebook.com m.facebook.com].freeze

    Result = Struct.new(:counts, :records, :backup, :backup_path, :dry_run, keyword_init: true)

    def self.run(...)
      new(...).run
    end

    def self.restore!(backup_data)
      data = backup_data.is_a?(String) ? JSON.parse(File.read(backup_data)) : backup_data
      User.transaction do
        data.each do |user_id, original_url|
          User.where(id: user_id).update_all(facebook_profile_url: original_url)
        end
      end
    end

    def initialize(dry_run: true, batch_size: 100, backup_dir: nil, force_production: false)
      @dry_run = dry_run
      @batch_size = batch_size
      @backup_dir = backup_dir || Rails.root.join("tmp")
      @force_production = force_production
    end

    def run
      if Rails.env.production? && !@force_production
        raise "Do not run this cleanup against production."
      end

      counts = { unchanged: 0, repairable: 0, unrepairable: 0, total: 0 }
      backup = {}
      updates_to_apply = []

      User.find_in_batches(batch_size: @batch_size) do |batch|
        batch.each do |user|
          counts[:total] += 1
          raw = user.facebook_profile_url
          status, cleaned = classify_and_clean(raw)

          counts[status] += 1

          if status != :unchanged
            backup[user.id] = raw
            updates_to_apply << [ user.id, cleaned ]
          end
        end
      end

      backup_path = nil
      unless @dry_run
        if backup.any?
          FileUtils.mkdir_p(@backup_dir)
          timestamp = Time.current.strftime("%Y%m%d%H%M%S")
          backup_path = File.join(@backup_dir, "facebook_profile_urls_backup_#{timestamp}.json")
          File.write(backup_path, JSON.pretty_generate(backup))

          updates_to_apply.each_slice(@batch_size) do |slice|
            User.transaction do
              slice.each do |user_id, cleaned_url|
                User.where(id: user_id).update_all(facebook_profile_url: cleaned_url)
              end
            end
          end
        end
      end

      Result.new(
        counts: counts,
        records: updates_to_apply,
        backup: backup,
        backup_path: backup_path,
        dry_run: @dry_run
      )
    end

    def classify_and_clean(raw_url)
      return [ :unchanged, nil ] if raw_url.nil?
      return [ :unchanged, nil ] if raw_url == ""

      trimmed = raw_url.strip
      return [ :unrepairable, nil ] if trimmed.empty?

      uri = begin
        URI.parse(trimmed)
      rescue URI::InvalidURIError
        nil
      end

      return [ :unrepairable, nil ] unless uri.is_a?(URI::Generic)
      return [ :unrepairable, nil ] unless %w[http https].include?(uri.scheme&.downcase)
      return [ :unrepairable, nil ] if uri.userinfo.present?
      return [ :unrepairable, nil ] unless ALLOWED_HOSTS.include?(uri.host&.downcase)
      return [ :unrepairable, nil ] if uri.path.blank? || uri.path == "/"

      if uri.scheme == "https"
        return [ :unrepairable, nil ] if uri.port != 443

        if safe_url?(trimmed)
          if trimmed == raw_url
            [ :unchanged, trimmed ]
          else
            [ :repairable, trimmed ]
          end
        else
          [ :unrepairable, nil ]
        end
      elsif uri.scheme == "http"
        return [ :unrepairable, nil ] if uri.port != 80

        uri.scheme = "https"
        candidate = uri.to_s
        if safe_url?(candidate)
          [ :repairable, candidate ]
        else
          [ :unrepairable, nil ]
        end
      else
        [ :unrepairable, nil ]
      end
    rescue StandardError
      [ :unrepairable, nil ]
    end

    private

    def safe_url?(url)
      User.new(facebook_profile_url: url).safe_facebook_profile_url?
    end
  end
end
