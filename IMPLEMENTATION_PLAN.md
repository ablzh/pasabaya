# Pasabaya.app - Implementation Plan

## Objective
Transform the existing landing page into a functional carpooling bulletin board ("Pasabaya.app") where users can post and find shared rides in the Philippines.

## Background & Motivation
The app is a community-driven, non-profit tool designed to help commuters find travel companions easily. It focuses on simplicity ("digital bulletin board") and trust ("Facebook-Verified"), without handling payments or complex ride-matching algorithms.

## Access Rules & Security
- **Public Access (Guests):** Can view the list of available rides (the bulletin board) to see what routes are active.
- **Restricted Access (Logged In):** Must register via email to view contact information, view Facebook profile links, or create a new ride post.
- **Verification:** Users will manually provide their Facebook profile link during/after registration so others can check mutual friends.

## Data Models

### 1. User
- `email`: string
- `password_digest`: string (for secure login)
- `first_name`: string
- `last_name`: string
- `facebook_profile_url`: string (for the manual "Facebook-Verified" trust system)

### 2. RidePost
- `user_id`: foreign key (belongs to User)
- `post_type`: integer/enum (0 = Offering/Driver, 1 = Requesting/Passenger)
- `origin_city`: string (selected from a predefined dropdown)
- `destination_city`: string (selected from a predefined dropdown)
- `departure_time`: datetime
- `seats`: integer (available or needed)
- `contact_info`: string (e.g., Viber number, Messenger username)
- `notes`: text (specific meetup spots, rules, etc.)
- `status`: integer/enum (0 = Open, 1 = Full, 2 = Cancelled, 3 = Completed)

## Phased Implementation Plan

### Phase 1: Rails 8 Authentication & User Foundation
1. **Branching:** Create a new git branch `feature/core-app-foundation`.
2. **Authentication:** Generate the Rails 8 authentication system: `bin/rails generate authentication`.
3. **User Extension:** Enhance the generated `User` model with `first_name`, `last_name`, and `facebook_profile_url` via a new migration.
4. **Session Management:** Integrate generated session helpers into the main layout to manage "Log In" / "Sign Up" and user profile visibility.
5. **Solid Trifecta:** Confirm configuration for `Solid Cache`, `Solid Queue`, and `Solid Cable` to ensure the app is production-ready out of the box.

### Phase 2: The Bulletin Board Engine (Hotwire/Turbo 8)
1. **Model & Migration:** Generate the `RidePost` model. Use `enum` for `post_type` and `status` to leverage Rails' built-in logic.
2. **Standard CRUD:** Build the `RidePostsController` using idiomatic Rails conventions.
3. **Turbo Morphing:** Implement **Turbo 8 Page Refreshes** (Morphing) for ride creation and status updates to provide a high-fidelity feel without custom JavaScript.
4. **Validation:** Ensure strict model validations to maintain data integrity on the "bulletin board."

### Phase 3: Discovery & Mobile Optimization (PWA)
1. **Smart Filtering:** Build a search/filter interface using **Turbo Frames** to allow users to find rides by city without full page reloads.
2. **PWA Readiness:** Optimize the Rails 8 generated PWA manifest and service worker to ensure Pasabaya.app feels like a native mobile app for commuters.
3. **Privacy Layer:** Use the authentication system to mask `contact_info` and `facebook_profile_url` for unauthenticated guests, protecting user privacy.
4. **Deployment Readiness:** Verify `deploy.yml` and `secrets` configuration for **Kamal**, ensuring the app is ready for a "One Person" deployment to any Linux server.

## Verification & Standards
- **UI Components:** Use **railsblocks** professionally designed components for all interface elements to ensure high-fidelity aesthetics and rapid development. There are docs: https://railsblocks.com/docs/installation
- **Zero-JS Policy:** Prioritize Hotwire (Turbo/Stimulus) over custom JavaScript and first try to use Rails Blocks components, not custom.
- **Security:** Ensure guests are redirected to the sign-in page via the generated authentication filters when trying to access private data.
- **Responsiveness:** Use **Tailwind CSS** (via RailsUI) to ensure the board is fully functional on small mobile screens (primary device in PH).
- **Performance:** Use `Solid Cache` for fragment caching the most frequent ride queries.
