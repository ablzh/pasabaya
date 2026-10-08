# UI/UX audit remediation — October 7, 2026

All 14 confirmed findings from the [audit](ui-ux-audit-report.md) have implementation changes and focused regression coverage. Changes remain uncommitted. The audit is a historical record of the failures before this remediation; its full-plan coverage limits still apply.

| Finding | Change | Regression coverage |
| --- | --- | --- |
| UX-01 | Chat flex children have explicit minimum/maximum bounds and wrap unbroken text; avatars cannot shrink. Long author rows wrap. | Initial own/incoming messages at 320/390/1440 px in both themes; live incoming insertion; local bounds, including negative left edges. |
| UX-02 | Message body contains only stored content, with no ERB indentation. User newlines and literal markup remain intact. | Exact rendered text for short, long, multiline and Unicode messages. |
| UX-03 | Removed visible View. Each notification has one semantic link covering the entire card, with keyboard focus. | No View link, single link per card; existing card-click/Enter/read-marking tests. |
| UX-04 | Chat Back/Send and navbar targets are at least 44 px. Mobile navbar spacing accommodates the unread Chats badge. | Actual hit rectangles and document width with a 15 px gutter and unread badge. |
| UX-05 | Profile content, badges and ride-card identity wrap within their available width. | Long realistic name and Hub data; local text/card bounds and live profile screenshot. |
| UX-06 | Trip details wrap valid unbroken notes. | Mobile/desktop local and document bounds. |
| UX-07 | Hub name/domain/mailbox and flex children wrap. Header/actions constrain themselves to their available space. | Verified, pending and nonmember states at 320/390/1440 px; Hub list and live verified detail. |
| UX-08 | Schedule titles can move below their radio when space is insufficient; radios retain their size and all titles remain readable. | Create/edit title and hint bounds with a 15 px scrollbar gutter. |
| UX-09 | Buttons constrain their width and wrap their labels. Settings avatar layout stacks on phones. | Settings submit bounds and live email action width. |
| UX-10 | Passenger identity/pickup notes wrap; avatars/actions retain their space. | Pending and accepted booking notes on mobile/desktop. |
| UX-11 | Authorized booking URLs redirect to the corresponding trip. | Passenger/driver redirects, unrelated-user denial and guest login. |
| UX-12 | Rejected uploads are discarded from the unsaved form model before rendering; the saved avatar remains. New images are decoded to reject corrupt files. Client preview checks type/size/decode before replacing the last valid image. | Multipart and signed direct-upload requests, saved-avatar preservation, corrupt PNG rejection; valid crop and invalid replacement preview. |
| UX-13 | Notification event text wraps inside a constrained column with fixed icon/unread marker. The narrow list header also wraps its Mark All action. | Long actor in both themes at all primary widths; no header overlap. |
| UX-14 | Chat timestamps use readable 12 px text and darker light-mode/lighter dark-mode colors. | Computed foreground/background contrast exceeds 4.5:1 in both themes. |

Regression tests are in `test/system/audit_remediation_test.rb`, `test/controllers/bookings_controller_test.rb`, and `test/controllers/settings/profiles_controller_test.rb`. Existing responsive/navigation tests retain their width checks; the navbar height ceiling now allows 44 px controls plus container padding. Avatar-purge tests now use real PNG fixtures instead of text labelled as PNG.

## Live verification

The connected in-app browser exercised profile, notifications, trip notes, pickup notes, verified Hub, settings, schedule form and chat at 320/390/1440 px in both light and dark modes: **48 checks**, with actual viewport dimensions recorded and no horizontal document overflow. Own/incoming long chat bubbles stayed inside the message list without clipped internal content.

At 320 px, the incoming 1000-character token and outgoing 781-character URL each occupy approximately 232 px bubbles, replacing the audit's 9317/5572 px widths. Send and Back measure 44 px high. At the same viewport, long trip/Hub/pickup content fits the 305 px document content width, including the scrollbar gutter.

Local evidence (intentionally ignored by Git): [primary matrix](qa/ui-ux-audit-2026-10-07/retest/primary-matrix.json), [chat measurements](qa/ui-ux-audit-2026-10-07/retest/chat-320-metrics.json), [profile](qa/ui-ux-audit-2026-10-07/retest/profile-390-final-fixed.jpg), [notifications](qa/ui-ux-audit-2026-10-07/retest/notifications-390-light-fixed.jpg).

## Verification gate

`mise exec -- bin/ci` **passed** in 1m16s. All setup, style, template lint, consistency, architecture, security and seed gates passed.

- 568 Rails tests, 2888 assertions; zero failures/errors/skips.
- 55 system tests, 4459 assertions; zero failures/errors/skips.
- `git diff --check` passed.

## Remaining scope

Physical iOS/Android keyboard behavior, independent simultaneous account sessions, network recovery and a full screen-reader pass remain unverified. The implementation and regression checks above resolve the confirmed defects; they do not establish that every scenario in the original plan is complete.

The chat history limit and product behavior of the single-line composer remain separate product questions. No commits or deployment were performed.
