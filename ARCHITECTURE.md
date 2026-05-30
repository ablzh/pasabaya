# Architecture & Design: Carpooling Bulletin Board

## 1. Project Vision
A lightweight, community-driven carpooling bulletin board designed specifically for the Philippines. This is **not** a transportation service (like Uber or BlaBlaCar) but a digital board where users post ride offers/requests and handle coordination externally.

### Core Philosophy
- **One-Person Framework:** Built for maximum productivity and minimum maintenance using Rails 8.1.
- **Simplicity over Complexity:** No internal messaging, no payment processing, no real-time tracking.
- **Trust via Social Proof:** Leveraging Facebook (the primary social platform in the Philippines) as the foundation for user verification and communication.
- **SQLite Everywhere:** Utilizing SQLite for the primary database, background jobs (`SolidQueue`), and caching (`SolidCache`).

---

## 2. Trust & Safety Strategy
Since this is a free, non-intermediated platform, trust is decentralized.

### Facebook-Centric Trust
- **Mandatory Profiles:** Users *must* provide a valid Facebook profile URL to post or request rides.
- **External Hand-off:** Communication happens via Facebook Messenger. The "Contact" button on a post will link directly to the poster's Facebook/Messenger profile (`m.me/username`).
- **User Education:** The UI will explicitly encourage users to inspect Facebook profiles (activity, friends, age of account) before agreeing to a ride.

### Community Moderation
- **Reporting System:** A polymorphic `Report` model allows users to flag suspicious posts or abusive users.
- **Admin Bans:** A simple `banned_at` timestamp on the `User` model allows the admin to instantly revoke access.
- **Public Record:** The app is a "public" board; transparency is a deterrent for bad actors.

---

## 3. Location Strategy (Standardization)
To prevent typos and fragmented search results (e.g., "Manila" vs "manila"), the app uses a strictly controlled location hierarchy.

### Hierarchical Model
A single `locations` table uses a `parent_id` (self-reference) to create a hierarchy:
1. **Country:** e.g., Philippines (PH).
2. **Region/Province:** e.g., Metro Manila, Cebu, Davao.
3. **City/Municipality:** e.g., Makati, Quezon City.

### Flexibility
- **Current Scope:** Seeded with Philippine regions and cities.
- **Future Growth:** Adding a new country is as simple as adding a new top-level `Country` record and its children. The UI filters will naturally adapt.

---

## 4. Domain Models

### User
- Existing: `email_address`, `password_digest`.
- Added: `first_name`, `last_name`, `facebook_profile_url` (mandatory), `banned_at` (moderation), `admin` (boolean).

### Location
- `name` (string).
- `location_type` (enum: country, region, city).
- `parent_id` (self-reference).
- `country_code` (string, e.g., "PH").

### RidePost
The central entity representing an intent to travel.
- `user_id` (references User).
- `post_type` (enum: offering, requesting).
- `origin_id` (references Location - city level).
- `destination_id` (references Location - city level).
- `departure_time` (datetime).
- `seats` (integer).
- `notes` (rich text via ActionText for details like "No smoking", "I have a pet").
- `status` (enum: active, fulfilled, canceled).

### Report (Polymorphic)
- `reporter_id` (references User).
- `reportable` (polymorphic: `User` or `RidePost`).
- `reason` (string/enum: scam, spam, inappropriate, etc.).
- `description` (text).
- `status` (enum: pending, reviewed, action_taken, dismissed).

---

## 5. Technical Stack (Rails 8.1 Defaults)
- **Database:** SQLite 3 with performance tuning for production.
- **Background Jobs:** `SolidQueue` (no Redis).
- **Caching:** `SolidCache` (no Redis).
- **Frontend:** Hotwire (Turbo & Stimulus) using Rails Blocks UI components for your Rails app. No need to create components from scratch, but rather take them from ready-made ones.
  - **Turbo Frames:** Used for "live" searching and filtering without page reloads.
  - **Turbo Streams:** Used for real-time moderation updates or UI feedback.
- **Styling:** Tailwind 4.
- **Deployment:** Kamal 2 for zero-downtime deployment to a single VPS.

---

## 6. Implementation Roadmap
1. **Infrastructure:** Prepare `db/seeds.rb` with Philippine locations and setup `Location` model.
2. **User Profile:** Update `User` to enforce Facebook profile links and implement `banned_at` logic.
3. **The Board:** Implement `RidePost` creation and the main search/filter index.
4. **Trust Layer:** Build the "Contact on Facebook" integration and User Profile views.
5. **Moderation:** Implement the `Report` system and a basic Admin dashboard.
