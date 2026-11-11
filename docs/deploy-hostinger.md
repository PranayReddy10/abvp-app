# Deploying on Hostinger shared hosting

This fits a Hostinger **Premium or Business** shared plan (PHP 8.3, SSH, cron, MySQL). Nothing here needs a server that stays running.

```
admin.abvpconnect.in  ->  static files from admin/dist
api.abvpconnect.in    ->  api/public  (Laravel)
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

- `api.abvpconnect.in` → `/home/USER/domains/abvpconnect.in/abvp-app/api/public`
- `admin.abvpconnect.in` → `/home/USER/domains/abvpconnect.in/public_html/admin` (or wherever you upload `admin/dist`)

The Laravel code (including `.env`) must stay outside any public folder. Only `api/public` is served.

Turn on **SSL** for both sub-domains (free Let's Encrypt in hPanel).

## 3. Upload and install the API

Over SSH:

```bash
cd ~/domains/abvpconnect.in
git clone https://github.com/PranayReddy10/abvp-app.git
cd abvp-app/api
composer install --no-dev --optimize-autoloader
cp .env.example .env
php artisan key:generate
```

Edit `.env`:

```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://api.abvpconnect.in
ADMIN_URL=https://admin.abvpconnect.in

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
php artisan abvp:make-admin 98XXXXXXXX "First Admin Name"
php artisan config:cache
php artisan route:cache
```

## 4. Cron

In **Advanced › Cron Jobs**, add a job that runs every minute:

```
cd /home/USER/domains/abvpconnect.in/abvp-app/api && php artisan schedule:run >> /dev/null 2>&1
```

This clears old OTP codes and expired sign-ins, and sends meeting reminders (a day before and 15 minutes before). Without it, reminders do not go out.

## 5. Admin panel

On your own computer:

```bash
cd admin
echo "VITE_API_URL=https://api.abvpconnect.in/api/v1" > .env.production
npm ci
npm run build
```

Upload everything inside `admin/dist` (including the hidden `.htaccess`) to the admin sub-domain's folder with hPanel's File Manager or SFTP.

## 6. Mobile app

```bash
cd mobile
flutter build appbundle --dart-define=API_URL=https://api.abvpconnect.in/api/v1
```

Upload `build/app/outputs/bundle/release/app-release.aab` to the Play Console. Signing keys and store listings are set up once in the Play Console.

## 7. SMS (OTP)

Indian SMS needs DLT registration. With MSG91:

1. Register the business entity and a sender ID on a DLT portal (Jio, Vodafone Idea or Airtel).
2. Register an OTP template, for example `{#var#} is your ABVP Connect sign-in code. It expires in 5 minutes. Do not share it.`
3. Create a Flow in MSG91 with that template and put its template ID in `MSG91_OTP_TEMPLATE_ID`.

Until DLT is approved, keep `SMS_DRIVER=log` on a staging copy only.

## 8. Google sign-in (optional)

Members can tap **Continue with Google** in the app and the admin panel. The first time, they also verify their mobile number once; after that Google signs them straight in. Identity in ABVP Connect stays the mobile number.

1. In Google Cloud Console → APIs & Services → Credentials, create OAuth client IDs:
   - **Web application** (used by the admin panel and as the app's "server client ID"). Add `https://admin.abvpconnect.in` under Authorised JavaScript origins.
   - **Android** with the app's package name and the SHA-1 of your Play signing key (from the Play Console).
   - **iOS**, if you publish on iPhone.
2. API `.env`: put every client ID, comma separated, in `GOOGLE_CLIENT_IDS`, then `php artisan config:cache`.
3. Admin build: add `VITE_GOOGLE_CLIENT_ID=<web client ID>` to `admin/.env.production` and rebuild.
4. App build: add `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client ID>` to the `flutter build` command. For iOS also add the iOS client's reversed ID as a URL scheme in `ios/Runner/Info.plist` (see the google_sign_in package README).

Until these are set, the Google button explains that it is not switched on yet, and mobile sign-in works as before. The API checks each Google token with Google over HTTPS, which Hostinger allows.

## 9. Photos on DigitalOcean Spaces (when ready)

The S3 driver Spaces needs is already in `composer.json`, so there is nothing to install. Everything is done from the admin panel by a super admin:

1. In DigitalOcean create a **private** Space (Bangalore, `blr1`, is closest), then an access key with read/write access to it.
2. Admin panel → **Settings** → Photo storage → **DigitalOcean Spaces**. Pick the region, enter the Space name, access key and secret.
3. **Test connection**, then **Save**. The panel writes, reads back and deletes a small test file first and refuses to switch if that fails, so uploads never break.
4. Press **Copy to Spaces** to copy photos saved earlier. It works 25 files at a time, so shared hosting never times out, and it can be run again safely. Files not yet copied keep loading from the server, and nothing is deleted from the server.

The secret is stored encrypted with `APP_KEY` (keep that key safe; if it changes, enter the secret again). Switching back to "This server" is one click. Photos are always served through short-lived signed links, never public URLs. `MEDIA_DISK` and `SPACES_*` in `.env` still work as a fallback when nothing is saved in Settings.

## Updating

```bash
cd ~/domains/abvpconnect.in/abvp-app && git pull
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
4. Point Nginx at `api/public` for `api.abvpconnect.in`, add HTTPS with Certbot.
5. Add one cron line: `* * * * * cd /var/www/abvp-app/api && php artisan schedule:run`. Optionally run `php artisan queue:work` under Supervisor.
6. Copy `storage/app` (member photos, post photos and event covers, if not on Spaces) to the VPS.
7. Change the `api` DNS record to the VPS address. The admin panel and the app keep working because they use the same `api.abvpconnect.in` address.

Keep the shared hosting running until the VPS has served one full day without errors, then switch it off.
