# frozen_string_literal: true

class AccountDeletionTombstone < ApplicationRecord
  validates :user_id, presence: true, uniqueness: true
  validates :anonymized_email, presence: true
  validates :deleted_at, presence: true

  def enqueue_avatar_purge
    return if avatar_blob_id.nil?

    if (blob = ActiveStorage::Blob.find_by(id: avatar_blob_id))
      blob.purge_later
    else
      # A purge can delete its database row before storage deletion fails.
      if avatar_key.present?
        service = ActiveStorage::Blob.services.fetch(avatar_service_name)
        service.delete(avatar_key)
        service.delete_prefixed("variants/#{avatar_key}/")
      end
      update!(avatar_blob_id: nil, avatar_key: nil, avatar_service_name: nil)
    end
  rescue StandardError => e
    Rails.logger.warn("Avatar cleanup pending for deleted User##{user_id}: #{e.message}")
  end
end
