# Form errors and feedback remediation plan

Status: implemented locally; final verification is recorded in [form-errors-and-feedback-verification.md](form-errors-and-feedback-verification.md). Changes remain uncommitted.

## Goal

Make every error explain what happened and what the user can do next, using the same English terminology as the visible fields. Keep errors readable and actionable on mobile, desktop, and in both themes.

The supplied screenshots are the initial acceptance examples: Change Password and Post a Ride. Extend the same behavior to the other forms and error flashes so these screens do not become isolated exceptions.

## 1. Inventory and agree on the wording

Record each message with its trigger, screen, visible field, and recovery action. Cover:

- Profile/avatar, email/password settings, and account deletion failures.
- Sign in, registration, password reset, and verification links.
- Ride creation/editing/publication, bookings, and chat submission.
- Hub membership, route alerts, reviews, and admin forms.
- Permission, expired-link, unavailable-record, rate-limit, and unexpected-save failures.

Use short, complete sentences. Explain an input correction directly; explain an unavailable action with a reason and next step. Avoid internal attribute names, framework prose, all-capital headings, and vague “invalid” messages. Keep authentication/reset responses neutral where revealing account existence would be inappropriate.

Initial copy decisions:

| Current message | Proposed message / placement |
| --- | --- |
| Password challenge is invalid | **Your current password is incorrect.** Under Current password. |
| Password confirmation doesn't match Password | **The passwords don’t match. Re-enter your new password.** Under Confirm new password. |
| 7 errors prohibited this post from being saved | **We couldn’t publish your ride. Check the highlighted fields.** Form summary. |
| Origin can't be blank / can't be blank | **Choose a departure city.** Under Leaving from (City), and linked from the summary. |
| Destination can't be blank | **Choose a destination city.** Under Going to (City). |
| Seats can't be blank | **Enter the number of passenger seats.** Under Available passenger seats. |
| Departure date is required for published ride offers | **Choose a departure date.** Under Departure Date. |
| Departure choice is required for published ride offers | **Choose a departure schedule.** Under the schedule group. |
| Departure time is required for published ride offers | **Enter a departure time.** Under Departure Time, when Exact Time is selected. |
| Remaining seats must be confirmed for published ride offers | Do not expose the internal remaining-seat field. Investigate the cause and associate a real capacity error with Available passenger seats; suppress a duplicate caused solely by a missing seat count. |
| Destination must differ from origin | **Choose a destination different from your departure city.** |
| Expected arrival must be after departure time | **Choose an arrival time after departure.** |
| Notes is too long | **Keep your notes to 300 characters or fewer.** |
| Try again later | State the affected action and retry guidance, for example **Too many sign-in attempts. Please try again in a few minutes.** Use a specific duration only when the server can provide it accurately. |

Password settings summary: **Your password wasn’t changed. Check the highlighted fields.** Email settings summary: **Your email address wasn’t changed. Check the highlighted fields.**

Field labels remain stable when an error appears. Error text and required indicators belong beside/below the relevant control; do not replace the label with a technical error. Helper text should contain useful rules before submission. Only describe password rules actually enforced by the server; do not invent a minimum length.

## 2. Give errors a consistent structure

- Use Rails translations for user-facing attribute names and validation wording. Give custom validation failures stable error codes rather than matching arbitrary strings in templates.
- Add a small shared form-error presentation layer that maps model errors to the visible controls and submitted action. Use the same message source for the summary and inline error.
- Group dependent failures into actionable corrections. Missing schedule must not also instruct the user to complete a hidden exact-time field. Missing capacity must not produce a separate internal remaining-seat instruction.
- Keep business-rule validation intact. A genuine eligibility, accepted-booking capacity, or other form-level failure remains visible with a useful explanation. Do not turn rejected submissions into apparent success.
- Keep errors scoped to the submitted form: a password failure must not highlight the email form’s Current password field. Preserve the existing namespaces and use a separate validation context for each settings form.

## 3. Rebuild form summaries and inline states

- Render a shared summary inside the failing form, above its fields. Use a sentence-case heading and valid list markup; settings currently places list items directly inside a div.
- Link each field-related summary item to the actual visible control. For a schedule/radio group, target the group’s first appropriate option; for a custom city picker, target its visible combobox rather than the hidden select.
- Put a complete corrective message below every invalid field or group. Settings currently omits inline error bindings for the password fields.
- Provide a visible invalid border/state, `aria-invalid`, and stable error IDs included in `aria-describedby`, retaining useful helper-text references. Use a fieldset/legend for grouped choices where appropriate.
- After a failed submit, announce and focus the summary without moving the user unexpectedly to another form. Activating an error link focuses the control and brings its label/error into view.
- Avoid repeated announcements from the summary, inline messages, and toast for the same failed submit. Preserve visible text independently of color.

