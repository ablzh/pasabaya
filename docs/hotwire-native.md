# Hotwire Native foundation

Pasabaya keeps search, rides, bookings, chat, account forms, and authorization in Rails. Native apps will provide navigation and selectively enhance HTML controls. This repository currently implements the Rails foundation; it does not contain iOS or Android apps or a push-notification integration.

## Implementation sequence

1. Security and privacy: escape toast text, validate and guard Facebook links, disconnect revoked sessions, and authorize each live subscription.
2. Trip correctness: retain acceptance history for post-departure reviews, save reviews and incidents atomically, complete overdue trips, and retain Hub audience and trip history.
3. Shared interface: render chat independently of request context, react to streamed notifications, preserve filters and chat links, and verify phone layouts and keyboard controls.
4. Native foundation: provide stable tab destinations, public versioned configuration, client-specific presentation, persistent sessions, and correct form responses.

Each phase is verified with behavior tests and `bin/ci`, then committed locally before the next phase.

## Updated follow-up plan — 3 October 2026

The initial four Rails phases are committed. The current working tree also contains the QA01–QA13 fixes and their tests, documented in [the browser QA report](qa/2026-10-03-browser-audit.md#implementation-results-and-evidence). That report records verification within Rails/Chromium coverage; real-device and production checks remain separate. Preserve these changes and their evidence rather than implementing the same fixes again.

The review follow-ups below remain open in the inspected source. In particular, the new review-form eligibility guards address impossible review forms, but do not yet prevent editing or deleting historical canceled trips.

### Phase 5: Optional Facebook links and legacy backfill (Completed — commit `8473ae2`)

- Facebook links are optional in models, signup, profile settings, and privacy copy; profile links render safely without implying verified identity.
- Validation allows blank inputs and validates new or changed links without blocking password resets on unchanged legacy values.
- Implemented `Users::BackfillFacebookUrlsService` and rake task `users:backfill_facebook_urls` with dry-run summary, safety normalization, audit backup in `tmp/`, idempotent updates in batches, and production safety guards.

### Phase 6: Protect historical trip participation (Completed — commit `1bf23df`)

- Formerly accepted and late-canceled bookings retain post-departure review eligibility and are protected from hard deletion.
- Trips with historical participation cannot have route or schedule altered after departure or late cancellation, nor can they be hard deleted.
- Driver and passenger accounts with departed historical participation are protected from deletion until review periods conclude.
- Normal editing of unmatched drafts and cancellation before departure remain unaffected.

### Phase 7: Native presentation and configuration delivery (Completed)

- Navigation configurations (`/configurations/ios_v1.json`, `/configurations/android_v1.json`) mandate revalidation (`Cache-Control: public, no-cache, must-revalidate` with `ETag` and `Last-Modified`) via `Middleware::NativeConfigurationCacheControl`, avoiding the 1-year static file cache while preserving far-future caching for digest-stamped assets.
- Profiles on Hotwire Native visibly identify their owner by name (`profile-name` / `data-profile-name` excluded from `main h1` screen-reader hiding), ensuring users with no active listings still have visible ownership.
- Controller and system tests verify production-equivalent cache headers, conditional revalidation (`304 Not Modified`), and visible native profile presentation.

### Phase 8: Native apps and device acceptance (Future work)

- Build the iOS/Android shells using the shared Rails screens and navigation contract below. Add bridge components only for an implemented native control and JSON endpoints only for a real native consumer.
- Prove sign in → search → request → accept → chat on devices, then complete the device checks in the verification section before a native beta. Add push delivery as a separate step once platform credentials and its account/device lifecycle are ready.


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

## Native implementation next (Phase 8 Roadmap)

### Prerequisites

1. **Tooling & SDKs:**
   - **iOS:** macOS with Xcode 15+, targeting iOS 17+, using the Swift Package Manager dependency `hotwire-native-ios` (Turbo Navigator).
   - **Android:** Android Studio Hedgehog+, targeting Android API 26+ (minSdk 26, targetSdk 34+), using Gradle dependency `dev.hotwire:core`.
2. **Platform Accounts & Credentials:**
   - Apple Developer Account with APNs Auth Key (`.p8`), App ID with Associated Domains (Universal Links) and Push Notifications capability.
   - Google Cloud / Firebase console project with FCM v1 credentials and `google-services.json` (Android App Links assetlinks).
3. **Application Endpoints Prepared in Rails:**
   - Remote path configuration delivered at `/configurations/ios_v1.json` and `/configurations/android_v1.json` with mandatory revalidation (`public, no-cache, must-revalidate`).
   - Secure persistent cookie authentication, CSRF handling via Turbo, and Turbo cache exemption on authenticated screens.

### Step-by-Step Implementation Steps

1. **Create Native App Shells:**
   - Generate empty native projects in their own repositories or dedicated directories (`ios/` and `android/`).
   - Embed `public/configurations/ios_v1.json` (iOS bundle resource) and `public/configurations/android_v1.json` (Android raw asset) as initial offline fallback configurations.
   - Configure Hotwire to load remote path configuration on app launch from `https://<domain>/configurations/{platform}_v1.json`.
2. **Implement Platform Tab Navigation:**
   - Explicitly read `settings.tabs` from the loaded path configuration.
   - Construct native root tab bar controller with 4 tabs:
     - Search (`/rides`)
     - My Trips (`/trips`)
     - Hubs (`/communities`)
     - Account (`/settings/profile`)
   - For Android, register `hotwire://fragment/web` as the default destination and provide custom fragment factories for modals.
3. **Verify Core User Flows & Session State:**
   - Walk through: Launch app → Search rides → Sign in → Request seat → Accept booking → Open trip chat.
   - Ensure cookies persist across app process kill and restart.
   - Ensure signing out cleans up navigation state and history in all tabs, preventing stale cached Turbo snapshots.
4. **Implement Hotwire Native Bridge Components (As Needed):**
   - When a native UI control is required (e.g. native navigation bar "Post" button or native modal dismiss), add `@hotwired/hotwire-native-bridge` to the Rails frontend via importmap.
   - Build lightweight Stimulus bridge controllers connecting HTML form buttons to native toolbar items without duplicating Rails validations or CSRF tokens.
5. **Push Notifications & Device Registration:**
   - Implement Rails device registration endpoint: `POST /devices` (storing `token`, `platform`, `user_id`, `last_used_at`).
   - Add push notification dispatch service using APNs HTTP/2 client and FCM v1 API, triggering on `Notification` and `ChatMessage` creation.
   - Wire notification payload deep links (e.g., `pasabaya://rides/123?tab=chat`) to open the corresponding tab and navigate to the conversation or booking modal.
6. **Device Acceptance & Beta Sign-off:**
   - Complete the physical device verification checklist below on physical iOS and Android hardware across slow 3G/offline connections, camera/photo uploads, and background resumes.


## Verification

`bin/ci` runs style, template, architecture, database, security, Rails, browser, and seed checks. The browser suite covers the two-user request/accept/chat flow at phone width, live notification empty states and badges, and toast injection. Controller tests cover native titles/configuration, restricted destinations, secure persistent cookies, return paths, and revocation.

Before a native beta, separately verify real iOS and Android app restarts, cookie persistence across tabs, modal dismissal and 422 errors, keyboard/safe-area behavior, camera/photo upload, slow/offline connections, logout in every tab, and deep links while signed out or with a canceled/inaccessible trip. Browser tests do not establish native-device readiness; Turbo snapshots and configuration fallback are not offline data storage.

References: [official path configuration](https://native.hotwired.dev/overview/path-configuration), [navigation properties](https://native.hotwired.dev/reference/path-configuration), and [bridge components](https://native.hotwired.dev/reference/bridge-components). The implementation follows the Rails-first approach in Joe Masilotti's *Hotwire Native for Rails Developers*.
