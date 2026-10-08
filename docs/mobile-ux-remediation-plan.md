# Mobile UX Remediation and Component Standardization

October 7, 2026 - Pasabaya

Status: Implemented and verified. CI passed: 563 Rails tests, 46 browser tests, and all remaining gates.

This revision replaces the incomplete PDF export with explicit file references, corrected scope, and behavior-based acceptance checks. The original audit contained seven mobile findings. Contrast problems discovered alongside that audit are included in this implementation.

## 1. Shared notices and passenger booking card

Targets:
- app/components/alert/component.rb
- app/components/alert/component.html.erb
- app/views/ride_posts/show.html.erb
- app/views/users/show.html.erb
- app/views/settings/profiles/show.html.erb
- app/views/notifications/incident_decision.html.erb
- app/views/communities/show.html.erb

Replace Seat Requested, Seat Confirmed, booking restrictions, Private Draft, profile freeze/reliability notices, pending email and hub verification, and superseded decision notices with Alert::Component. Retain existing wording, Hubs links, resend verification actions, and the decision notice's status semantics. Escape user-controlled values with safe_join and tag helpers when combining text and markup.

Wrap passenger booking content in Card::Component. Put full-width flex alignment inside its body wrapper so notices and action groups remain centered. Allow the confirmed-booking buttons to wrap at narrow widths. Keep long alert titles and descriptions inside their grid column with minmax(0, 1fr) and word wrapping.

Acceptance: all five alert variants' title and description text reach at least 4.5:1 contrast in light and dark themes; long email-like strings do not overflow; pending and accepted booking actions remain centered at 320px and 1440px; driver names cannot inject links into descriptions.

Verification:
```sh
mise exec -- bin/rails test test/components/alert/component_test.rb
mise exec -- bin/rails test test/controllers/ride_posts_controller_test.rb
mise exec -- bin/rails test test/controllers/notifications_controller_test.rb
```
Browser coverage: test/system/ui_components_test.rb and test/system/mobile_ux_remediation_test.rb.

```sh
mise exec -- bin/rails test test/system/ui_components_test.rb
mise exec -- bin/rails test test/system/mobile_ux_remediation_test.rb
```

## 2. Compact chat deadline disclosure

Targets:
- app/views/ride_posts/_chat_deadlines.html.erb
- app/views/ride_posts/show.html.erb
- app/javascript/controllers/chat_scroll_controller.js
- app/assets/tailwind/application.css

Use one native details/summary disclosure on desktop and mobile. The collapsed summary shows a short messaging deadline in Philippine time. Expanded details retain both full dates, machine-readable time elements, the UTC+8 explanation, and the distinction between booking-cutoff and cancellation-based deadlines.

Keep the live cancellation/coordination status outside the disclosure. Preserve the coordinationNotice target and its deadline transitions. Only the expanded policy body scrolls on short mobile viewports; the cancellation notice and summary remain visible. Limit the expanded body to one fifth of the mobile visual viewport height.

Capture the user's current scroll position before a disclosure toggle. After layout changes, keep users at the latest message when following the conversation, or preserve their older-history position. Native summary interaction supports pointer activation and the keyboard, with a visible focus indicator and reduced-motion styling.

Acceptance: collapsed notice height is at most 64px at 320px, a 390x420 reduced viewport, and desktop; expanded details leave more than 50px for messages; toggling preserves both latest-message following and older-history position in both themes. Cancellation messaging and expiry transitions remain visible. Measure actual geometry instead of claiming an unverified 70% space saving.

Browser coverage: test/system/mobile_trip_chat_test.rb and test/system/chat_deadline_transitions_test.rb.

```sh
mise exec -- bin/rails test test/system/mobile_trip_chat_test.rb
mise exec -- bin/rails test test/system/chat_deadline_transitions_test.rb
```

## 3. Shared badges

Targets:
- app/views/ride_posts/show.html.erb
- app/views/chat_messages/_chat_message.html.erb
- app/views/ride_posts/index.html.erb

Use Badge::Component for canceled/read-only statuses, chat driver roles, verified community badges, female-profile badges, and route-alert subscription status. Preserve the actual community name and existing subscription wording. Keep the dynamically updated live/coordination status target compatible with the chat controller.

