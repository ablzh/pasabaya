# Form errors and feedback — implementation and verification

Date: October 8, 2026. Implementation is uncommitted.

## What changed

The password and ride screenshots now use complete corrective sentences rather than Rails attribute fragments. The same message source supplies linked summaries and inline feedback. Summaries focus after rejected submissions, labels remain stable, and invalid controls expose `aria-invalid` and error/help IDs through `aria-describedby`.

Forms supply their input attributes explicitly through `Forms::Component`. City-picker controls and their popup search inputs share the native select’s label/error references. Summary links target the visible picker once it is enhanced. Radio choices use a fieldset and legend; the missing-time correction appears only for Exact Time. The picker’s invalid style sits above its existing control styles so the visible border cannot be overridden.

Settings use separate password-change, email-change, and password-reset validation contexts. Empty credential submissions now fail instead of reporting an unchanged password or missing email as a successful update. Feedback stays in the submitted settings form. Returned HTML never contains password values, and rejected credential forms explain the required re-entry.

Custom validations now supply stable error codes while retaining existing model-level messages for domain/API callers. English presentation translations map those codes to visible field names. Dependent display errors are grouped without removing the underlying business-rule validation: missing seats does not expose a duplicate “Remaining seats” error, and a missing schedule does not point to a hidden time input. Genuine capacity, participation, eligibility, and history restrictions remain visible.

## Error-path inventory

| Surface / trigger | Presentation and recovery |
| --- | --- |
| Settings: wrong current password | “Your current password is incorrect.” below the current password in the submitted form. |
| Settings/reset: mismatched confirmation | “The passwords don’t match. Re-enter your new password.” below confirmation. |
| Empty password/confirmation or new email | Required corrections below the corresponding fields; no success response or credential change. |
| Profile: names, Facebook link, invalid/corrupt/oversized avatar | Profile-only summary, linked inline corrections, retained non-sensitive input and saved avatar. |
| Registration: names/email/password/confirmation/policy acceptance | Shared summary and inline messages; policy error links to the acceptance checkbox. |
| Sign in: rejected credentials | Persistent neutral feedback; entered email retained and password blank on rejection. |
| Password reset: known/unknown email or recipient cooldown | Identical neutral response: “If an account uses this email address, we’ll send password reset instructions. Check your inbox and spam folder.” |
| Expired password, email, or Hub verification link | Persistent explanation with the next step to request a new link. Different-account Hub links explain which account must sign in. |
| Ride: missing route/date/schedule/seats | Actionable visible-field corrections, linked summary, preserved input. |
| Ride: same cities, past date/time, malformed or missing exact time, arrival before departure, seat integer/range, long notes | Complete corrective messages under the relevant controls; stored ride remains unchanged after rejection. |
| Ride: invalid audience/membership or confirmed/historical participation restrictions | Inline audience corrections or persistent form-level business-rule explanation. |
| Ride: incomplete private draft | Supported; publishing alone requires a complete ride. |
| Ride: publish/delete/close/cancel redirect failure | Short outcome/recovery headline and persistent details; no concatenated validation-list toast. |
| Seat request / booking transition failure | Persistent reason and guidance to check the ride, audience, request status, or account restrictions. Permission feedback identifies who may view the request. |
| Chat: blank/long message or closed messaging | Persistent composer feedback. Closed-chat guidance explains that available history can still be read. |
| Hub verification: invalid address/domain/duplicate mailbox | Rejected form renders with the submitted email and linked inline correction. It does not imply a verification email was sent. |
| Route alert: invalid cities/date/duplicate/eligibility | Persistent corrections with guidance to change the search. |
| Account deletion: incorrect password | Error stays in the deletion form; account and session remain intact. Other deletion failures retain support guidance. |
| Admin decision: reason, choice, stale/missing version, save failure | Shared focused summary and inline reason/choice correction. Reason text is preserved; version conflicts still require reviewing the refreshed case. |
| Rate limits on messages/rides/bookings/route alerts/email/Hub verification | Persistent warning names the attempted action, with retry guidance that does not invent a cooldown duration. Chat warning sits beside the composer and preserves its draft. |

## Seat-value discrepancy

The current baseline did not reproduce replacing a rejected empty seat count with 4: the returned field stays empty. The stale-error case was reproduced and covered instead. A valid stepper or manual correction now removes only that field’s inline message, invalid attributes, and matching summary entry. Required, integer/range, length, confirmation, and acceptance corrections are cleared only when their local rules pass; server-only errors remain until server validation runs again. Unrelated errors remain visible. Changing away from Exact Time removes its now-inapplicable time correction.

## Verification

- The two initial request regressions failed on the original screenshot behavior before implementation, then passed with the shared feedback.
- Request regressions cover scoped password/email errors, empty credential rejection, exact-time dependency, arrival/route/seat/note wording, input preservation, incomplete drafts, password-reset privacy, and persistent booking failures.
- Existing profile/avatar, registration, Hub verification, booking, chat deadlines, route-alert, abuse-protection, admin conflict/decision, and ride tests retain their rejection and persistence checks with the new wording.
- Three focused browser tests cover correction/resubmission, visible city-picker and native-input focus, associated error IDs, corrected-only clearing, required radio grouping, persistent server-only errors, visible invalid borders, password blanking, and successful fixture credential updates.
- Ride and password error states each run at **320, 390, and 1440 px**, in **light and dark** themes. Tests assert the actual viewport and theme after the rejected submit, check overflow, and capture complete rendered pages after animations finish.
- Browser sign-in helpers wait for authenticated navigation before checking the URL, avoiding a Turbo navigation timing race.
- Final `bin/ci`: **passed** in 1m13.44s. **577 Rails tests / 2,990 assertions** and **58 system tests / 4,617 assertions**, with zero failures, errors, or skips. Setup, Ruby style, template lint, database consistency, architecture, all security checks, and seed checks passed.

## Screenshots and practical limits

The two original “before” screenshots are in the user’s request; their original local paths are no longer available. The initial failing regressions also establish the before behavior. Twelve new “after” captures are saved locally under the ignored QA directory:

- `docs/qa/form-feedback-ride-{320,390,1440}-{light,dark}.png`
- `docs/qa/form-feedback-password-{320,390,1440}-{light,dark}.png`

Representative captures were visually inspected. Browser verification uses the isolated Chromium test server and fixture accounts; it does not change live credentials or use Safari. Physical-device keyboard behavior and spoken screen-reader announcements were not manually rechecked in this form-specific task. Existing unrelated local files remain untouched. No commits or deployment were performed.
