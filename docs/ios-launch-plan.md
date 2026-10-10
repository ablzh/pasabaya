**Pasabaya iOS and Android launch plan**

Updated October 4, 2026. This is a plan only. Both iOS and Android are included in the first release scope.

The first release will reuse Rails for search, ride offers, seat requests, trip history, chat, profiles, and authorization. Swift on iOS and Kotlin on Android, with Hotwire Native, will supply native navigation, persistent web sessions, and device-specific behavior. Keep the existing Rails server, SQLite, Solid Queue, and Solid Cable.

The first release is a free iPhone app and Android phone app with the existing four tabs and complete trip coordination. Keep the existing notification center, live badges/toasts while connected, email delivery, and in-app chat. Push notifications are a separate future project: they are not an implementation phase, test gate, or store-release dependency here. This release will not alert a closed/backgrounded app about new messages or booking events through native push; users can check the app and use the existing email notifications.

Do not add device registrations, push jobs, Firebase/APNs setup, messaging SDKs, notification permissions, or push-specific entitlements as preparation for this release. Maps, background location, offline trip writes, social login, and payment integration are also deferred. Both clients belong to this launch effort, but their store submissions can proceed independently when ready.

**Current project baseline**

Checked against the current checkout, rather than treating earlier planning items as unfinished:

| Area | Current state | Remaining work |
| --- | --- | --- |
| Rails screens and authorization | Shared web/native flows exist | Verify on WKWebView and Android WebView; preserve access checks for every new endpoint |
| Sessions | Persistent signed session-ID cookie and revocable server sessions exist | Test shared sessions across tabs, restart, logout, password reset, and account switching |
| Navigation | Both platform configuration files, modal rules, tab destinations, cache revalidation exist | Bundle a fallback per client and build native navigation; verify Android modal destinations against the chosen library |
| Previous review fixes | Optional Facebook links/backfill, history protection, configuration caching, profile presentation exist | Regression verification; do not implement them again |
| Notifications | Durable booking notifications, email, live badges/toasts, delivery/recovery jobs exist | Verify existing behavior in both clients; push is deferred entirely |
| Chat | Authorized realtime trip chat exists | General abuse reporting/blocking and foreground/reconnect behavior on both clients |
| Account deletion | In-app deletion/anonymization and recovery journal exist | Verify removal/retention and correct misleading screen copy; extend cleanup for new records |
| Store preparation | Privacy and terms pages exist | App Privacy/Data safety disclosures, support/deletion pages, reviewer access, both store listings |
| Native clients | Neither iOS nor Android project exists in this repository | Create both projects and implement the shells |

The existing architecture contract is in [hotwire-native.md](/Users/uzver/Repos/pasabaya/docs/hotwire-native.md). This baseline is a source inspection, not a claim that the current application passed device testing or CI during planning.

**Phase 1 — Finish the backend release work**

Complete the following shared backend milestones first; both clients use the same behavior. Native work can begin against the existing backend while these items are finished, but public release must include the required safety/deletion flows. Account enrollment and Android tester recruitment can start early to avoid calendar delays. No push backend work belongs to these milestones.

**1A. Complete the account-deletion and support experience**

1. Keep the existing deletion entry point in Account Settings and password confirmation. Verify that the user can complete it entirely inside both native apps.
2. Correct the current description and confirmation in [profiles/show.html.erb](/Users/uzver/Repos/pasabaya/app/views/settings/profiles/show.html.erb): “all associated data” and “all your rides will also be deleted” do not accurately describe the implemented anonymization and retained history. Explain precisely what disappears and what, if anything, remains.
3. Review retained records for residual personal information and user content, not just display names. Record the purpose and applicable basis for any retention. An anonymized label by itself does not prove that a record is de-identified.
4. Reuse the existing deletion/recovery mechanism in [account-deletion-recovery.md](/Users/uzver/Repos/pasabaya/docs/account-deletion-recovery.md). Include new abuse-report/block records in deletion and recovery cleanup with an explicit retention rule.
5. Add a small public support page with working contact details and links to privacy, terms, account deletion, and abuse reporting. Also publish an account-deletion request page for Google Play that identifies Pasabaya, explains the request steps and retained data, and provides a working route to request deletion without reinstalling the app. Check that published contact inboxes are actually monitored.

