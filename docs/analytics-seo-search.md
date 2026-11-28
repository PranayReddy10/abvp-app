# Google Analytics, Search Console, SEO and search

Everything is built in. What is left needs **your Google account**: create the properties below and paste the IDs where shown. No code change or rebuild is needed for the website; the app needs one build with the Firebase values.

---

## 1. Google Analytics for the website (5 minutes)

1. Open <https://analytics.google.com> → **Admin** → **Create** → **Property**. Name: `ABVP Connect`, time zone India, currency INR.
2. **Data streams** → **Add stream** → **Web** → URL `https://abvpconnect.org`, name `Website`.
3. Copy the **Measurement ID** (it looks like `G-ABC123XYZ`).
4. Admin panel → **Settings** → **Website – analytics and Google** → paste it → **Save**.

That is all. The website loads Google Analytics on the next page view. You will see visitors under **Reports → Realtime** within a minute.

What is sent:
- a page view for every page (the website is a single-page app, so each page change is counted correctly);
- these actions: `sign_up`, `login` (password, SMS code or Google), `delegate_register`, `post_create`, `help_request` (chat or ticket), `search`.

No names, mobile numbers, emails or messages are ever sent. To switch analytics off, clear the ID and save.

## 2. Google Search Console – get the site on Google (10 minutes)

1. Open <https://search.google.com/search-console> → **Add property**.
2. Choose **Domain** and type `abvpconnect.org` (covers www, api and admin too).
3. Google shows a **TXT record**. In Hostinger: **Domains → abvpconnect.org → DNS / Nameservers → Add record** → type `TXT`, name `@`, value = what Google gave → save. Back in Search Console press **Verify** (DNS can take a few minutes to an hour).
   - Prefer the “URL prefix” method instead? Choose **HTML tag**, copy the tag and paste it into Admin → Settings → Website → *Google Search Console verification*, save, then press Verify.
4. In Search Console → **Sitemaps** → add `https://abvpconnect.org/sitemap.xml` → **Submit**.
5. Optional, for Bing and other engines: <https://www.bing.com/webmasters> → *Import from Google Search Console* (or paste the `msvalidate.01` code in the same Settings card).

Google usually starts showing the site within a few days. Search for `site:abvpconnect.org` to check.

## 3. Google Analytics for the app (through Firebase)

App analytics in Google go through Firebase, which reports into the same Google Analytics.

1. Open <https://console.firebase.google.com> → **Add project** → choose the existing Google Analytics account (and the `ABVP Connect` property from step 1 if offered).
2. **Add app → Android**: package name `org.abvpconnect.app`. Download `google-services.json` (keep it private; you do not need to add it to the code).
3. For iPhone: **Add app → iOS**: bundle ID `org.abvpconnect.app`.
4. From `google-services.json` (or Project settings → Your apps) take these values:

| Build value | Where to find it |
|---|---|
| `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |
| `FIREBASE_PROJECT_ID` | `project_info.project_id` |
| `FIREBASE_SENDER_ID` | `project_info.project_number` |
| `FIREBASE_ANDROID_APP_ID` | `client[0].client_info.mobilesdk_app_id` (starts `1:…:android:…`) |
| `FIREBASE_IOS_APP_ID` | the iOS app's App ID (starts `1:…:ios:…`) |

5. Build the app with them (from the `mobile` branch):

```
flutter build appbundle --release \
  --dart-define=API_URL=https://api.abvpconnect.org/api/v1 \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_SENDER_ID=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=FIREBASE_IOS_APP_ID=...
```

Without these values the app works exactly as before and sends nothing.

The app sends screen views (Home, Community, Me, Guide and each guide section, Delegate form, Volunteer, Help, Edit profile, Search) and the same actions as the website: `login`, `sign_up`, `delegate_register`, `post_create`, `help_request`, `search`. No personal details.

Play Store: in *App content → Data safety* declare **App activity – App interactions** and **Device or other IDs**, collected for **Analytics**, not shared.

## 4. SEO – what is already done on the website

- Title, description, keywords, canonical link and language tags on every page; each page sets its own title and description.
- Share previews (WhatsApp, Facebook, X, Telegram, LinkedIn) with a 1200×630 image: `og-image.jpg`.
- Structured data for Google: Organization, WebSite with a search box, the mobile app, and an **Event** for the conference and each event page (dates, venue, organiser) so Google can show it as an event.
- `robots.txt` (personal pages such as My space, sign-in and the delegate form are kept out of Google) and `sitemap.xml`, rebuilt on every build with all published events.
- Sign-in-only pages (guide, volunteer, My space) are marked *noindex*.
- The admin panel and the API tell search engines not to index them.
- `site.webmanifest`, icons and theme colour, so the site can be added to a phone's home screen.

## 5. Search inside the website and the app

- Website: the 🔍 button in the menu (or `abvpconnect.org/search?q=…`).
- App: the 🔍 button at the top of Home, next to the bell. Works in English, Hindi and Telugu.

What each person can find:

| Who | Results |
|---|---|
| Anyone | Upcoming published events |
| Signed in | + volunteers of the conference team (with call), members, community posts they can already see |
| Delegates (form filled) | + places in the conference guide: stays, food halls, transport desks, sessions, exhibition, emergency… |

Server: `GET /api/v1/search?q=…` (2–60 characters). Admin setting: `GET/PUT /api/v1/admin/settings/website` (super admins). Public: `GET /api/v1/site`.
