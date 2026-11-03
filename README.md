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

Next phases: Vibhag spaces, meetings and calls by link, circulars, activity reports (Phase 2), then events and passes (Phase 3). See the design vision for the full plan.

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
| Admin | `GET admin/dashboard`, `GET admin/applications`, `POST admin/applications/{id}/approve\|return\|reject`, `GET admin/members`, `admin/vibhags`, `admin/org-units`, `admin/role-assignments`, `admin/responsibilities`, `GET admin/audit-logs` |

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
