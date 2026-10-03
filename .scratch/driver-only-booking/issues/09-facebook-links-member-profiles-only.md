# 09: Limit Facebook links to member profiles

**What to build:** Signed-in members find a user's Facebook link on that user's profile, with clear visibility guidance when adding the link.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Remove Facebook buttons and links from ride board cards and ride detail pages.
- [ ] A member profile with a configured URL has View Facebook Profile opening in a new tab with appropriate external-link attributes.
- [ ] When no URL is configured, show the subtle Facebook profile not linked label.
- [ ] Profile access and Facebook URL visibility remain restricted to signed-in users; guests cannot retrieve the URL through the profile.
- [ ] Settings explicitly state that a linked Facebook profile is visible to other signed-in members.
- [ ] Continue validating acceptable Facebook links and preserving existing profile data.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.

