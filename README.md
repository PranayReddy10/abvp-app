# ABVP Connect

One app for every karyakarta: membership, profiles, Vibhags, meetings and events.
This repository holds all three parts.

| Folder | What it is | Built with | Runs on |
|---|---|---|---|
| `api/` | The server and database rules | Laravel 13, PHP 8.3 | Hostinger shared hosting, `api.abvpconnect.in` |
| `admin/` | Web admin panel for state, district and Vibhag offices | React 19, Vite | Static files on Hostinger, `admin.abvpconnect.in` |
| `mobile/` | Android and iOS app for members | Flutter 3.47 | Play Store and App Store |
| `docs/` | Design vision and deployment guide | | |

The design vision is in [`docs/design/design-vision.html`](docs/design/design-vision.html). Hosting steps are in [`docs/deploy-hostinger.md`](docs/deploy-hostinger.md).

## What works now (Phase 1: members)

- **Sign in with OTP.** Mobile number plus a 6-digit SMS code. No passwords. Limited to 3 codes per number every 10 minutes and 5 wrong tries per code.
- **Apply for membership.** Name, date of birth, state › district › unit, college, Vibhags, photo.
- **Review by the right office.** An application goes to the admins whose area contains the chosen unit. A district admin sees only their district; a state admin sees the whole state. Approve, return for correction (with a note), or reject (with a note). Every decision is in the history and the audit log.
- **Member ID** on approval, numbered per district: `ABVP-TS-HYD-000001`.
- **Member pass.** A QR code that changes daily and holds no personal data. Saved on the phone so it works without signal.
- **Profile.** Bio, skills, languages, links, Vibhags, dayitva (posts held) and privacy settings for phone, email, college and birthday.
- **Admin panel.** Dashboard, approval queue, member search, Vibhag list (the ~70 Vibhags are data, not code), admin roles, audit log.
- **Roles with areas.** Every admin role is tied to an area. You can only give roles below your own, inside your own area.

## What works now (Phase 2: organisation work)

- **Vibhag spaces.** Members join one or many Vibhags. Each space has coordinators, updates and a list of members nearby. Only that Vibhag's coordinators can post.
- **Meetings and calls by link.** Admins call a baithak for an area (and optionally one Vibhag); every approved member in that audience is invited. Any member can propose a one-to-one call from the directory. Paste any https link: Google Meet, Zoom, Teams, Jitsi and YouTube Live are recognised by name. Going / Maybe / Can't, "Add to Google Calendar", attendance recorded when people tap Join, minutes and action items with owners and due dates. Reminders go out a day before and 15 minutes before.
- **Circulars with read receipts.** Issued at any level to everyone below it, with an optional PDF. The issuer sees the read rate and can remind those who have not read it.
- **Activity reports.** A unit reports a programme with date, students, colleges and up to 6 photos.
- **Directory.** Find office bearers by name, college or Vibhag. Phone numbers are never listed; contact goes through a call request.
- **In-app notifications** for invitations, call requests, replies, reminders, action items and circular reminders.
- **Analysis in the admin panel.** For the admin's area over 3, 6 or 12 months: members, approval rate and time to decide, meetings and attendance, circular read rate, units active in the last 30 days, month-by-month charts, a table of every area inside it with "needs attention" flags (applications waiting over 7 days, no activity for 30+ days), drill-down into any area, members by Vibhag, field work by programme type, age and gender, and who is reviewing applications and how fast. Tables download as CSV.

To see the analysis with example data on your computer:

```bash
cd api
php artisan db:seed --class=DemoSeeder
```

It adds about 115 example members across Telangana with six months of history. It refuses to run in production.

## What works now (Phase 3: events)

