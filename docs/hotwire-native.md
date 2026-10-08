# Hotwire Native foundation

Pasabaya keeps search, rides, bookings, chat, account forms, and authorization in Rails. Native apps provide platform navigation and selectively enhance HTML controls. This repository implements the Rails foundation; it does not contain native iOS or Android app shells or push-notification integrations.

## Navigation contract

| Tab | Start path | Authentication |
| --- | --- | --- |
| Search | `/rides` | Public; restricted rides remain protected |
| My Trips | `/trips` | Required; resolves the signed-in user |
| Hubs | `/communities` | Public discovery; membership gates restricted content |
| Account | `/settings/profile` | Required |

Serve remote path configuration from `/configurations/ios_v1.json` and `/configurations/android_v1.json`. The files live in `public/configurations`, so initial configuration loading does not depend on signing in. Their `settings.tabs` is an application contract: client apps read it and construct platform tab controllers. Hotwire Native does not create tabs automatically from this setting.

Each native app bundles the matching JSON file as its initial/offline configuration fallback, loading the remote version before creating navigators. Keep v1 available when a future breaking change requires v2. Android's default destination registers `hotwire://fragment/web`.

Sign-in, registration, password reset, ride creation/editing, and trip feedback forms open as modals. Modal forms disable pull-to-refresh. Ride and account form writes redirect with 303; their validation responses use 422 and retain the form. Booking actions and Hub membership requests redirect with 303, including error feedback. Ride detail links preserve `?tab=chat`, including canonical redirects. Path patterns handle both numeric IDs and route slugs.

### Caching and configuration delivery

Navigation configurations (`/configurations/ios_v1.json`, `/configurations/android_v1.json`) mandate revalidation (`Cache-Control: public, no-cache, must-revalidate` with `ETag` and `Last-Modified`) via `Middleware::NativeConfigurationCacheControl`. This ensures client apps promptly receive routing and tab rule changes without waiting for stale static file caches to expire, while preserving far-future caching for digest-stamped assets.

## Shared HTML and sessions

The standard Hotwire Native user agent (`Hotwire Native iOS` / `Hotwire Native Android`) selects short HTML titles and native styling. It is a presentation hint and grants no permissions. HTML varies by `User-Agent`; authenticated responses use `private, no-store`. Private native pages opt out of Turbo snapshots to avoid showing cached account content after logout or account switching.

Profiles on Hotwire Native visibly identify their owner by name (`profile-name` / `data-profile-name` excluded from `main h1` screen-reader hiding), ensuring users with no active listings still have visible ownership.

The full web navbar/footer are hidden in native mode. Compact HTML navigation keeps posting, notifications, account access, logout, and legal pages reachable before native controls exist. Native headings remain available to assistive technology. Chat uses the same HTML, with sender alignment determined in the viewing browser rather than baked into broadcasts.

Use the existing signed, persistent session-ID cookie and server-side `Session` records. HTTPS cookies are Secure and HttpOnly. Destroying a session disconnects its live connections; channels also check that the session still exists before transmitting. The generic Turbo channel rejects subscriptions, so new realtime features must use an explicitly authorized application channel.

## Verification

`bin/ci` runs style, template, architecture, database, security, Rails, browser, and seed checks. The test suite covers:
- Remote configuration delivery, headers, and 304 conditional revalidation.
- Two-user request/accept/chat flows at phone width.
- Live notification badges and empty states.
- Modal presentation, return paths, and persistent session authentication.

References: [official path configuration](https://native.hotwired.dev/overview/path-configuration), [navigation properties](https://native.hotwired.dev/reference/path-configuration), and [bridge components](https://native.hotwired.dev/reference/bridge-components). The implementation follows the Rails-first approach in Joe Masilotti's *Hotwire Native for Rails Developers*.
