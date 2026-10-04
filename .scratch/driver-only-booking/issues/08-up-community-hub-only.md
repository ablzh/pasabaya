# 08: Keep only the UP community hub

**What to build:** Hub discovery presents the University of the Philippines community, explains Pasabaya's independence, and directs suggestions to the existing support channel.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] Retain only University of the Philippines, using institutional email domain up.edu.ph. Do not claim that this domain alone verifies Diliman campus affiliation.
- [x] Remove unwanted locally created hubs, including commercial and test hubs, and their disposable local-only associated data safely. This is authorized local cleanup, not a blanket production-data deletion.
- [x] Seed replay recreates the intended UP hub without duplicate hubs or reintroducing removed organizations.
- [x] Show: Pasabaya is an independent community platform and is not officially affiliated with, endorsed by, or partnered with any listed university or institution. Hubs are community-led spaces verified via institutional email domains.
- [x] Request a Community Hub opens the existing Pasabaya Facebook support page and explains that users should send the institution name and email domain.
- [x] Keep UP institutional-email verification working, and never silently turn an existing restricted ride into a public ride during cleanup.
- [x] No hub request submission system or retirement workflow is required for these disposable local hubs.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.






## Implementation evidence

Review fix 105f79a restricts transactional cleanup in migration and seeds to development/test, aborting protected ride deletion. Original local development cleanup completed: removed test.edu, accenture.com, ateneo.edu and jpmorgan.com and disposable associated data; only canonical up.edu.ph remains. Database backup: /private/tmp/pasabaya-local-hubs-before-20261004.sqlite3. Production data untouched.

Final integrated review and bin/ci passed at code commit 9c27ee66e6e2742cc536bb60ac5f96e21a9c946f: 424 Rails tests/2026 assertions and 31 system tests/2067 assertions; zero failures, errors or skips. Setup, Ruby style, templates, database consistency, ArchSpec, gem/importmap audits, Brakeman and seed replant all passed. No blocked automated checks. All 178 acceptance criteria are preserved verbatim.