Apple requires account-deletion initiation inside apps that create accounts, and addresses associated user-generated content and legally required retention in its [account-deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/). Google Play requires both an in-app deletion path and an outside-app web resource for deletion requests. [Google account-deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111).

**Done when:** deletion works inside the app, the text matches the backend, retained data has been assessed, and support links work. Add the smallest regression test for each behavior changed.

**1B. Add a minimal abuse-reporting and blocking flow**

Pasabaya has chat, avatars, ride notes, and reviews. Its no-show incident system is not a general abuse-reporting or user-blocking feature.

1. Add a report action where a user encounters a message, listing, profile, or review. Save the reporter, target, reason, time, and handling status; do not create a separate moderation service.
2. Add a block/unblock action. Define its behavior for discovery, new requests, existing trips, shared trip chat, and existing in-app notifications before implementation. Prevent new interaction between blocked users, hide blocked-author content from the blocker, and preserve a safe way to see or cancel existing commitments. Enforce the rules in Rails, including live delivery.
3. Add proportionate objectionable-content filtering for the text/uploads the app accepts. Start with simple rules and manual review appropriate to the volume; define what those rules cover and their limits.
4. Give the operator a small protected report list and actions to remove content or restrict an account. Define a realistic response process and check the queue regularly. A report button without anyone handling reports is incomplete.
5. Keep these controls on the shared Rails screens so web users benefit too. Test that another user cannot change a report, unblock somebody else's block, or bypass restrictions through direct requests.

Filtering, reporting with timely responses, blocking, and published contact details come from Apple's user-generated-content rule, [Guideline 1.2](https://developer.apple.com/app-store/review/guidelines/#user-generated-content). The particular implementation above is our recommendation for this project.

**Done when:** a user can report and block from a relevant screen, the restrictions work across shared flows, and the operator can act on reports.

**1C. Reconcile shared navigation, privacy, and deployment**

1. Update the policy for the actual iOS/Android data flow, new report/block records, retention, and deletion. Do not disclose unimplemented push collection as if it exists.
2. Inventory data from the Rails screens and native dependencies for Apple App Privacy and Google Play Data safety answers. Include GoatCounter, server diagnostics, account data, trip information, chat, avatars, and device identifiers where applicable. Disable analytics in native mode if it serves no useful purpose; verify the result rather than assuming a privacy-focused product means no disclosure.
3. Verify the iOS and Android tab destinations and modal rules against the selected library releases. Android rules must resolve to registered fragment destinations, including modal/sheet destinations where required; adjust the Rails JSON and native registrations together. Confirm bundled fallbacks, conditional revalidation, and redirects with query strings.
4. Confirm HTTPS/WSS, workers, email, both configuration URLs, backups, and restore procedures. Continue serving `ios_v1.json` and `android_v1.json` for installed clients when future versions are introduced.
5. Run targeted tests, then `bin/ci`. Deploy the tested backend before distributed builds rely on new endpoints. Deployment is a later implementation action, not part of this planning task.

**Done when:** shared flows pass, disclosures match the intended release, deployment is ready, and every required check is reported accurately.

**Phase 2 — Set up both developer accounts and app identities**

**2A. Apple Developer and App Store Connect**

The owner performs identity verification, agreements, and payment. An implementation agent can prepare the project and instructions; it cannot supply your legal identity or complete verification on your behalf.

