# 01: Remove passenger ride posts

**What to build:** People browse and publish driver offers only. Passengers continue requesting seats on driver offers; they no longer create separate passenger ride posts.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Passenger-request ride posts, their search tabs and offering/requesting card badges are removed from the user experience; driver offers remain searchable and bookable.
- [ ] Forms, accepted parameters, validations, database rules, sample data and product documentation consistently support driver offers only.
- [ ] Preserve positive offered-seat totals and inventory constraints, including valid sold-out rides and protection against negative or excessive remaining inventory.
- [ ] The supplied production assumption is that no passenger-request ride posts exist. Stop any destructive migration if unexpected passenger-request records are present rather than relabeling or deleting them silently.
- [ ] Seeds remain repeatable and no longer create passenger-request ride posts. Passenger accounts and seat requests remain supported.
- [ ] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [ ] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.

