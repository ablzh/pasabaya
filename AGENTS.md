# Agent Guidelines

## Verification & Testing
- Use existing coverage first. Add or update the smallest test for current behavior or a credible regression; deletion-only cleanup can rely on the remaining tests.
- Assert outcomes, data, permissions, accessibility, and working interactions. Keep wording, DOM structure, CSS classes, and exact geometry flexible unless they are an explicit requirement.
- Retire tests for removed development-only features and unused imported component variants. Keep absence assertions that protect an active security, privacy, or behavioral contract.
- Use browser tests for browser behavior, with the smallest viewport/theme matrix that exercises distinct behavior.
- Keep manual QA screenshot generation outside normal CI.
- Run `bin/ci` before declaring completion.
- Report any check that could not run rather than calling the gate green.
