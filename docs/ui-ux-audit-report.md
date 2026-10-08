# Pasabaya UI/UX audit — October 7, 2026

**Remediation update:** see [UI/UX fixes and verification](ui-ux-fixes.md) for the subsequent uncommitted changes. The findings and coverage below describe the original audit, before those fixes.

**Result: 14 confirmed defects (6 P1, 8 P2). The application does not pass the UI/UX acceptance criteria.**

This report covers the browser tests actually performed. It does **not** claim that every combination in the testing plan has passed. [Coverage](qa/ui-ux-audit-2026-10-07/coverage.md) records the tested scope and remaining checks for all 60 scenario IDs: **19 FAIL, 38 PARTIAL, 3 BLOCKED**. Physical-device keyboard testing, independent simultaneous account sessions, network fault injection, and consequential account operations remain unverified.

## Environment and method

- Target: `http://127.0.0.1:3000`, local development.
- Browser: connected Codex in-app browser. Safari is excluded at the user's request. No additional browser engine is included in the results.
- Revision: `4b1e1a5f46aad9c6a129b06e09368de4bb2e5f4a`, plus the existing uncommitted remediation changes. No application code was changed during this audit.
- Prepared six ordinary QA accounts, tagged trips, a long conversation, a test Hub, and one synthetic incident. The existing demo administrator was used. Existing records were not reset. [Fixture manifest](qa/ui-ux-audit-2026-10-07/fixture-manifest.json) identifies the records; credentials and verification tokens are omitted.
- Mail delivery was verified as local files. UI actions included publishing, requesting/accepting/declining/canceling bookings, sending chat messages, subscribing/canceling route alerts, legacy mailing-list unsubscribe, profile updates, avatar uploads, Hub verification/resend/leave, reviewing a trip, and moderating the synthetic incident.
- Rare lifecycle states were prepared directly in development. Their screenshots verify rendering, not the transitions that created those states.
- Main responsive captures use 320 × 568, 390 × 844, and 1440 × 900. Additional geometry checks cover 360 × 800, 430 × 932, 768 × 1024, 1024 × 768, and 1280 × 800 on search, create, settings, and profile. Chat also received the wider matrix and a 390 × 420 short-height check.
- Measurements use the **actual** rendered viewport and scrollbar gutter. Some captures requested as mobile rendered at desktop dimensions; those are excluded from mobile coverage. Admin captures remained light and are not counted as dark-mode checks. See the [capture index](qa/ui-ux-audit-2026-10-07/capture-index.csv).
- [Raw observations](qa/ui-ux-audit-2026-10-07/observations.json) retain measurements and action results. Screenshots are evidence, not automatic PASS results. Representative defect images were visually inspected; the entire screenshot archive has not received a pixel-by-pixel review.

The `docs/qa/` evidence directory is intentionally ignored by the repository. This report is outside that directory so its conclusions can be reviewed in Git; the linked evidence remains available locally.

## Confirmed defects

| ID | Priority | Defect | Affected surface |
| --- | --- | --- | --- |
| UX-01 | P1 | Chat bubbles and long author names escape their available width | Chat, mobile and desktop |
| UX-02 | P2 | Template whitespace renders as message content | Chat bubbles |
| UX-03 | P2 | Redundant View controls fragment on narrow notification cards | Notifications |
| UX-04 | P2 | Several mobile actions are smaller than the plan's 44 × 44 px goal | Chat and navigation |
| UX-05 | P2 | Profile names and Hub badges are clipped | Profiles and ride cards |
| UX-06 | P1 | Unbroken trip notes widen the document | Ride details |
| UX-07 | P1 | Long Hub names and mailbox data widen the document | Hub list/detail and membership states |
| UX-08 | P2 | Schedule labels exceed their columns at 320 px | Create/edit forms |
| UX-09 | P2 | Email-update action exceeds its narrow form column | Settings |
| UX-10 | P1 | Unbroken pickup notes widen booking cards and the document | Driver passenger lists |
| UX-11 | P1 | Direct booking page renders a missing-template exception | `/bookings/:id` |
| UX-12 | P1 | Invalid avatar upload crashes the validation response | Settings |
| UX-13 | P2 | Long notification actor names hide the rest of the message | Notifications |
| UX-14 | P2 | Light-mode chat timestamps have insufficient contrast | Chat |