## 4. Fix value preservation and stale errors

The screenshot shows a seat value of 4 while displaying “can’t be blank.” Reproduce both possible causes before choosing a fix:

1. The server rejected an empty field, but a default or stepper then replaced its visible value on the returned form.
2. The user corrected the value after the failed submit, but the old error remained unchanged.

Preserve the submitted route IDs, date, schedule, seats, notes, and other nonsensitive fields after rejection. Do not overwrite them with defaults during Turbo rendering or controller connection.

When a user corrects an invalid field, update that field’s stale error and the matching summary entry after the relevant local rule passes. Do not clear every error on any keystroke or pretend an asynchronous/server-only check has succeeded. Keep unrelated errors visible; the next submit remains server-validated.

Password values must not be echoed into returned HTML or persisted in the browser. Keep all password fields blank after a server rejection, and make any required re-entry clear. Preserve the saved avatar when an upload fails.

## 5. Separate form validation from transient flashes

- Form validation stays in the form until corrected or resubmitted. A disappearing toast must not be its only explanation.
- Redirected actions use a short outcome plus recovery guidance. Do not concatenate an entire raw `errors.full_messages` list into one long toast.
- Give base/business-rule errors a persistent contextual message when correction is impossible from the current field. Preserve the existing authorization and privacy behavior.
- Keep success, warning, and error treatment consistent across flash banners, alert cards, and toasts. Critical recovery guidance remains available after the transient notification disappears.
- Check long text wrapping, list indentation, icon alignment, dismiss/focus behavior, timing, and stacked messages. Flash feedback must not cover the active field, composer, or final action on mobile.

## 6. Implementation order

1. Build the message inventory and shared error-message/field mapping.
2. Fix Change Password and Change Email: wording, scoped summaries, inline errors, and focus links.
3. Fix Post/Edit/Publish Ride: actionable summaries, dependent-error grouping, schedule targets, and seat value/error consistency. Keep incomplete drafts supported.
4. Apply the same presentation to the remaining forms; rewrite affected redirect/error flashes using the inventory.
5. Recheck success flows, failed submits, correction/resubmit, Turbo navigation, and accessibility behavior. Document any additional defect separately.

Main code seams: `config/locales/en.yml`, `Forms::Component`, settings/ride form templates, custom User/RidePost validations, and the flash/toast producers. Extend the existing components rather than adding a separate error system per screen. The form component must expose error attributes for its supplied input controls; changing the wrapper alone will not connect their accessibility state.

## 7. Tests and acceptance

Write the smallest relevant regression test for each behavior. Start with failing cases from the screenshots:

- Wrong current password plus mismatched confirmation: readable summary and messages under the two correct fields; the other settings forms stay unaffected.
- Empty ride publication: only actionable visible-field corrections; no `Password challenge`, `Remaining seats`, or scaffold “prohibited … saved” text.
- Exact Time selected without a time; a different schedule selected; arrival before departure; identical route cities; missing/invalid seats; notes over 300 characters.
- Failed ride submit followed by stepper/manual correction: entered value and error state agree, unrelated input is retained, and resubmission succeeds when valid.
- Summary links, visible invalid styling, associated error IDs, focus/scroll, and native/custom picker targets.
- Failed email/profile/avatar/reset forms, repeated submits, scoped rate limits, and redirected errors. Preserve generic account-existence responses.
- Long summaries/toasts at 320, 390, and 1440 px, light/dark, including a scrollbar gutter; no horizontal overflow, clipped messages, or overlapping actions.

Use request/model/component tests for validation and wording, plus targeted browser tests for field focus, Turbo rerendering, value preservation, and layout. Credential-change behavior can be verified with isolated automated test fixtures; live new-credential entry remains a human-operated check.

Run `bin/ci` after implementation and fix any failures before declaring completion. Save representative before/after screenshots and an English verification note. Leave all changes uncommitted, as previously requested.

Completion means the examples above are fixed and the inventoried error paths have clear, consistently placed feedback. Implementation was subsequently authorized by the user.
