# frozen_string_literal: true

architecture :rails

component :view_components, in: "app/components/**/*.rb"

view_components.cannot_use :controllers, because: "ViewComponents must not depend on controllers"
jobs.cannot_reference_constants "Current", because: "background jobs must not reference Current for request context"
