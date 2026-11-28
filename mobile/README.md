# ABVP Connect mobile app

Flutter app for Android and iOS.

```bash
flutter pub get
flutter run                     # uses the live server, api.abvpconnect.org
flutter run --dart-define=API_URL=http://10.0.2.2:8000/api/v1   # a server on your own computer (Android emulator)
flutter analyze && flutter test
```

Flow: sign in with OTP → apply for membership → see application status (fix and resubmit if returned) → after approval, Home with member card, daily pass (works offline) and profile with privacy settings.

Code map: `lib/api/` HTTP client, `lib/state/session.dart` who is signed in and which stage they are at, `lib/screens/` one file per screen, `lib/theme.dart` colours from the design vision.

## Analytics (Firebase / Google Analytics)

Off by default. Build with the Firebase values to switch it on – see `docs/analytics-seo-search.md`
on the `main` branch:

```
flutter build appbundle --release --dart-define=API_URL=https://api.abvpconnect.org/api/v1 \
  --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=FIREBASE_IOS_APP_ID=...
```

Search: the 🔍 button on Home (`lib/screens/search_screen.dart`, server `GET /search`).
