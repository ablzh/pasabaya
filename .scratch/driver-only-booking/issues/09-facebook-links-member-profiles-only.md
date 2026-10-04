# 09: Limit Facebook links to member profiles

**What to build:** Signed-in members find a user's Facebook link on that user's profile, with clear visibility guidance when adding the link.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] Remove Facebook buttons and links from ride board cards and ride detail pages.
- [x] A member profile with a configured URL has View Facebook Profile opening in a new tab with appropriate external-link attributes.
- [x] When no URL is configured, show the subtle Facebook profile not linked label.
- [x] Profile access and Facebook URL visibility remain restricted to signed-in users; guests cannot retrieve the URL through the profile.
- [x] Settings explicitly state that a linked Facebook profile is visible to other signed-in members.
- [x] Continue validating acceptable Facebook links and preserving existing profile data.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.





## Implementation evidence

Implementation commit 23c000a integrated at d2c24db. Profile-only external Facebook URL with signed-in authorization, absent-link label and settings visibility copy verified. 25 targeted tests pass; full bin/ci passes all checks (ticket-09-ci.log). No blocked checks.

Final integrated review and bin/ci passed at code commit 9c27ee66e6e2742cc536bb60ac5f96e21a9c946f: 424 Rails tests/2026 assertions and 31 system tests/2067 assertions; zero failures, errors or skips. Setup, Ruby style, templates, database consistency, ArchSpec, gem/importmap audits, Brakeman and seed replant all passed. No blocked automated checks. All 178 acceptance criteria are preserved verbatim.
