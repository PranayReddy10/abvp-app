# Deploying on Hostinger shared hosting

This fits a Hostinger **Premium or Business** shared plan (PHP 8.3, SSH, cron, MySQL). Nothing here needs a server that stays running.

```
abvpconnect.org        ->  public_html            (the repository root: built website)
admin.abvpconnect.org  ->  public_html/admin      (built admin panel)
api.abvpconnect.org    ->  public_html/api/public (Laravel)
MySQL                 ->  Hostinger's own database on the same account
Photos                ->  DigitalOcean Spaces (optional at first; local private storage works for the pilot)
Cron (every minute)   ->  php artisan schedule:run
```

## 1. Check the plan

In hPanel:

- **Advanced › PHP Configuration:** PHP 8.3. Extensions `pdo_mysql`, `mbstring`, `openssl`, `fileinfo`, `gd` or `imagick`, `zip` on.
- **Advanced › SSH Access:** enable it and note the host, port and user.
- **Databases › MySQL:** create a database and user. Note the name, user and password. The host is `localhost`.

## 2. Sub-domains

In **Domains › Subdomains**, create `api` and `admin`. Then change each one's document root:

- `api.abvpconnect.org` → `/home/USER/domains/abvpconnect.org/public_html/api/public`
- `admin.abvpconnect.org` → `/home/USER/domains/abvpconnect.org/public_html/admin`

The `main` branch is cloned straight into `public_html` (see "Deploy with git over SSH" below). The website's `.htaccess` at the root refuses `/api`, `/admin`, `/source`, `/docs` and dot-files on the main domain, so the Laravel code, `.env` and logs are never served from `abvpconnect.org`. Only `api/public` is served, on its own sub-domain.

