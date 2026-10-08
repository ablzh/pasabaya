module FormErrorsHelper
  FieldError = Data.define(:text, :rule, :limit) do
    def to_s = text
  end

  def settings_form_error(record, attribute, context)
    form_error(record, attribute) if controller_name == context
  end

  # Presentation aliases match visible fields; domain errors remain on the model.
  def form_error_attribute(record, attribute)
    if record.is_a?(RidePost)
      { origin: :origin_id, destination: :destination_id, departure_time: :exact_departure_time,
        remaining_seats: :seats, community: :community_id }.fetch(attribute, attribute)
    elsif record.is_a?(NoShowIncident)
      { decision_reason: :reason }.fetch(attribute, attribute)
    elsif record.is_a?(TripReview)
      { reported_user: :reported_user_id }.fetch(attribute, attribute)
    else
      attribute
    end
  end

  def form_error_entries(record)
    record.errors.filter_map do |error|
      if record.is_a?(RidePost)
        next if error.attribute == :departure_time && !record.exact_time? && record.errors[:departure_choice].any?
        next if error.attribute == :remaining_seats && record.errors[:seats].any?
      end
      attribute = error.type == :registration_acceptance ? :registration_acceptance : form_error_attribute(record, error.attribute)
      { attribute: attribute, error: present_form_error(record, error) }
    end.uniq { |entry| [ entry[:attribute], entry[:error].to_s ] }
  end

  def form_error(record, attribute)
    entries = form_error_entries(record).select { |entry| entry[:attribute] == attribute }
    return if entries.empty?

    # Clear locally only when every correction for this field is locally verifiable.
    first = entries.first[:error]
    FieldError.new(text: entries.map { |entry| entry[:error].to_s }.join(" "),
      rule: entries.map { |entry| entry[:error].rule }.uniq.one? ? first.rule : nil, limit: first.limit)
  end

  def present_form_error(record, error)
    label = record.class.human_attribute_name(error.attribute)
    options = error.options.except(:message).merge(field: label, detail: error.message, domain: record.try(:community)&.domain)
    text = I18n.t("form_errors.models.#{record.model_name.i18n_key}.#{error.attribute}.#{error.type}",
      **options, default: I18n.t("form_errors.messages.#{error.type}", **options, default: error.full_message))
    rule = { blank: "required", required_for_publication: "required", too_long: "max-length",
      not_a_number: "positive-integer", not_an_integer: "positive-integer", greater_than: "positive-integer", confirmation: "confirmation", registration_acceptance: "accepted" }[error.type]
    rule = nil if error.attribute == :base && error.type != :registration_acceptance
    FieldError.new(text: text, rule: rule, limit: error.options[:count])
  end
end