1. Create or use an [Apple Account](https://account.apple.com/) and enable two-factor authentication. Use an account you control long term.
2. Start at [Apple Developer Program enrollment](https://developer.apple.com/programs/enroll/). For a personally maintained project, choose **Individual**. Enter your legal name, address, phone, and requested identity information. Apple's normal membership fee is **US$99 per year**, with local pricing shown during enrollment. Your legal personal name appears as the seller; the app can still be named Pasabaya.
3. Alternatively, where supported, install the Apple Developer app, open **Account → sign in → Enroll Now**, and follow verification and payment. [Enrollment in the app](https://developer.apple.com/help/account/membership/enrolling-in-the-app).
4. Choose Organization only for an actual eligible legal entity. A personal noncommercial project does not automatically receive a nonprofit waiver. [Fee-waiver eligibility](https://developer.apple.com/help/account/membership/fee-waivers/).
5. Install the latest stable Xcode compatible with your Mac. As checked on October 4, 2026, uploads require **Xcode 26+ and the iOS 26 SDK+**. Recheck this at submission. These are build requirements, not a requirement that every user run iOS 26. [Apple's current requirements](https://developer.apple.com/news/upcoming-requirements/).
6. In Xcode settings, add the Apple Account. In the app target's **Signing & Capabilities**, select the enrolled Team and enable **Automatically manage signing**.
7. Choose a permanent Bundle ID, for example `app.pasabaya.ios` if available. Register the explicit App ID through [Apple Developer Account](https://developer.apple.com/account/) → **Certificates, Identifiers & Profiles → Identifiers → + → App IDs → App**. Use the exact same Bundle ID in Xcode and Apple. The example is proposed, not an identifier already registered.
8. Open [App Store Connect](https://appstoreconnect.apple.com/) → **Apps → + → New App**. Choose iOS, name, primary language, registered Bundle ID, and a unique internal SKU such as `pasabaya-ios`. [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app).

You can prototype in the simulator before buying membership. Enrollment becomes necessary for TestFlight and App Store distribution. If enrollment takes time, continue local shell work while it is pending.

**Done when:** membership is active, the owner understands the public seller identity, Xcode signs with the correct Team, and the App Store Connect record matches the project.

**2B. Google Play Console and Android app identity**

1. Use a Google account you control long term and register at [Google Play Console](https://play.google.com/console/signup). Choose **Personal** for a personally maintained project, accept the developer agreement, and pay the **US$25 one-time registration fee**. Complete the identity/contact verification requested by the console. Choose Organization only for an eligible real organization. [Registration requirements](https://support.google.com/googleplay/android-developer/answer/6112435).
2. Complete any required Android-device verification through the Play Console mobile app. For new personal accounts, this requires access to a non-rooted physical phone running Android 10 or later; an emulator does not satisfy it. Account/device checks are owner tasks. [Device verification](https://support.google.com/googleplay/android-developer/answer/14316361).
3. Choose a stable application ID, for example `app.pasabaya.android` if available. Keep it consistent in the Android project and Play uploads. In Play Console choose **Create app**, enter the name/language, select app rather than game, set it as free, and complete the initial declarations. [Create an app](https://support.google.com/googleplay/android-developer/answer/9859152).
4. If this is a personal account created after November 13, 2023, plan for a closed test with **at least 12 testers continuously opted in for at least 14 days** before applying for production access. Recruit testers early; record genuine usage and feedback. Finishing 14 days does not automatically grant production access, and internal testing does not replace this requirement. [Personal-account testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465).
5. Review the account's Android developer verification/package-registration status and complete outstanding items shown by Play Console. Use the actual account's requirements rather than treating unrelated regional rollout dates as a Philippine launch deadline. [Developer verification](https://developer.android.com/developer-verification).
6. Install stable [Android Studio](https://developer.android.com/studio), its SDK tools, and a compatible emulator. As checked on October 4, 2026, new phone apps must target **Android 16 / API 36 or later**. Choose `compileSdk` at least as high as `targetSdk`; `minSdk` is a separate device-support choice. Recheck before submission. [Target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878).

**Done when:** the account is verified, the app record/application ID is established, required device checks are complete, and the owner has a realistic plan for any mandatory closed test. Closed-test completion and production access are later gates.

**Phase 3 — Build the Hotwire Native iOS shell**

1. Keep the iOS client beside Rails under `ios/` in this repository, with one Xcode project and reproducible Swift Package Manager versions. This is a proposed location; no project has been created yet.
2. In Xcode use **File → New → Project → iOS App**, Swift and the UIKit/Storyboard setup described by Hotwire's starter guide. Add `https://github.com/hotwired/hotwire-native-ios` through **File → Add Package Dependencies**, selecting the application target. Pin a supported stable release and commit the package resolution when implementing. [Official starter guide](https://native.hotwired.dev/ios/getting-started).
3. Configure one base origin per build configuration. Release builds point to `https://pasabaya.app`; local builds may use a development endpoint. On a physical phone, `localhost` means that phone, not your Mac. Do not distribute a build depending on a private laptop address or broad insecure-network exceptions.
4. Set the minimum supported iOS version after checking the selected Hotwire package and Rails' `allow_browser versions: :modern` behavior in WKWebView. Test the oldest supported version. Package compatibility alone does not prove the HTML app works there.
5. Bundle `ios_v1.json`, configure local and remote sources before starting navigation, and use the bundled/cached configuration immediately. Remote updates arrive asynchronously; a failed network request must not prevent shell startup. Validate custom tab paths against the app origin and fall back safely. [Configuration loading](https://native.hotwired.dev/ios/path-configuration).
6. Use the built-in `HotwireTabBarController` and a `HotwireTab` for Search (`/rides`), My Trips (`/trips`), Hubs (`/communities`), and Account (`/settings/profile`). `settings.tabs` is our contract: client code reads it and constructs these tabs. Use lazy loading to avoid triggering authentication from an unselected private tab at startup. [Native tabs](https://native.hotwired.dev/ios/tabs).
7. Preserve the standard Hotwire Native user-agent marker. Apply modal rules for sign-in, registration, password recovery, ride forms, and trip reviews. Test cancel/dismiss, successful redirects, and 422 validation inside modals. Add a small bridge for session-change events if needed to refresh tab state.
8. Use persistent WebKit storage and the existing Rails session. On login/logout/account switching, refresh the relevant screens and reset private navigation stacks/screenshots so another account's content cannot appear when switching tabs or pressing Back. The existing Rails Turbo-cache protections remain part of this behavior.
9. Route external web links using the framework's browser handling. Provide a clear retry experience on lost connectivity and restore normal navigation after foregrounding or WebKit process termination. Reload/reconnect chat and existing in-app notifications on return so missed events become visible. Keep offline writes out of v1. [Navigator behavior](https://native.hotwired.dev/ios/reference).
10. Confirm all important actions remain reachable: Post Ride, the existing notification center, sign-out, support, privacy, and account deletion. Use native controls selectively where they improve the flow; keep Rails forms and validation shared.
11. Verify avatar selection, keyboard behavior in chat, safe areas, dark mode, VoiceOver, and large text. If camera capture is offered, add its accurate usage description; request only permissions the app uses. Decide deliberately whether to ship iPhone-only; enabling iPad adds testing and store assets.

**Done when:** on a real phone, two accounts can search → request → accept → chat, switch tabs, restart, recover a password, and log out without navigation loops or private-content leakage. Add focused native tests for meaningful client logic such as URL validation and invalid configuration fallback.

**Phase 4 — Build the Hotwire Native Android shell**

Android is part of this release, using the same screens and four tab destinations as iOS. Start its project during the initial mobile effort; it does not wait for a future notification project.

1. Keep the Android client beside Rails under `android/`, with the Gradle wrapper and pinned dependency versions. In Android Studio choose **New Project → Empty Views Activity**, Kotlin, and Kotlin DSL. Use the current supported Hotwire Native release with `dev.hotwire:core` and `dev.hotwire:navigation-fragments` in the application module. The official starter uses minimum API 28; confirm the selected package and actual WebView support before finalizing the floor. [Android starter guide](https://native.hotwired.dev/android/getting-started).
2. Use the built-in `HotwireBottomNavigationController` with a `HotwireBottomTab` for Search, My Trips, Hubs, and Account. Each tab has its own `NavigatorHost` and navigation stack; use the framework's lazy-loading option so opening Search does not load an unselected private tab and force sign-in. `settings.tabs` describes our destinations; client code constructs the native tab objects. Reuse these components instead of writing a custom tab controller. [Native bottom tabs](https://native.hotwired.dev/android/tabs), [Navigator model](https://native.hotwired.dev/android/reference).
3. Configure Hotwire in the Application before creating activities. Register normal and required modal fragment destinations so the server's `uri` properties resolve to actual fragments. Preserve the standard Hotwire Native Android user-agent marker. [Android configuration](https://native.hotwired.dev/android/configuration).
4. Bundle `android_v1.json` under application assets and configure both that fallback and `https://pasabaya.app/configurations/android_v1.json`. Use local/cached rules immediately while remote loading proceeds. Match modal behavior and registered destination URIs to the chosen release, rather than assuming `context: modal` alone implements every presentation. [Android path configuration](https://native.hotwired.dev/android/path-configuration).
5. Add internet access and use the production HTTPS origin in release builds. Android emulator access to a Rails server on the host differs from an iPhone simulator; configure a debug-only reachable endpoint. Never ship a localhost/private-laptop dependency or a broad cleartext exception.
6. Keep Rails cookie authentication in WebView and verify persistence after app restart. On login/logout/account switching, refresh tab state, clear private stacks/previews, and preserve server-side session revocation. Do not introduce an independent mobile password/token system.
7. Implement/test Android system Back and gesture navigation, modal dismissal, tab reselection, rotation/activity recreation, and process recreation. Restore safe state without revealing the previous user's pages. Use framework state/lifecycle support before adding custom persistence.
8. Verify Android edge-to-edge layouts, system bars, keyboard insets, form controls, chat input, file/avatar selection, dark mode, TalkBack, and large text. Use a system picker and request only permissions actually needed by the selected upload flow.
9. Keep external links in the platform browser/Custom Tabs and provide lost-connectivity retry. On returning to the app, reload/reconnect chat and existing in-app notifications so events missed while backgrounded become visible. Do not add background socket services or notification permissions to substitute for deferred push.
10. Make posting, the notification center, sign-out, support, terms/privacy, and account deletion reachable. Verify the full request → acceptance → chat flow against the same Rails authorization rules as iOS.
11. Inspect the release dependencies for bundled native `.so` libraries and check 16 KB page-size compatibility where applicable. Pure Java/Kotlin dependencies already support these devices; test the release in a compatible environment rather than adding an NDK unnecessarily. [Android page-size guidance](https://developer.android.com/guide/practices/page-sizes).

**Done when:** the complete flow works on an emulator and real Android phone, including restart, Back, account switching, uploads, and reconnect. Add focused tests for client routing/configuration logic and run Android build/lint/tests appropriate to the project. Rails `bin/ci` does not build or test this client.

**Phase 5 — Produce release builds and test both apps**

**5A. iOS archive and TestFlight**

1. Prepare a proper app icon in the Xcode asset catalog, launch presentation, human version such as `1.0.0`, and build number `1`. Increase the build number for each subsequent upload. Ensure the archive uses the production HTTPS origin and production configuration.
2. In Xcode select the app scheme and a generic/build-only iOS device destination, then **Product → Archive**. In Organizer select the archive, validate it, then **Distribute App → App Store Connect** and complete the upload. Wait for processing. [Archive/upload guidance](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).
3. Resolve export-compliance questions for the actual build. HTTPS uses encryption; do not blindly select “no encryption.” If the app qualifies for an exemption, use the appropriate declaration after checking its dependencies. [Export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance).
4. In App Store Connect → **TestFlight**, create a small testing group. Start with yourself and eligible internal users; invite ordinary volunteer testers externally. The first external build requires beta review. Internal testers have App Store Connect access, so do not grant project access merely to bypass external review. [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview).
5. Run the release checklist with separate driver/passenger accounts: request/accept/decline/cancel, trip chat, community permissions, account settings/deletion, report/block, existing in-app notifications/email, restart, offline retry, and old/new configuration. Include the oldest supported iOS and current iOS, large text, VoiceOver, and a small-screen phone.
6. Fix release blockers, run `bin/ci` for changed Rails code, and repeat affected device checks. Upload a new numbered build when the binary changes. Keep a brief record of devices, builds, results, and unresolved issues.

TestFlight currently supports up to 100 internal users and 10,000 external testers; builds expire after 90 days. A handful of volunteers is enough for this project's initial beta. Beta review is separate from App Store approval.

**Done when:** the release archive is accepted, critical flows work from TestFlight, and no known privacy, authorization, deletion, or data-loss blocker remains.

**5B. Android signing and Google Play testing**

1. Set the app icon, launch presentation, `versionName` such as `1.0.0`, and `versionCode` `1`. Increase `versionCode` for each new upload. Ensure the release build uses the public HTTPS backend, compatible SDK levels, and release-safe logging/WebView settings.
2. In Android Studio use **Build → Generate Signed Bundle / APK → Android App Bundle**. Create an upload keystore/key, store it and its passwords securely outside Git, and keep a recovery copy. Sign the release AAB with that upload key. Use **Play App Signing** for the store-managed app-signing key; the upload key and the final distribution key have different roles. [Signing and Play App Signing](https://developer.android.com/studio/publish/app-signing).
3. In Play Console open **Testing → Internal testing**, create a release, upload the signed `.aab`, and invite a small group. Install from the Play testing link to exercise the actual distribution path, rather than relying only on an Android Studio debug install. [Testing tracks](https://support.google.com/googleplay/android-developer/answer/9845334).
4. For an account with the mandatory personal-account test, publish an appropriate **Closed testing** release and have at least 12 testers remain opted in for 14 consecutive days. Provide usable trip data, collect feedback, fix issues, and answer the production-access questions honestly. Apply for production access after meeting the requirement; allow for Google's decision. Start this interval as soon as a genuinely usable build is ready.
5. Run the same driver/passenger checklist as iOS, including existing notification-center/email behavior, account deletion, abuse controls, restart, reconnect, and old/new configuration. Include the minimum supported Android, current Android/API 36 behavior, current Android System WebView, a modest phone, and accessibility settings.
6. Run the native project's relevant build/lint/tests, resolve Play's bundle/pre-launch findings, and repeat affected device checks. Upload a new signed build with a higher `versionCode` when the binary changes. Run `bin/ci` for Rails changes and report any unavailable checks.

**Done when:** Play-distributed testing builds work on real hardware, release signing is recoverable, critical shared flows pass, and any required closed testing and production-access approval are complete. Neither platform's beta checklist depends on push notifications.

**Phase 6 — Prepare both store listings and reviewer access**

**6A. Apple App Store**

1. Set the app name, subtitle, truthful description, keywords, category, copyright, free price, and intended availability. Starting with the Philippines matches the current product; broader distribution can be added deliberately later.
2. Capture screenshots of the actual release build: search, ride details/request, My Trips, chat, and account controls. Use the current accepted sizes shown in App Store Connect. Add iPad assets if iPad support is enabled. [Screenshot requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).
3. Supply working support and privacy URLs. Keep the policy reachable inside the app. Complete App Privacy answers from Phase 1's inventory, including data handled by embedded SDKs and web content. Do not claim “no data collected” because the UI is a web view. [App Privacy guidance](https://developer.apple.com/app-store/app-privacy-details/).
4. Inspect the archive's privacy report. Use current dependencies that include the required privacy manifests, and declare any required-reason APIs actually used by the app. SDK-specific manifest/signature requirements apply only to dependencies actually shipped; do not add messaging SDKs for this release. Privacy manifests, store labels, and the public policy are separate deliverables. [SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/), [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
5. Answer the age-rating and content-rights questions accurately, including messaging/user content. Do not choose an age rating merely because the project is noncommercial. [Age-rating questionnaire](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating).
6. Create dedicated reviewer driver/passenger accounts with unique credentials and useful future-trip data. Give instructions for testing both roles, community access, chat, report/block, and deletion. Keep them valid throughout review, refresh time-sensitive rides, and provide a disposable account for destructive tests. Send credentials only through App Review's private fields, not this public repository or screenshots.
7. Explain that Pasabaya is a free community carpool-matching app, uses shared Rails screens with native navigation, and has no payment collection. Own email/password login does not require adding social login; physical rides do not call for an IAP implementation. [Review Guidelines 3.1.3(e) and 4.8](https://developer.apple.com/app-store/review/guidelines/).
8. Demonstrate complete useful trip coordination and polished mobile behavior. Apple's minimum-functionality rule applies; Hotwire Native itself neither guarantees nor prevents approval, and there is no required number of native features. [Guideline 4.2](https://developer.apple.com/app-store/review/guidelines/#minimum-functionality).

**Done when:** App Store Connect has the tested build, complete metadata/declarations, screenshots, and functioning reviewer access; required fields have no outstanding validation errors.

**6B. Google Play listing and declarations**

1. Prepare the truthful title, short/full descriptions, category, app icon, feature graphic, and Android phone screenshots of the release build. Set the app as free and select intended countries; starting with the Philippines is a recommendation, not a requirement.
2. Complete **App content** declarations for **Data safety**, privacy policy, ads, app access, content rating, and target audience. Include data collected through Rails/WebView and actual dependencies; do not select “no data collected” just because there are no native analytics or push SDKs. Declare the absence of ads only after checking the shipped app. [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469).
3. Supply both the in-app deletion instructions and public deletion-request URL from Phase 1. Keep retention/deletion disclosures consistent across the app, policy, and store answers. [Deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111).
4. In **App access**, provide private reviewer credentials and steps for driver/passenger flows, community restrictions, report/block, and deletion. Reuse the review-data preparation from 6A, with credentials that remain available during review and no dependence on a real trip or inaccessible email verification.
5. Verify user-generated-content controls against Google's rules: terms/community standards, reporting, blocking for user interaction, and effective moderation. Keep these controls shared in Rails. [Google UGC policy](https://support.google.com/googleplay/android-developer/answer/9876937).
6. Demonstrate useful complete trip coordination with reliable native navigation. Check Play's minimum-functionality/content requirements; push is not part of this release's feature promise. [Functionality policy](https://support.google.com/googleplay/android-developer/answer/9898783).

**Done when:** the listing, app-content declarations, deletion URL, screenshots/assets, tested bundle, and reviewer instructions are complete, and the console has no outstanding release-blocking requirements.

**Phase 7 — Submit both apps for review and release**

**7A. Apple review and release**

1. Recheck Apple's current SDK/submission requirements. Select the exact TestFlight-tested build for version `1.0.0`.
2. Select **Manually release this version** so approval does not publish it before the final production check.
3. In the app version, choose **Add for Review**. Open the resulting submission and choose **Submit for Review**. Adding it to the submission alone does not send it to Apple. [Official submission steps](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app).
4. Keep Rails, workers, email, and reviewer accounts available. Monitor App Review messages. If Apple finds a problem, respond with clear reproduction/testing instructions and fix the specific issue. Upload a new numbered build for native changes; correct backend or metadata issues as appropriate and resubmit.
5. After approval reaches **Pending Developer Release**, check the public backend and key flows one last time, then select **Release This Version** and confirm when the owner is ready to publish. [Release controls](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option).
6. Watch failures and support reports after launch. Keep `ios_v1.json` compatible with the installed binary. Maintain the Developer membership, dependencies, and security fixes. Native changes and entitlement changes require a new build/review; Rails changes can be deployed while respecting store policies and the client contract.

**Done when:** Apple has approved the app, the owner has released it, the public listing is accessible, and installation/login/booking/chat have been checked against production. Review timing and approval are Apple's decisions; no schedule guarantee is assumed.

**7B. Google Play review and release**

1. Confirm production access, account verification, current target API requirements, and completion of the store declarations. Use the signed, tested bundle from Phase 5, promoting it from a testing track where appropriate.
2. Open **Production → Create new release**, select/upload the tested AAB, add release notes, choose countries, and resolve the review screen's errors. Send the production changes for Google's review through Publishing overview/release controls. Keep Rails and reviewer accounts available. [Prepare and roll out a release](https://support.google.com/googleplay/android-developer/answer/9859348).
3. Check **Publishing overview → Managed publishing** after the testing release. Google requires an app to already be available and recommends publishing to a closed testing track before using this control for a product launch. If eligible, enable it to hold approved production changes until the owner publishes them. If unavailable, plan for automatic publication after approval and coordinate submission with backend readiness. Do not assume either behavior without checking the app's console state. [Review and publishing controls](https://support.google.com/googleplay/android-developer/answer/9859654).
4. Address review findings and resubmit as needed. Confirm the first public listing, install from Google Play, and verify production login, booking, chat, deletion, and reconnect. Treat review/availability timing as an external dependency; do not wait for push or require both stores to approve on the same day.
5. Monitor failures/support after release and preserve `android_v1.json` compatibility. Use staged rollouts for later updates where useful; do not assume a staged percentage rollout is available for the first production release. [Staged updates](https://support.google.com/googleplay/android-developer/answer/6346149).

**Done when:** Google has approved production publication, the app is available in the intended countries, and the Play-installed release has passed the production checks. iOS and Android can publish independently once each is ready.

**Cost and execution rules**

| Item | Initial approach |
| --- | --- |
| Apple membership | US$99/year, or the local enrollment price; [official enrollment](https://developer.apple.com/programs/enroll/) |
| Google Play account | US$25 once; [official registration](https://support.google.com/googleplay/android-developer/answer/6112435) |
| Rails/database/workers | Reuse current hosting; additional capacity only if measured load requires it |
| Builds and beta | Local Xcode/Android Studio, TestFlight, and Play testing tracks; no paid build service planned |
| Monitoring and moderation | Existing logs plus a small operator workflow; no new paid SaaS planned |
| Hardware | Existing compatible Mac, a real iPhone, and a real Android phone; acquiring missing hardware is a separate cost |

For implementation, finish and verify one milestone before committing it locally and moving on. Follow `AGENTS.md`: smallest relevant behavior/regression tests, no unnecessary browser tests, `bin/ci` before declaring a code milestone complete, and explicit reporting of checks that could not run. Native tests/device checks supplement Rails CI; they are not covered by `bin/ci`. Account setup is an owner task and does not itself need a Git commit. This planning task makes no implementation commits, enrollment payments, deployments, uploads, submissions, or releases.

**Separate future task:** design and implement push notifications end to end for both platforms. It includes its own backend work, provider/account setup, client integration, delivery behavior, and tests. Do not create scaffolding or mark this launch incomplete because push is missing.

Other work that can wait: Universal Links/Android App Links for external email links, native maps, background location, offline data synchronization, paid monitoring, and cloud build automation.

**How this uses the book**

The relevant guidance in Joe Masilotti's *Hotwire Native for Rails Developers* is the Rails-first session model, progressively enhanced shared screens, platform navigation, and Chapter 9's TestFlight and Play testing/signing sequence. Chapter 10's push-notification implementation is outside this release scope.

Use current official API/tooling documentation over dated sample versions. Keep a public HTTPS release server, existing Rails cookie authentication and CSRF protections, and explicit logout/account-switch handling on both platforms. Treat the book as reference material, not as instructions overriding the owner's request or repository requirements.

Planning validation: local document references, phase scope, and formatting were checked. `bin/ci` was attempted on October 4, 2026, but could not start because the active Ruby environment lacks the locked bundle (`Bundler::GemNotFound`). No passing application gate, native build, or device verification is claimed. Application code was not changed and no commits were made by this planning update.