- **Events.** Admins create an event as a draft (type, dates, venue, map link, seats, closing date, instructions, contact person) and publish it. Changing the time or venue tells everyone registered; cancelling tells everyone with the reason.
- **Who can register.** Open to all approved members, or limited to an area and/or a Vibhag. Every member still sees every published event; the app says clearly whether they can register and why not.
- **Registration.** One tap. Seats are counted inside a database lock so two people cannot take the last seat. When full, people join a waitlist and move up automatically (with a notification) when someone cancels. Optional approval per registration.
- **Event pass.** A QR code holding only a signed registration number, no personal data. It is saved on the phone and works without signal. Today's pass sits on top of the Pass tab.
- **Gate check-in.** Members put on an event's gate team get "Gate check-in" under Me. Scan with the camera, type the code, or find someone by name. Green = welcome, amber = already checked in (with time and gate), red = do not let in. A person is never checked in twice, and people not on the list are sent to the coordinator rather than added at the gate.
- **No signal at the gate.** The confirmed list is kept on the scanner's phone. Scans made offline show who the person is, are saved, and are sent in one go when the signal is back; each is confirmed or flagged.
- **Guests.** Invite chief guests and speakers by name and mobile. They sign in with OTP and see only their invitations and pass; they do not become members. Guest and member arrivals are counted separately.
- **Live arrivals board** in the admin panel, refreshing every 15 seconds: arrived vs expected, members vs guests, arrivals every 30 minutes, by gate, and the latest arrivals. Registrations list with filters (to approve, waitlist, arrived, not arrived), approve/reject, "Mark arrived", and CSV download.
- **Analysis** now includes events held, registrations and turnout.

## What works now (Phase 4: event-day operations)

- **Teams and duties.** Coordinators make teams (Registration desk, Hospitality, Stage and sound, Parking, Food…) with a team lead, and give duties to one or many people at once: what, where to report, from when to when, instructions. Only people registered for the event or on its team can get duties.
- **Clash check.** If someone already has a duty at that time (at any event), the coordinator sees who and where, and can choose others or assign anyway.
- **Accept or decline.** Each person accepts, or says they can't with a reason; the team lead and coordinator are told at once, and the duty can be reassigned (both people are notified).
- **On the day.** "I've reached, starting now", "Mark as done", "Report a problem". The person sees whom to report to with a call button. Team leads see their whole team in the app, can call anyone, and can update statuses.
- **Event-day Home.** On the day, Home opens with a saffron card: today's duty, where, when to report and to whom, a call button, and the pass.
- **Help requests.** Anyone at the event can ask for help (medical, registration, stay, food, transport, venue, lost and found). Medical requests show "Call 108 first" and go to the top of the coordinators' help desk. Replies come back into the app.
- **Announcements.** Coordinators send a message to everyone at the event or only to volunteers; it shows as a notification and on the event page.
- **Admin event page** gains Duties (status bar, filters, reassign, cancel, CSV), Help desk (oldest and medical first, reply, resolve) and Announcements tabs. The live board now shows duty progress and open help requests.
- **Coordinators** can be admins of the area or members added to the event team with the Coordinator role.

## What works now (Phase 5: logistics)

- **Travel details.** Each participant says how they are coming (train, bus, flight, own vehicle), the train or bus number, when and where they arrive, and whether they need a pickup and a place to stay.
- **Arrivals and transport.** Coordinators see every arrival in time order with filters (need pickup, no vehicle yet, picked up, need stay), add buses and vans with seats, pickup point, departure time and driver, and assign people in bulk. A vehicle cannot be over-filled. People are told which vehicle and where to wait; drivers' numbers show in the app. "Picked up" is marked from the board.
- **Stay.** Add hostels or halls (for everyone, women only or men only) with any number of rooms and beds. "Allocate rooms automatically" fills beds for everyone who asked, keeps people from the same unit together and follows the women/men rule; or place people by hand. Room check-in and removal from the board. Everyone is told their room and sees it in the app with a map link.
- **Food.** Add meal sessions (Day 1 Breakfast, Lunch…). Counter volunteers pick the meal in Gate check-in and scan the same event pass: one plate per person per meal, enforced by the database; a second scan shows when and at which counter they were served. Meal scans need a signal so a plate is never given twice.
- **Live location, only by choice.** A participant can share their location with event coordinators or only their team lead, for 30 minutes to 4 hours, with a reason ("coming late by bus"). It is sent about once a minute only while the app is open, stops by itself, can be stopped any time, and is deleted from the server a day after sharing ends. Coordinators see who is sharing and open the position in Google Maps. No map SDK or paid service is needed.
- **Live board** adds beds taken, pickups pending, the meal being served now and how many people are sharing location.

## Verified profiles and working contacts

