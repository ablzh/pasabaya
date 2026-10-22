# Agent Guidelines

Read docs/architecture.md for domain rules and boundaries before changing
models, services, or authorization logic.

## Generator-first policy

- If an artifact has a built-in generator, use it instead of hand-writing
  files from scratch. Run `mise exec -- bin/rails g --help` to discover
  available generators. Common ones in this project: `migration`, `model`,
  `job`, `mailer`, `channel`, `stimulus`, `system_test`, and
  `view_component:component`.
- Never hand-create files in `db/migrate/`. Timestamps must come from the
  generator.
- Do not use `scaffold` or `controller` generators for functional changes.
- For services, concerns, and POROs follow existing project conventions in
  the corresponding directories.
- After generating a migration, verify reversibility:
  `mise exec -- bin/rails db:migrate && bin/rails db:rollback && bin/rails db:migrate`.
  If rollback is intentionally impossible, raise
  `ActiveRecord::IrreversibleMigration` in `down`.

## Rails conventions

- Read `Gemfile.lock` for the resolved Rails and gem versions before using
  their APIs. Use APIs supported by those versions and consult matching
  API documentation or installed gem source when unsure.
- Prefer built-in Rails APIs over hand-rolled alternatives or external gems.
- Use `normalizes` for attribute normalization, not `before_validation`
  callbacks. Use `generates_token_for` for expiring tokens, not manual
  token columns. Use `authenticate_by` for credential lookup.
- Consult `Archspec.rb` for enforced component boundaries. Jobs must not
  reference `Current`.

## Turbo Morph safety

- The app uses page-refresh morphing (`turbo_refreshes_with method: :morph`).
  Every interactive element (forms, inputs, containers targeted by
  `turbo_stream`) must have a stable, unique HTML `id` so Idiomorph can
  match nodes correctly.
- Use `data-turbo-permanent` only for elements managed by third-party JS
  (e.g. Tom Select) that cannot survive a morph re-render.

## Verification & Testing

- Use existing coverage first. Add or update the smallest test for current behavior or a credible regression; deletion-only cleanup can rely on the remaining tests.
- Assert outcomes, data, permissions, accessibility, and working interactions. Keep wording, DOM structure, CSS classes, and exact geometry flexible unless they are an explicit requirement.
- Retire tests for removed development-only features and unused imported component variants. Keep absence assertions that protect an active security, privacy, or behavioral contract.
- Use browser tests for browser behavior, with the smallest viewport/theme matrix that exercises distinct behavior.
- Keep manual QA screenshot generation outside normal CI.
- Run `bin/ci` before declaring completion.
- Report any check that could not run rather than calling the gate green.
