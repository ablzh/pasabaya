# 08: Keep only the UP community hub

**What to build:** Hub discovery presents the University of the Philippines community, explains Pasabaya's independence, and directs suggestions to the existing support channel.

**Blocked by:** None (can start immediately).

**Status:** in-progress

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

Final review found cleanup migration and seeds need production protection; regression fix underway.
