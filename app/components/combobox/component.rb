# frozen_string_literal: true

module Combobox
  class Component < ViewComponent::Base
    def initialize(name:, id:, grouped_options:, selected: nil, placeholder: "Select a city...")
      super()
      @name = name
      @id = id
      @grouped_options = grouped_options
      @selected = selected
      @placeholder = placeholder
    end
  end
end