### UX-01 — Chat content escapes the bubble's available width

**Reproduce:** sign in as the QA driver, open `/rides/6-manila-to-baguio?tab=chat`, use a 320 or 390 px viewport, and inspect the incoming 1000-character token and outgoing long URL. Also reproduce with the existing demo conversation's long token.

The incoming bubble measured **9317 px** inside a **232 px** content wrapper at 320 px. The outgoing URL bubble measured approximately **5572 px** and extended left to **−5283 px**. A normal document-width assertion can pass while outgoing text is clipped off the left edge. Long incoming author names also exceed their row.

**Acceptance:** the complete message wraps inside its own/incoming bubble; every bubble and author row stays within the conversation; reading text requires no horizontal scrolling. Test initial rendering and live insertion separately, including both alignments. Do not treat `overflow: hidden` as a fix.

**Regression:** assert bubble bounds against the available wrapper, including negative left coordinates, with a 1000-character token and long URL on mobile and desktop.

Evidence: [mobile](qa/ui-ux-audit-2026-10-07/evidence/qa-chat-320-light.jpg), [desktop](qa/ui-ux-audit-2026-10-07/evidence/chat-1440-light-full.jpg); exact geometry in observations.

### UX-02 — Technical whitespace increases bubble height

**Reproduce:** inspect a plain `Hello!` in the demo or QA conversation. Rendered text includes leading/trailing newlines and indentation from the template while its CSS preserves whitespace. The short-message bubble is approximately 90 px tall.

**Acceptance:** render only the user's message content inside the whitespace-preserving element. Preserve intentional user newlines, emoji, quotes, and markup-like text. Verify a one-character message, `Hello!`, and several user paragraphs.

**Regression:** compare exact rendered text to the stored message and check short-message geometry without hard-coding a height for every content type.

Evidence: [existing conversation](qa/ui-ux-audit-2026-10-07/evidence/chat-390-light-before.jpg).

### UX-03 — Notification View is redundant and malformed

**Reproduce:** open notifications at 320 px. The visible inline View element measures approximately 41 × 51 px and produces a fragmented background. The row is already clickable through the same link's full-card hit area.

**Acceptance:** remove visible View as requested by the user. Keep one semantic link per card with a useful accessible name, visible keyboard focus, correct destination, and read marking. Verify text, icon, timestamp, empty space, and Enter activation.

**Regression:** assert no visible View text, one navigation focus stop per card, full-card activation, and unread-state update.

Evidence: [notification layout](qa/ui-ux-audit-2026-10-07/evidence/notifications-driver-320-light-settled.jpg).

### UX-04 — Mobile hit areas are too small

**Reproduce:** measure chat Send, Back, and navbar controls at a mobile viewport. Send is approximately 82 × 36 px; Back is approximately 30 × 40 px. Navbar actions are also shorter than 44 px.

**Acceptance:** provide a hit area of at least 44 × 44 CSS px for the primary mobile actions, with adequate separation. Include the actual clickable area, not just the icon.

**Regression:** measure interactive rectangles for these controls at 320/390 px and with short-height chat open.

Evidence: control rectangles in observations and chat screenshots above.

### UX-05 — Names and Hub identity are clipped

**Reproduce:** open `/users/5` at 390 px. The valid name `QA Driver With A Long Display Name Audit` loses its beginning and end inside the card. The long Hub badge is also clipped. Related clipping occurs in ride cards and the `/trips` profile destination.