Acceptance: community identity, role labels, route subscription cancellation, and read-only state remain available through existing controller and browser flows.

```sh
mise exec -- bin/rails test test/controllers/route_subscriptions_controller_test.rb
```

## 4. Create and edit form ergonomics

Targets:
- app/views/ride_posts/_form.html.erb
- app/views/ride_posts/new.html.erb
- app/views/ride_posts/edit.html.erb

Baseline correction: the schedule choices already had two mobile columns and the seat buttons already had 44px targets. Preserve those existing fixes. Refine option spacing and responsive padding. Hide decorative icons on phones, use 12px mobile option headings, and remove the mobile hint indent so headings stay within their pills and hints need at most two lines. Use 20px mobile card padding and retain 32px desktop padding on both create and edit pages.

Stack Visibility and Community Hub until the md breakpoint, giving narrow tablets the same readable layout. Preserve both seat buttons' aria-labels and non-submitting behavior; retain 44px targets on phones and use 48px targets above the sm breakpoint.

Acceptance: two schedule columns below 640px and three from 640px; audience controls remain stacked through 640px; both seat targets are at least 44x44px; create and edit forms fit 320px, 390px, and 640px without document overflow. Existing keyboard labels and seat adjustment behavior remain intact.

Browser coverage: test/system/mobile_ux_remediation_test.rb and test/system/passenger_seats_test.rb.

```sh
mise exec -- bin/rails test test/system/mobile_ux_remediation_test.rb
mise exec -- bin/rails test test/system/passenger_seats_test.rb
```

## 5. Notification row navigation

Target: app/views/notifications/_notification.html.erb

Stretch the existing View link across its relatively positioned row. Retain the notification endpoint, so navigation marks the notification read and uses the current target resolution and access checks. Provide a descriptive accessible link name and a focus ring around the row.

Acceptance: clicking the row away from View opens the correct ride and marks it read; activating the semantic link with Enter does the same at a 320px viewport. Realtime notification badge and list updates continue to pass.

Browser coverage: test/system/notifications_test.rb.

```sh
mise exec -- bin/rails test test/system/notifications_test.rb
```

## 6. Search swap placement

Target: app/views/ride_posts/_search_form.html.erb

Remove the dedicated right-hand swap column. Keep origin and destination fields full width. Place a circular 44px button centered between them, reserving enough vertical space to avoid covering either field or its label. Keep the DOM focus order From, To, swap, Date, Search.

Acceptance: on home and ride search pages, the swap button is centered between aligned fields and clear of the From input and To label; route and Date fields have equal widths; its target is at least 44x44px. Long labels, dropdown option hit-testing, submitted swapped IDs, and keyboard order work at 320px, 360px, 390px, 768px, and 1440px in both themes.

Browser coverage: test/system/responsive_ux_test.rb and test/system/responsive_flows_test.rb.

```sh
mise exec -- bin/rails test test/system/responsive_ux_test.rb
mise exec -- bin/rails test test/system/responsive_flows_test.rb
```

## 7. Admin navigation

Target: app/views/layouts/admin.html.erb

Use a horizontally scrollable navigation row, with non-wrapping links and at least 44px action height. Allow the row to shrink within its flex parent; keep the scrollbar available for discoverability. Preserve current-page semantics and the existing sign-out action.

Acceptance: the document does not overflow at 320px; scrolling the navigation makes the final action reachable; Back to Pasabaya still works.

Browser coverage: test/system/admin_moderation_test.rb.

```sh
mise exec -- bin/rails test test/system/admin_moderation_test.rb
```

## 8. Final verification gate

Run the repository gate after implementation and any repairs:
```sh
mise exec -- bin/ci
```

The gate performs setup, Ruby style checks, template lint, database consistency, architecture checks, gem/importmap/Brakeman security checks, Rails tests, system tests, and test-only seed verification. Standalone seed checks must also explicitly select the test environment:
```sh
mise exec -- env RAILS_ENV=test bin/rails db:seed:replant
```

Report blocked or incomplete checks accurately. Browser coverage here uses Chromium with a simulated reduced visual viewport; physical iOS/Android keyboard behavior remains a manual device check. Retain the existing no-hamburger navigation design. Preserve unrelated working-tree changes.
