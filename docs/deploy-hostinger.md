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

## 8. Photos on DigitalOcean Spaces (when ready)

```bash
composer require league/flysystem-aws-s3-v3
```

Create a private Space in the Bangalore region (`blr1`), make an access key, fill the `SPACES_*` values and set `MEDIA_DISK=spaces`. Photos are always served through short-lived signed links, never public URLs.

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
6. Copy `storage/app` (member photos, if not on Spaces) to the VPS.
7. Change the `api` DNS record to the VPS address. The admin panel and the app keep working because they use the same `api.abvpconnect.in` address.

Keep the shared hosting running until the VPS has served one full day without errors, then switch it off.