- **Blue tick.** State and district admins (and above) can mark a member's identity as verified from Members, with a note on how it was checked. It is recorded in the audit log and the member is notified. The tick shows next to their name in the app (profile, member card, directory, duties, teams) and in the admin panel. Only approved members can be verified, and the tick can be removed.
- **People who work together can reach each other.** A phone number normally follows the member's own privacy choice. During a current event it is also visible to: teammates on the same duty team, the team lead, the person they report to, the event's coordinators, and admins of their area. The duty screen lists "Your team" with phone numbers and call buttons; coordinators see phone numbers in the Duties and Registrations tabs. The exception ends a day after the event.

## What works now (Phase 6: community feed)

- **Post like on Twitter.** Approved members write short posts (up to 500 characters) with up to 4 photos, and choose who sees them: all members, only their district, or one of their Vibhags. #Hashtags become links, and the week's trending tags appear above the feed.
- **Like, reply, repost, quote.** Replies notify the author. A repost shares a post as it is; a quote adds your own words on top.
- **Follow.** Member profiles show posts, followers and following, with Follow, Schedule a call and (when allowed) Call buttons. The Following tab shows only people you follow. New followers are notified.
- **Safe by default.** Members report posts with a reason (abusive, false information, spam, private details, other). Five reports hide a post until someone reviews it. Members can post or reply at most 10 times every 10 minutes.
- **Moderation in the admin panel.** "Community" lists reported and hidden posts from members in the admin's area, with reasons and notes. Hide (the author is told why), restore, or dismiss reports; every action is in the audit log. The sidebar shows how many are waiting.
- **Photo storage setting.** Super admins choose in Settings whether photos are kept on the Hostinger server or in DigitalOcean Spaces, with a connection test before switching, an encrypted secret, and a batch "Copy to Spaces" for earlier photos.
- **Event cover photos.** Upload a cover in the event's Details tab; it appears on the event cards and event page in the app.

## Design

- App (refreshed after the travel-app references): light grey background with large white rounded cards and no borders, a floating dark pill navigation bar (Home, Community, Pass, Calendar, Me) whose active tab turns saffron, round icon buttons, a "Good morning, Name 👋" greeting with the member's area, a pill search with a saffron filter button, icon chips that turn dark when selected, photo event cards with a round arrow, and event passes styled as boarding passes with a perforated edge.
- App (earlier): bundled Mukta and Anek Devanagari fonts (work offline and in Hindi), new theme, gradient member card, page transitions, list items that cascade in, press feedback, animated loading placeholders, and a new sign-in screen. Respects the phone's "reduce motion" setting.
- Admin (refreshed after the dashboard references): Plus Jakarta Sans type with Hindi falling back to Mukta, a solid saffron pill for the active menu item, a top bar with a wide member search, round icon buttons, a light/dark switch and the signed-in admin, pastel stat tiles with big numbers, icons and trend tags, white cards with softer table headers and soft status tags.
- Admin (earlier): sidebar with icons and an active marker, softer cards with depth and hover lift, pages and sections that fade in, bars that grow into place, shimmering loading rows, a two-panel sign-in page, and verified badges. Respects "reduce motion".

All phases in the design vision, plus the community feed, are now built. See `docs/deploy-hostinger.md` for going live, and its last section for moving to a VPS when national events need it.

## Run it on your computer

You need PHP 8.3 with Composer, Node 20+, and Flutter 3.47.

### API

```bash
cd api
cp .env.example .env
composer install
php artisan key:generate
touch database/database.sqlite
php artisan migrate --seed
php artisan abvp:make-admin 9848012345 "Your Name"
php artisan serve
```

With `OTP_FIXED_CODE=123456` in `.env`, every sign-in code is `123456` on your computer. Real codes are written to `storage/logs/laravel.log` when that line is removed.

Run the tests:

```bash
cd api && php artisan test
```

### Admin panel

```bash
cd admin
cp .env.example .env
npm install
npm run dev
```

Open http://localhost:5173 and sign in with the mobile number you made admin.

