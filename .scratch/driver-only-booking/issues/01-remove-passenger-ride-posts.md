# 01: Remove passenger ride posts

**What to build:** People browse and publish driver offers only. Passengers continue requesting seats on driver offers; they no longer create separate passenger ride posts.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] Passenger-request ride posts, their search tabs and offering/requesting card badges are removed from the user experience; driver offers remain searchable and bookable.
- [x] Forms, accepted parameters, validations, database rules, sample data and product documentation consistently support driver offers only.
- [x] Preserve positive offered-seat totals and inventory constraints, including valid sold-out rides and protection against negative or excessive remaining inventory.
- [x] The supplied production assumption is that no passenger-request ride posts exist. Stop any destructive migration if unexpected passenger-request records are present rather than relabeling or deleting them silently.
- [x] Seeds remain repeatable and no longer create passenger-request ride posts. Passenger accounts and seat requests remain supported.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.




## Implementation evidence

Restricted ride posts to driver offers only with database check constraint and schema default. Verified migration halts on legacy passenger posts. Eager-loaded avatars to eliminate N+1. Passing full bin/ci with 312 Rails tests and 15 system tests.
