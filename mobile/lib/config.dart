/// Build with: flutter run --dart-define=API_URL=https://api.abvpconnect.in/api/v1
const String apiBaseUrl = String.fromEnvironment(
  'API_URL',
  // Android emulator reaches the host machine on 10.0.2.2.
  defaultValue: 'http://10.0.2.2:8000/api/v1',
);