Turn on **SSL** for both sub-domains (free Let's Encrypt in hPanel).

## 3. Upload and install the API

Over SSH:

```bash
cd ~/domains/abvpconnect.org/public_html     # empty it first, keep nothing from earlier uploads
git clone https://github.com/PranayReddy10/abvp-app.git .
cd api
composer install --no-dev --optimize-autoloader
cp .env.example .env
php artisan key:generate
```

Edit `.env`:

```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://api.abvpconnect.org
ADMIN_URL=https://admin.abvpconnect.org
WEB_URL=https://abvpconnect.org,https://www.abvpconnect.org

DB_CONNECTION=mysql
DB_HOST=localhost
DB_DATABASE=u123_abvp
DB_USERNAME=u123_abvp
DB_PASSWORD=...

SMS_DRIVER=msg91
MSG91_AUTH_KEY=...
MSG91_OTP_TEMPLATE_ID=...
OTP_FIXED_CODE=

QR_SECRET=<64 random hex characters>
SESSION_DRIVER=file
CACHE_STORE=database
QUEUE_CONNECTION=database
```

Then:

```bash
php artisan migrate --force --seed
php artisan abvp:make-admin 98XXXXXXXX "First Admin Name" --password
php artisan config:cache
php artisan route:cache
```

### Admin sign-in

The admin panel offers two ways in:

- **Password:** mobile number + password. `--password` on `abvp:make-admin` asks for one (typed twice, hidden). Any admin can set or change theirs later under **My account** in the panel; changing it signs out their other devices. 5 wrong tries lock that account for 10 minutes.
- **Code on mobile:** a 6-digit SMS code (needs SMS set up, section 8).

Forgotten password: `php artisan abvp:set-password 98XXXXXXXX` (asks for the new one and signs the account out everywhere). To give someone else admin access, make them an admin in **Admins and roles**; they sign in once with a code, or you run `abvp:set-password` for them, and they set their own password under My account.

### Fill the empty database

`php artisan migrate --seed --force` only adds states, districts and Vibhags. Then:

```bash
php artisan abvp:make-admin 98XXXXXXXX "Your Name" --password   # the first super admin; asks for a password
php artisan abvp:setup-conference --helpline=98XXXXXXXX \
  --start="2026-12-26 09:00" --days=3 --venue="Venue name, Hyderabad" --lat=17.385 --lng=78.4867
```

The second command creates the national conference with the guide already laid out: Hyderabad's airport, stations and bus stands (with map pins), the emergency numbers 108/112/181, the usual offices and tourist places. It adds **no sample people**. Organisers then fill stays, food stalls, sessions, hall emergency leads and desk leads in the admin panel (Events → the conference → Guide) and switch on the guide and delegate registration when ready.

Do **not** run `db:seed --class=DemoSeeder` on the live server: it is sample data with made-up names and numbers, and it refuses to run when `APP_ENV=production`. To see the demo, use your own computer or a separate test copy with `APP_ENV=local`.

## 4. Cron

In **Advanced › Cron Jobs**, add a job that runs every minute:

```
cd /home/USER/domains/abvpconnect.org/public_html/api && php artisan schedule:run >> /dev/null 2>&1
```

This clears old OTP codes and expired sign-ins, and sends meeting reminders (a day before and 15 minutes before). Without it, reminders do not go out.

## 5. Admin panel

The built admin panel is committed in `admin/`, so `git pull` puts it in `public_html/admin`. Nothing to build on the server. To change it, edit `source/admin` and run `./build.sh` on your computer (next section).

## 6. Public website (abvpconnect.org)

The built website is the repository root (`index.html`, `.htaccess`, `assets/`, `fonts/`, `img/`). After changing `source/web` or `source/admin`, on your own computer:

```bash
./build.sh                                   # API https://api.abvpconnect.org/api/v1
VITE_GOOGLE_CLIENT_ID=<web client ID> ./build.sh   # with Google sign-in
```

Commit and push to `main`, then `git pull` on the server. The `.htaccess` makes links like `/guide/5` work on refresh. Add `https://abvpconnect.org` to the Google OAuth web client's Authorised JavaScript origins if Google sign-in is used, and make sure `WEB_URL` in the API's `.env` lists the site's address.

## 7. Mobile app

The app's code is on the `mobile` branch:

```bash
git checkout mobile
cd mobile
flutter build appbundle --dart-define=API_URL=https://api.abvpconnect.org/api/v1
```

Upload `build/app/outputs/bundle/release/app-release.aab` to the Play Console. Signing keys and store listings are set up once in the Play Console.

## 8. SMS (OTP)

Indian SMS needs DLT registration. With MSG91:

1. Register the business entity and a sender ID on a DLT portal (Jio, Vodafone Idea or Airtel).
2. Register an OTP template, for example `{#var#} is your ABVP Connect sign-in code. It expires in 5 minutes. Do not share it.`
3. Create a Flow in MSG91 with that template (variable `##otp##`).
4. Admin panel → **Settings → Sign-in** (super admin): choose **SMS through MSG91**, paste the auth key and template ID, **Send test** to your own number, then **Save**. The key is stored encrypted. (`SMS_DRIVER` / `MSG91_*` in `.env` still work as a fallback when nothing is saved there.)

The same card switches **sign in with a code on mobile** on or off. With it off, only password (and Google, if set up) sign-in work, and new members cannot sign up; the panel refuses to switch it off until you have set your own password under My account. **Testing: server log** sends no SMS and writes codes to `api/storage/logs/laravel.log` – use it only until MSG91 is ready.

## 9. Google sign-in (optional)

Members can tap **Continue with Google** in the app, the website and the admin panel. The first time, they also verify their mobile number once; after that Google signs them straight in. Identity in ABVP Connect stays the mobile number.

1. In Google Cloud Console → APIs & Services → Credentials, create OAuth client IDs:
   - **Web application** (used by the admin panel and as the app's "server client ID"). Add `https://admin.abvpconnect.org` and `https://abvpconnect.org` under Authorised JavaScript origins.
   - **Android** with the app's package name and the SHA-1 of your Play signing key (from the Play Console).
   - **iOS**, if you publish on iPhone.
2. API `.env`: put every client ID, comma separated, in `GOOGLE_CLIENT_IDS`, then `php artisan config:cache`.
3. Admin and website builds: run `VITE_GOOGLE_CLIENT_ID=<web client ID> ./build.sh`, commit and push.
4. App build: add `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client ID>` to the `flutter build` command. For iOS also add the iOS client's reversed ID as a URL scheme in `ios/Runner/Info.plist` (see the google_sign_in package README).

Until these are set, the Google button explains that it is not switched on yet, and mobile sign-in works as before. The API checks each Google token with Google over HTTPS, which Hostinger allows.

## 10. Photos on DigitalOcean Spaces (when ready)

The S3 driver Spaces needs is already in `composer.json`, so there is nothing to install. Everything is done from the admin panel by a super admin:

1. In DigitalOcean create a **private** Space (Bangalore, `blr1`, is closest), then an access key with read/write access to it.
2. Admin panel → **Settings** → Photo storage → **DigitalOcean Spaces**. Pick the region, enter the Space name, access key and secret.
3. **Test connection**, then **Save**. The panel writes, reads back and deletes a small test file first and refuses to switch if that fails, so uploads never break.
4. Press **Copy to Spaces** to copy photos saved earlier. It works 25 files at a time, so shared hosting never times out, and it can be run again safely. Files not yet copied keep loading from the server, and nothing is deleted from the server.

The secret is stored encrypted with `APP_KEY` (keep that key safe; if it changes, enter the secret again). Switching back to "This server" is one click. Photos are always served through short-lived signed links, never public URLs. `MEDIA_DISK` and `SPACES_*` in `.env` still work as a fallback when nothing is saved in Settings.

## Updating

### Deploy with git over SSH

First time (the folder must be empty apart from what Hostinger puts there):

```bash
cd ~/domains/abvpconnect.org/public_html
git init && git remote add origin git@github.com:PranayReddy10/abvp-app.git
git fetch origin main && git checkout -f -B main origin/main
```

Every update:

```bash
cd ~/domains/abvpconnect.org/public_html && git pull origin main
cd api && composer install --no-dev --optimize-autoloader && php artisan migrate --force && php artisan optimize
```

## Privacy jobs the cron runs

- `abvp:meeting-reminders` every minute.
- `abvp:prune-locations` every hour: deletes live-location points a day after sharing ends.
- Old OTP codes and expired sign-ins daily.

If cron is not set up, location points are not deleted. Check it after every move.

## Moving to a VPS

Shared hosting is fine for the pilot and for district and state events. Move the API to a VPS (Hostinger KVM 2 or similar: 2 vCPU, 8 GB RAM) when any of these is true:

- An event will have more than about 5,000 people using the app on the same day (gate scanning, meals and passes all hit the API at once).
- hPanel shows the account hitting its CPU or process limits ("508 resource limit reached" errors).
- You want push notifications sent instantly rather than by the minute.

The code does not change. Steps:

1. Create the VPS with Ubuntu 24.04. Install Nginx, PHP 8.3-FPM (with `pdo_mysql`, `mbstring`, `xml`, `gd`, `zip`, `intl`), MySQL 8 and Composer.
2. Export the database from hPanel (Databases → phpMyAdmin → Export) and import it on the VPS.
3. Clone the repository, copy `.env` from shared hosting, change `DB_HOST` to `127.0.0.1`, run `composer install --no-dev -o` and `php artisan migrate --force && php artisan optimize`.
4. Point Nginx at `api/public` for `api.abvpconnect.org`, add HTTPS with Certbot.
5. Add one cron line: `* * * * * cd /var/www/abvp-app/api && php artisan schedule:run`. Optionally run `php artisan queue:work` under Supervisor.
6. Copy `storage/app` (member photos, post photos and event covers, if not on Spaces) to the VPS.
7. Change the `api` DNS record to the VPS address. The admin panel and the app keep working because they use the same `api.abvpconnect.org` address.

Keep the shared hosting running until the VPS has served one full day without errors, then switch it off.