**Acceptance:** wrap full identity text on detail/profile surfaces. Preview truncation is acceptable only where a clear action exposes the full information. Constrain flex/grid children without hiding important text.

**Regression:** use a realistic long name with spaces and a long Hub name; check text bounds within the identity card, not just document overflow.

Evidence: [mobile profile](qa/ui-ux-audit-2026-10-07/evidence/qa-profile-390-final.jpg).

### UX-06 — Trip notes expand the page

**Reproduce:** open `/rides/17-manila-to-baguio` containing a valid note under 300 characters with an unbroken token. Document scroll width reaches **2330 px** at a 320 px viewport and approximately **2586 px** at desktop width.

**Acceptance:** retain and wrap the full note within the detail card, including paragraphs, long URLs, and tokens. Contain its ancestors as well as the text element.

**Regression:** use an unbroken valid note at 320/390/1440 px and assert both document and local content bounds.

Evidence: [ride detail](qa/ui-ux-audit-2026-10-07/evidence/qa-driver-long-notes-detail-320-light.jpg).

### UX-07 — Hub content expands the page

**Reproduce:** open `/communities/uxqa-20261007` as a verified member with a long institutional mailbox. Document width reaches **1259 px** at a 320 px viewport. A final guest check also measured 1259 px at an actual 390 px viewport. The Hub list also expands; nonmember and pending states have additional overflow in their header and explanatory content.

**Acceptance:** Hub name, domain, mailbox, badges, form, and actions stay inside the viewport in nonmember, pending, and verified states. Full mailbox information remains readable.

**Regression:** cover all three membership states and the Hub list using long but valid data; check actual viewport dimensions before accepting evidence.

Evidence: [verified Hub](qa/ui-ux-audit-2026-10-07/evidence/qa-driver-hub-verified-320-light.jpg). Captures of nonmember/pending states with a desktop actual viewport are desktop evidence only.

### UX-08 — Schedule labels still exceed their column

**Reproduce:** open create or edit at 320 px with a 15 px scrollbar gutter. Afternoon text measures approximately **81 px** inside a **70–73 px** text column. The earlier automated viewport checks did not catch this configuration.

**Acceptance:** all six schedule choices remain readable without collision, clipping, or widening; retain usable radio hit areas with validation messages present.

**Regression:** test the rendered content width with the scrollbar gutter, long labels, and error state. Check text-column bounds independently of the outer option card.

Evidence: [create](qa/ui-ux-audit-2026-10-07/evidence/qa-driver-new-ride-320-light.jpg), [edit](qa/ui-ux-audit-2026-10-07/evidence/qa-driver-edit-ride-320-light.jpg).

### UX-09 — Settings action exceeds the narrow form

**Reproduce:** open settings at 320 px. Update Email Address exceeds its available form column by approximately **6 px**. Single-line input scrolling itself is not classified as a bug.

**Acceptance:** the action fits its form with readable text and a usable hit area at the minimum viewport, including error and long-email states.

**Regression:** assert the button's bounds against its own form column with the scrollbar gutter present.

Evidence: [settings](qa/ui-ux-audit-2026-10-07/evidence/qa-driver-settings-320-light.jpg).

### UX-10 — Pickup notes expand passenger lists

**Reproduce:** open `/rides/8-manila-to-baguio` as its driver. A valid pickup note containing an unbroken repeated token expands the document to approximately **837 px** at mobile widths. Desktop can avoid document overflow while the note still exceeds its card.

**Acceptance:** pickup notes wrap inside pending and confirmed passenger cards; Accept/Decline/Cancel Seat remain visible and usable.

**Regression:** check local and document bounds for long pickup notes in both booking states and both themes.

Evidence: [confirmed passenger](qa/ui-ux-audit-2026-10-07/evidence/qa-driver-full-320-light.jpg).

### UX-11 — Direct booking page is broken

**Reproduce:** as the QA passenger owning booking 4, open `/bookings/4`. The development response says `BookingsController#show is missing a template for request formats: text/html`. The endpoint has a show action but no HTML view or successful redirect for its authorized owner.

