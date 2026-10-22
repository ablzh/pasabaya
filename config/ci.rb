# Run using bin/ci

# Keep test concurrency consistent across developer machines and GitHub runners.
ENV["PARALLEL_WORKERS"] ||= "4"

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Lint: Templates", "bin/herb lint app/views app/components"

  step "Consistency: Database", "bin/database_consistency"
  step "Architecture: ArchSpec", "bundle exec archspec check"
  step "Packaging: Docker context", "bin/check-docker-context"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Tests: Rails", "env RAILS_ENV=test bin/rails db:test:prepare test"
  step "Tests: System", "env RAILS_ENV=test bin/rails db:test:prepare test:system"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
end