### Mobile app

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8000/api/v1
```

`10.0.2.2` is how the Android emulator reaches your computer. On a real phone, use your computer's network address.

## API at a glance

All routes start with `/api/v1`. Responses look like `{ "success": true, "data": …, "meta": { "request_id": … } }`; errors look like `{ "success": false, "error": { "code": "FORBIDDEN_SCOPE", "message": "…" } }`.

| | Route |
|---|---|
| Sign in | `POST auth/send-otp`, `POST auth/verify-otp`, `GET auth/me`, `POST auth/logout` |
| Lookups | `GET org/units?parent_id=`, `GET vibhags` |
| Me | `GET/PATCH me/profile`, `PUT me/privacy`, `POST me/photo`, `GET me/qr` |
| Membership | `POST membership/application` |
| Directory | `GET members/{memberId}`, `POST qr/verify` |
| Vibhag spaces | `GET spaces`, `GET spaces/{id}`, `POST/DELETE spaces/{id}/join`, `GET/POST spaces/{id}/posts`, `GET spaces/{id}/members` |
| Meetings | `GET/POST meetings`, `GET meetings/{id}`, `POST meetings/{id}/rsvp\|join\|cancel`, `PUT meetings/{id}/minutes`, `GET meetings/{id}/calendar.ics`, `GET me/action-items`, `POST action-items/{id}/done` |
| Circulars and reports | `GET circulars`, `GET circulars/{id}`, `POST activity-reports`, `GET me/activity-reports`, `GET directory`, `GET notifications` |
| Events | `GET events`, `GET events/{id}`, `POST events/{id}/register\|cancel-registration`, `GET me/passes` |
| Gate check-in | `GET me/check-in-events`, `GET events/{id}/roster`, `POST events/{id}/check-in`, `POST events/{id}/check-in/batch`, `GET events/{id}/check-in/search`, `POST events/{id}/registrations/{reg}/check-in` |
| Event day | `GET me/duties`, `POST duties/{id}/respond\|progress`, `GET me/teams`, `GET events/{id}/announcements`, `POST events/{id}/help`, `GET me/help`, `POST help/{id}/reply` |
| Admin operations | `admin/events/{id}/teams`, `admin/events/{id}/duties` (assign with clash check, edit/reassign, cancel), `admin/events/{id}/help`, `admin/events/{id}/announcements` |
| Logistics | `GET events/{id}/my-logistics`, `PUT events/{id}/travel`, `GET events/{id}/meal-sessions`, `POST events/{id}/meal-sessions/{m}/serve`, `POST events/{id}/location-sessions`, `POST location-sessions/{id}/points\|stop`, `GET events/{id}/team-locations` |
| Admin logistics | `GET admin/events/{id}/logistics`, `stays` (+ `auto-allocate`), `rooms/{room}/allocate`, `allocations/{a}`, `meal-sessions`, `vehicles`, `arrivals` (+ `assign`, `picked-up`) |
| Community | `GET feed?tab=for_you\|following&tag=&before=`, `GET feed/trending`, `POST posts` (multipart, `photos[]`), `GET/DELETE posts/{id}`, `POST posts/{id}/like\|comments\|report`, `DELETE comments/{id}`, `POST members/{memberId}/follow`, `GET members/{memberId}/posts` |
| Admin events | `admin/events` (list, create, edit, `publish`, `cancel`, `cover`, `registrations`, `decide`, `guests`, `staff`, `live`) |
| Admin settings | `GET/PUT admin/settings/storage`, `POST admin/settings/storage/test`, `POST admin/settings/storage/copy` (super admin) |
| Admin moderation | `GET admin/moderation?status=reported\|hidden`, `POST admin/moderation/posts/{id}` (`hide` with reason, `restore`, `dismiss`) |
| Admin | `GET admin/analytics?months=&unit_id=`, `admin/circulars` (+ `/remind`), `GET admin/meetings`, `GET admin/activity-reports`, `GET admin/dashboard`, `GET admin/applications`, `POST admin/applications/{id}/approve\|return\|reject`, `GET admin/members`, `admin/vibhags`, `admin/org-units`, `admin/role-assignments`, `admin/responsibilities`, `GET admin/audit-logs` |

## Roles

| Role | Rank | Can |
|---|---|---|
| Super Admin | 100 | Everything |
| National Admin | 90 | Everything except platform settings; manages the Vibhag list and reads the audit log |
| State Admin | 70 | Review, members, add districts and units, assign roles in their state |
| District Admin | 50 | Review, members, assign roles in their district |
| Vibhag Admin | 40 | See members in their area |
| Verification Officer | 30 | Review applications in their area |

Role names and rules live in `api/config/abvp.php`.