**Acceptance:** an authorized passenger or driver reaches an intentional booking view or the corresponding trip. An unrelated user receives a useful access-denied response without exposing the booking.

**Regression:** request the endpoint as passenger, driver, unrelated user, and guest; assert the intended response/destination rather than merely a nonempty body.

Evidence: [missing template](qa/ui-ux-audit-2026-10-07/evidence/qa-booking-direct-missing-template.jpg).

### UX-12 — Invalid avatar crashes settings

**Reproduce:** as the QA newcomer, choose a harmless `text/plain` file through Upload Avatar and submit Save Profile Changes. Rendering the validation response tries to generate an image variant for the invalid attachment and raises `ActiveStorage::InvariableError`.

Reloading settings recovers because the invalid avatar was not persisted. A valid wide PNG previews as an 80 × 80 cropped image and saves successfully.

**Acceptance:** unsupported files produce a clear inline error without a 500 response, broken preview, or loss of other valid profile input. Retain the existing valid avatar on failure.

**Regression:** submit a nonimage avatar alongside valid profile fields and verify the rendered validation response and preserved avatar. Include a corrupt image, not only a file-extension check.

Evidence: [upload exception](qa/ui-ux-audit-2026-10-07/evidence/qa-invalid-avatar-crash.jpg).

### UX-13 — Long notification names hide event text

**Reproduce:** open QA passenger notifications containing the long actor name. The name and message overflow the row's available content width: approximately **1044 px** of internal scroll width inside a **239 px** mobile row. The outer card clips the rest of the sentence, so the event becomes difficult to understand.

**Acceptance:** actor and event text wrap, preserving the event and destination context; the card and its link remain constrained. Fixing View alone must not leave this overflow.

**Regression:** requested/canceled notifications with a long actor name in read/unread states, on mobile and desktop.

Evidence: [long notification list](qa/ui-ux-audit-2026-10-07/evidence/qa-passenger-notifications-320-light.jpg).

### UX-14 — Chat timestamps fail the plan's contrast threshold

**Reproduce:** in light chat, timestamps use 10 px text with computed color `oklch(0.708 0 none)` against a nearly white background. Even against pure white, its neutral luminance yields only approximately **2.59:1** contrast, below the plan's **4.5:1** ordinary-text threshold. Compositing the slightly darker background does not improve it.

**Acceptance:** timestamp text meets the plan's contrast threshold in both themes while remaining visually secondary.

**Regression:** measure computed foreground/background contrast, including ancestor background composition and opacity; review readability at mobile size.

Evidence: `contrast_samples` in observations and [live chat](qa/ui-ux-audit-2026-10-07/evidence/qa-live-chat-after.jpg).

## Behaviors verified within the tested scope

- Successful regular/admin login; wrong credentials give an error; contextual Login to Request Seat returns to the intended trip.
- Blank publication reports required fields. A corrected form publishes a new trip. An incomplete draft saves privately. Invalid notes and arrival-before-departure errors preserve input. The seat decrement stops at one.
- Passenger request, driver acceptance, driver decline, pending cancellation, accepted cancellation, request closure, and trip cancellation change their visible states. Acceptance reduces capacity; cancellation restores it. Confirmation dismissal is not claimed verified: the automation did not expose a reliable dialog for these actions.
- Accepted passengers access chat; pending/canceled-seat passengers cannot reopen it through `?tab=chat`. Prepared read-only/expired states were inspected separately.
- Send and Enter submit normal messages. Whitespace-only input returns an error. A server-boundary probe of 1001 characters returns an error and retains the input. The composer is single-line; entering multiline content removes line breaks, which is a product limitation rather than a confirmed rendering bug.
- In two tabs sharing the QA driver session, actual UI sends appear once without reload. A receiver reading older history retains scrollTop 0; a receiver at the bottom follows the new message. Driver/passenger alignment was checked in sequential sessions. Separate-role simultaneous sessions and reconnect remain unverified.
- Deadlines support Space; expanding them preserves older-history position or follows the latest message. At 390 × 420, composer and message area remain present. This is a short-height check, not a physical keyboard test.
- Notification text/Enter navigation reaches the intended trip. Read marking and mark-all-read update unread markers and badge. Superseded incident notifications explicitly identify the current replacement outcome.
- Route-alert subscribe/cancel persists correctly. Repeated scoped QA subscription actions show the rate-limit notice while preserving the page.
- Profile validation, profile name/gender save, valid avatar upload, and wrong-current-password email validation work. Appearance selection persists and menu Enter/Escape works.
- Hub wrong-domain validation, pending state, resend, local-email verification, and leaving the synthetic membership work.
- Passenger smooth-trip review saves. Admin no-result filters, required reason, decision save, corrected decision, and both history entries work on the synthetic incident. Regular users receive 403.
- Password reset delivers a local email; a valid token opens the form and an invalid token returns a clear error. No new password was entered.

