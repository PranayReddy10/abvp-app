# ABVP Connect mobile app

Flutter app for Android and iOS.

```bash
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8000/api/v1
flutter analyze && flutter test
```

Flow: sign in with OTP → apply for membership → see application status (fix and resubmit if returned) → after approval, Home with member card, daily pass (works offline) and profile with privacy settings.

Code map: `lib/api/` HTTP client, `lib/state/session.dart` who is signed in and which stage they are at, `lib/screens/` one file per screen, `lib/theme.dart` colours from the design vision.
