# Privacy Policy and Terms review — 22 October 2026

Review of the release checkout against the public text and primary sources. This is a factual release review, not legal clearance. The findings below describe the documents as reviewed on 22 October, before the subsequent requested edits to the [Privacy Policy](../app/views/pages/privacy.html.erb) and [Terms](../app/views/pages/terms.html.erb).

## Update prepared on 23 October 2026

The user requested revised text after the review. The policy pages, signup policy
version, homepage announcement, and both release emails now use 23 October 2026,
after the Manila date changed. Previous acceptance records are untouched. The
user confirmed Artem Blazhievskii (GitHub `ablzh`) as operator of this volunteer-run
open-source project, the monitored privacy/legal addresses, Cloudflare R2 backup
storage, and enabled Skylight monitoring. Those facts are included without
inventing a company or hosting location.

The revised pages address the factual findings below. Further review found the
homepage's standard YouTube embed; its network/browser processing and possible
cookies are now disclosed. The optional hub-verification form also explains email
processing and the badge's visibility before requesting a verification link.
Institutional affiliation can reveal sensitive education information under
RA 10173, so verification is discussed under consent rather than generic
contractual necessity. [YouTube's embed guidance](https://support.google.com/youtube/answer/171780?hl=en),
[RA 10173, Sections 3 and 13](https://privacy.gov.ph/data-privacy-act-/).

The actual hosting provider and processing locations remain unverified. The
copy honestly discloses that non-chat records do not have automatic fixed
expiry; this does not establish that indefinite retention is legally justified.
Any necessary fresh consent for existing users and the transport-law and
enforceability questions below remain rollout/legal assessments. Preparing the
text and email templates does not send notices or deploy the application.

## Correct factual mismatches before publishing

1. **Terms chat deadline:** Section 7 says messaging ends 24 hours after departure and messages are purged after 30 days. Actual deadlines depend on booking cutoff, qualifying cancellation, and a further 30-day history window; deletion is asynchronous. Replace that sentence with: “Messaging closes 24 hours after booking cutoff, or 24 hours after cancellation if canceled while messaging is open. Cancellation does not reopen closed messaging or expired history. Authorized participants can read chat for another 30 days after messaging closes; deletion from the live database is then scheduled. Backup copies follow the separate retention schedule in the Privacy Policy.” Privacy Section 5 already substantially matches this behavior. [Deadline implementation](../app/models/ride_post.rb#L273), [retention job](../app/jobs/chat_retention_job.rb), [Privacy Section 7](../app/views/pages/privacy.html.erb#L108).

2. **Collected data and purpose:** Add recurring ride schedules and route subscriptions/alerts. Explain that login session IP addresses and user agents are stored in the database, rather than mentioning only web-server logs. Gender is used for both Ladies Only eligibility and the female-profile badge visible to logged-in members; remove “exclusively” in Section 2, which contradicts Section 4's badge disclosure. [Ride schedules](../app/models/ride_schedule.rb), [route-alert service](../app/services/route_subscriptions/match_service.rb), [session schema](../db/schema.rb#L278), [current collection/visibility descriptions](../app/views/pages/privacy.html.erb#L31).

3. **Analytics:** Replace the absolute “without collecting personally identifiable information” and “non-PII” claims with: “We use cookie-free GoatCounter analytics on selected public pages. We send fixed page identifiers and titles without URL queries or referrers. GoatCounter processes IP addresses and browser headers to calculate statistics and recognize repeat visits; its documented repeat-visit identifier mapping is retained in memory for up to eight hours.” The app's fixed fields do not prevent the recipient from receiving network information. [App integration](../app/javascript/analytics.js), [GoatCounter's own privacy explanation](https://www.goatcounter.com/help/privacy).

4. **Deletion and enforcement:** Remove claims that retained anonymous records prevent re-registration or no-show-strike evasion. Deletion clears the email, ban, and freeze; the deletion registry supports restoration scrubbing, not matching new accounts to deleted identities. Accurate wording: “We retain de-identified historical safety records to preserve incident, trip, and review integrity.” [Anonymization](../app/services/users/anonymize_service.rb#L64), [deletion registry](../app/services/users/deletion_registry.rb), [current claims](../app/views/pages/privacy.html.erb#L46).

5. **Recurring rides in the Terms:** Explain that users choose the schedule, offers without an end date repeat until paused or ended, and every departure still requires driver acceptance of passenger requests. Pausing stops new admission and expires pending requests while honoring accepted participation; ending the series cancels future departures. Users need these distinctions to understand their commitments. The legacy import also publishes recurring offers using reviewed defaults; its personalized notice should clearly explain those defaults and how to stop the offers. [Schedule behavior](../app/models/ride_schedule.rb), [pause/end transitions](../app/services/ride_schedules/transition_service.rb), [legacy rollout](operations.md#legacy-ride-transition).

6. **Technical accuracy:** Describe passwords as bcrypt-hashed, not encrypted. The login session cookie is signed; do not describe every authentication cookie as encrypted. Describe chat sender/trip identifiers and message timestamps without implying stored per-message recipient or delivery receipts. The review model stores outcome categories rather than numeric ratings. [Authentication](../app/controllers/concerns/authentication.rb), [chat model](../app/models/chat_message.rb), [review model](../app/models/trip_review.rb), [current collection description](../app/views/pages/privacy.html.erb#L30).

## Owner facts needed before the notice is complete

- **Controller identity:** “Pasabaya.app” and a privacy email do not identify the actual responsible person or entity. Suggested structure: “Pasabaya is operated by [legal person/entity name], the personal information controller. Contact: [verified contact/address details], privacy@pasabaya.app.” Supply real details rather than publishing placeholders. NPC IRR Section 34(a)(2)(g) requires controller identity/contact details; Section 34(c)(8) addresses controller identity/address access. [Current introduction](../app/views/pages/privacy.html.erb#L17), [NPC IRR](https://privacy.gov.ph/implementing-rules%20regulations-data-privacy-act-2012/).
- **Retention and rights:** State actual periods for session/security records, route subscriptions, schedules, accounts, and moderation records; avoid inventing durations. Add how to withdraw consent and request data portability, including applicable limits and any separate lawful basis for continued processing. IRR Section 34 requires storage-period information; Section 36 establishes portability. [Current retention/rights text](../app/views/pages/privacy.html.erb#L94), [NPC IRR](https://privacy.gov.ph/implementing-rules%20regulations-data-privacy-act-2012/).
- **Providers and assurances:** Skylight is configured; confirm whether production enables it and, if so, disclose its monitoring purpose/data. Verify actual hosting/backup provider identities and locations and the contracts supporting “strict security agreements.” Source configuration alone cannot establish those agreements or production locations. [Skylight configuration](../config/skylight.yml), [provider claims](../app/views/pages/privacy.html.erb#L113).

## Date, announcement, and existing users

Both documents and `User::REGISTRATION_POLICY_VERSION` currently use **3 October 2026**. If the revised terms first become effective with this release, use **22 October 2026** consistently and preserve the previous version. A deployment by itself does not prove an existing policy's effective date must change. [Privacy date](../app/views/pages/privacy.html.erb#L13), [Terms date](../app/views/pages/terms.html.erb#L13), [registration version](../app/models/user.rb#L2).

If the registration version changes, update its hardcoded expectation in the existing test. Preserve historical users' recorded acceptance dates and versions; changing the constant must not rewrite their past acceptance. [Registration acceptance test](../test/controllers/registrations_controller_test.rb#L120).

Privacy Section 11 promises an announcement and email for major handling changes. The existing upgrade email templates have no policy links or explicit legal-change notice. Prepare a concise notice with both links, the effective date, changed processing/visibility/retention, and how to exercise rights; do not treat a generic feature announcement as satisfying that promise. Registration acceptance records do not provide an existing-user update acknowledgment flow. [Policy commitment](../app/views/pages/privacy.html.erb#L146), [HTML upgrade email](../app/views/user_mailer/ride_upgrade.html.erb), [text upgrade email](../app/views/user_mailer/ride_upgrade.text.erb), [registration model](../app/models/user.rb).

Fresh consent is **not automatically required for every wording update**. NPC Circular 2023-04 Section 4(B) says retaking consent is unnecessary when disclosed processing remains the same; Section 21(A) requires new consent when consent-based processing changes considerably. Evaluate the actual old-to-new processing before rollout. A notice, Terms acceptance, and consent to personal-data processing serve distinct purposes. Section 20 also makes privacy-right waivers void. [NPC consent circular](https://privacy.gov.ph/wp-content/uploads/2023/11/NPC-Circular-No.-2023-04_Guidelines-on-Consent_07Nov2023.pdf).

## Transport-law limit

Keep the prohibition on commercial/unauthorized transport, but do not infer that a free platform or expense sharing guarantees an exemption. An official 1 April 2026 government report describes a Metro Manila permit framework and says final guidelines were still expected. This limited search did **not** verify the final issuance or applicability to Pasabaya's arrangements. Confirm the current position with LTFRB/MMDA or Philippine counsel before making exemption claims. Broad liability waivers and indemnities also need local enforceability review; factual corrections cannot establish their validity. [Terms Sections 4–5 and liability provisions](../app/views/pages/terms.html.erb), [official PIA report](https://pia.gov.ph/news/govt-launches-carpooling-program-to-ease-transport-costs/).

## Verification

`mise exec -- bin/ci` passed on 22 October 2026, including 687 Rails tests and 76 browser tests, with no test failures, errors, or skips. All CI gates passed after retrying with the required network, Docker, and local-browser access. This verifies the checkout's technical gate; it does not certify legal compliance or production configuration.

After the requested copy changes, the full gate passed again on 23 October:
688 Rails tests (3,849 assertions) and 76 browser tests (2,315 assertions),
with no failures, errors, or skips. The existing mailer and page coverage now
checks the updated notices, effective version, and material disclosures; one
additional controller test covers the verification/resend privacy notice.