## Additional observations and limits

- The legacy mailing-list unsubscribe link was tested on a dedicated QA record: initial and repeated visits show success, and the Homepage action returns correctly. This is separate from account route alerts; the original PUB-03 wording conflates them. Invalid/expired legacy links remain unverified.
- A conversation with more than 100 records displays only its last 100, with no older-history loading control observed. Clarify whether this is intended; users currently receive no explanation of the limit. This is not included in the 14 confirmed implementation defects.
- Wrong-domain Hub validation clears the entered email. It should ideally preserve it for correction.
- The regular-user admin response is an empty 403 (`head :forbidden`). The connected browser displays its own load error. Authorization works; a product error page would provide a clearer explanation and recovery path.
- A separate Rails runner's chat broadcast cannot reach the dev server because development uses the process-local `async` cable adapter. That attempt is not a realtime failure; the later actual two-tab UI send is the relevant receiver test.
- Independent authenticated browser contexts and offline/throttle controls are not exposed by the connected browser API. No claim is made about two different accounts connected simultaneously, slow/offline retries, or reconnect.
- No physical iOS/Android device or screen-reader pass was performed. Browser viewport sizes do not emulate a real software keyboard, browser bars, or safe-area changes.
- Registration consent, new credential entry, final email/password changes, and irreversible deletion are not completed. The computer-use policy requires action-time consent or a user handoff for those actions. Existing test credentials were used only for login.

### What the existing keyboard handling does

The existing chat controller listens to `visualViewport` resize/scroll and uses the visible viewport height/offset to size the mobile conversation. CSS keeps the composer in the chat layout and adds safe-area padding. The earlier remediation also preserves message scroll position while opening deadlines. This handles layout around keyboard-driven viewport changes; it does not alter the keyboard itself. Physical-device behavior remains unverified.

## Repository verification

`mise exec -- bin/ci` **passed** in 2m36s:

- 563 Rails tests, 2865 assertions; zero failures/errors/skips.
- 46 system tests, 2697 assertions; zero failures/errors/skips.
- Setup, Ruby style, security audits, and seed checks passed.

These gates cover the existing test suite. They do not invalidate the live UI findings or turn incomplete manual scenarios into PASS results. No fixes were implemented, committed, or deployed during this audit.

## Recommended remediation order

1. Fix UX-01/06/07/10 with local containment and wrapping across chat, notes, identity, and Hub components. Test negative bubble coordinates and clipped cards, not only document width.
2. Fix the broken booking endpoint and invalid-avatar validation response (UX-11/12).
3. Remove notification View and repair event-text wrapping (UX-03/13).
4. Repair profile identity, schedule/settings geometry, hit areas, template whitespace, and timestamp contrast (UX-02/04/05/08/09/14).
5. Retest the failing cases, then finish the remaining device, independent-session, network, and human-operated account scenarios in the coverage matrix.
