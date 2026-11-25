/// The live server by default. For a server on your own computer:
/// flutter run --dart-define=API_URL=http://10.0.2.2:8000/api/v1   (Android emulator)
const String apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://api.abvpconnect.org/api/v1',
);

/// Google sign-in: the OAuth *web* client ID the API accepts as token audience.
/// Build with: --dart-define=GOOGLE_SERVER_CLIENT_ID=1234-abc.apps.googleusercontent.com
const String googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
);
