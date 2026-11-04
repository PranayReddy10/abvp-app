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

Next: teams and duties for event day (Phase 4). See the design vision for the full plan.

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
| Admin events | `admin/events` (list, create, edit, `publish`, `cancel`, `registrations`, `decide`, `guests`, `staff`, `live`) |
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
