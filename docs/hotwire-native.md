# Hotwire Native foundation

Pasabaya keeps search, rides, bookings, chat, account forms, and authorization in Rails. Native apps will provide navigation and selectively enhance HTML controls. This repository currently implements the Rails foundation; it does not contain iOS or Android apps or a push-notification integration.

## Implementation sequence

1. Security and privacy: escape toast text, validate and guard Facebook links, disconnect revoked sessions, and authorize each live subscription.
2. Trip correctness: retain acceptance history for post-departure reviews, save reviews and incidents atomically, complete overdue trips, and retain Hub audience and trip history.
3. Shared interface: render chat independently of request context, react to streamed notifications, preserve filters and chat links, and verify phone layouts and keyboard controls.
4. Native foundation: provide stable tab destinations, public versioned configuration, client-specific presentation, persistent sessions, and correct form responses.

Each phase is verified with behavior tests and `bin/ci`, then committed locally before the next phase.

## Navigation contract

| Tab | Start path | Authentication |
| --- | --- | --- |
| Search | `/rides` | Public; restricted rides remain protected |
| My Trips | `/trips` | Required; resolves the signed-in user |
| Hubs | `/communities` | Public discovery; membership gates restricted content |
| Account | `/settings/profile` | Required |

Serve remote path configuration from `/configurations/ios_v1.json` and `/configurations/android_v1.json`. The files live in `public/configurations`, so initial configuration loading does not depend on signing in. Their `settings.tabs` is an application contract: future Swift/Kotlin clients must explicitly read it and construct the platform tab controllers. Hotwire Native does not create tabs automatically from this setting.

Bundle the matching JSON file in each native app as its initial/offline configuration fallback, then load the remote version before creating navigators. Keep v1 available when a future breaking change requires v2. Android's default destination must register `hotwire://fragment/web`.

Sign-in, registration, password reset, ride creation/editing, and trip feedback forms open as modals. Modal forms disable pull-to-refresh. Ride and account form writes redirect with 303; their validation responses use 422 and retain the form. Booking actions and Hub membership requests redirect with 303, including error feedback. Ride detail links preserve `?tab=chat`, including canonical redirects. Path patterns handle both numeric IDs and route slugs.

## Shared HTML and sessions

The standard Hotwire Native user agent selects short HTML titles and native styling. It is a presentation hint and grants no permissions. HTML varies by `User-Agent`; authenticated responses use `private, no-store`. Private native pages opt out of Turbo snapshots to avoid showing cached account content after logout or account switching. Future native clients must also clear/reset every tab's navigation state when accounts change.

The full web navbar/footer are hidden in native mode. Compact HTML navigation keeps posting, notifications, account access, logout, and legal pages reachable before native controls exist. Replace this fallback only when equivalent native actions work. Native headings remain available to assistive technology. Chat uses the same HTML, with sender alignment determined in the viewing browser rather than baked into broadcasts.

Use the existing signed, persistent session-ID cookie and server-side `Session` records. HTTPS cookies are Secure and HttpOnly. Destroying a session disconnects its live connections; channels also check that the session still exists before transmitting. The generic Turbo channel rejects subscriptions, so new realtime features must use an explicitly authorized application channel.

## Native implementation next

Start with the existing web screens and platform navigators/tab controllers. Prove sign in → search → request → accept → chat on both devices before adding native screens.

Add a bridge component only for a specific need, such as a native submit button. It should activate the existing HTML form so Rails validation, CSRF, and authorization remain shared. Hide an HTML control only when that component is supported by the installed client, and clean up native controls when their HTML component disconnects. Existing importmaps and Stimulus can support the web bridge library when the first component is implemented; no bundler change is needed now.

Introduce JSON endpoints only for actual native consumers, such as device-token registration or a native map. Push notifications will need APNs/FCM credentials, contextual permission requests, token rotation, account/logout cleanup, delivery-status handling, and authenticated deep links. Reuse Pasabaya's existing notification records and jobs rather than replacing them wholesale. Keep CSRF protection on cookie-authenticated writes and verify native HTTP cookie handling separately for each platform.

## Verification

`bin/ci` runs style, template, architecture, database, security, Rails, browser, and seed checks. The browser suite covers the two-user request/accept/chat flow at phone width, live notification empty states and badges, and toast injection. Controller tests cover native titles/configuration, restricted destinations, secure persistent cookies, return paths, and revocation.

Before a native beta, separately verify real iOS and Android app restarts, cookie persistence across tabs, modal dismissal and 422 errors, keyboard/safe-area behavior, camera/photo upload, slow/offline connections, logout in every tab, and deep links while signed out or with a canceled/inaccessible trip. Browser tests do not establish native-device readiness; Turbo snapshots and configuration fallback are not offline data storage.

References: [official path configuration](https://native.hotwired.dev/overview/path-configuration), [navigation properties](https://native.hotwired.dev/reference/path-configuration), and [bridge components](https://native.hotwired.dev/reference/bridge-components). The implementation follows the Rails-first approach in Joe Masilotti's *Hotwire Native for Rails Developers*.
