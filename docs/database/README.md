# Database import files (no SSH needed)

For Hostinger when you cannot run `php artisan migrate`:

1. `abvp-connect-database.sql` – every table, plus states/districts and Vibhags. phpMyAdmin → select your database → Import → choose file → Go.
2. `abvp-connect-starter-data.sql` – your first super admin and the national conference with its guide. First replace `9000000000` with your mobile and `ADMIN NAME` with your name (Notepad → Replace), then import the same way.

Made from the migrations as of the commit that added them. If new migrations are added later, run `php artisan migrate --force` (or ask for fresh files).
