# 10: Record registration self-attestation

**What to build:** New users explicitly confirm that they are at least 18 and accept the Terms of Service and Privacy Policy, with acceptance recorded by the app.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] The required checkbox reads I confirm that I am at least 18 years old and agree to the Terms of Service and Privacy Policy, with working links to both policies.
- [x] The server rejects omitted or false acceptance, including requests that bypass browser validation, with: You must be at least 18 years old and agree to the Terms of Service and Privacy Policy to register.
- [x] Store the acceptance timestamp and the applicable policy version for successful new registrations; neither value is trusted from client-supplied timestamps or version strings.
- [x] Treat this as self-attestation, without collecting a birth date or adding identity/age verification.
- [x] Existing users are not forced to reaffirm, and normal profile updates do not require a registration-only checkbox.
- [x] Failed registrations preserve useful form input and display the acceptance error.
- [x] Add the smallest relevant behavior or regression test for code changes, covering this ticket's user-visible behavior and important failure boundary. Do not require a browser test for changes with no browser behavior.
- [x] Run bin/ci before declaring the implementation complete; report any check that could not run rather than calling the gate green.



## Implementation evidence

Implementation commit 31c59c9 integrated at d2c24db. Server rejects missing/false acceptance and records trusted time and policy version on registration only. Targeted tests pass; clean full bin/ci passes (292 Rails tests, 15 system tests, all static/security/seeds checks). No blocked checks.
