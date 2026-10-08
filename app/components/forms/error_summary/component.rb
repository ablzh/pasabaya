module Forms
  module ErrorSummary
    class Component < ViewComponent::Base
      def initialize(record:, form:, title:, targets: {})
        @record = record
        @form = form
        @title = title
        @targets = targets
      end

      def entries
        helpers.form_error_entries(@record)
      end

      def target_for(attribute)
        return @targets[attribute] if @targets.key?(attribute)
        controls = {
          user: %i[first_name last_name avatar facebook_profile_url gender email_address unconfirmed_email password password_confirmation password_challenge registration_acceptance],
          ride_post: %i[origin_id destination_id departure_date exact_departure_time expected_arrival_at seats visibility community_id notes],
          trip_review: %i[reported_user_id outcome notes],
          community_membership: %i[institutional_email],
          chat_message: %i[body]
        }
        return unless controls.fetch(@record.model_name.i18n_key, []).include?(attribute)

        @form.field_id(attribute)
      end

      def render? = @record.errors.any?
    end
  end
end
