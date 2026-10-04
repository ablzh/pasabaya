# 14: Add the chats inbox

**What to build:** Members open a dedicated chats inbox to find their accessible trip conversations and resume a discussion from its latest message preview.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] A dedicated chats destination lists conversations the current user is authorized to access.
- [x] Each entry shows the trip route, latest-message preview and timestamp, with a clear link into the discussion and sensible latest-activity ordering.
- [x] Include currently accessible read-only conversations with an appropriate state label; honor the applicable cancellation and retention rules as those rules evolve.
- [x] Provide a useful empty state for members with no conversations.
- [x] Both inbox queries and direct chat navigation enforce participation and audience access; previews do not leak private messages from inaccessible trips.
- [x] Message activity updates previews and ordering appropriately without producing per-conversation query growth.
- [x] Keep the inbox and existing trip chat text-only; attachment preparation is outside this release.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.




## Implementation evidence

Added /chats inbox endpoint, latest-message preview with batched authorization and community IDs to prevent N+1 queries, Turbo refresh broadcasts for participant inboxes without disclosing private preview content in broadcasts, normal and native navigation links to Chats, and regression coverage for permissions revocation, ordering, and query stability. Passing full bin/ci with 323 Rails tests and 17 system tests.
