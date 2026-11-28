import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Google Analytics for the app, through Firebase.
///
/// Switched off until the Firebase project's values are given when the app is built:
///   flutter build apk --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_PROJECT_ID=...
///     --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_ANDROID_APP_ID=...
///     (--dart-define=FIREBASE_IOS_APP_ID=... for iPhone)
/// No google-services.json is needed. Without these values nothing is sent and nothing breaks.
/// Only screen names and kinds of action are sent – never names, mobiles or messages.
class Analytics {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _measurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
  );

  static FirebaseAnalytics? _fa;
  static bool get enabled => _fa != null;

  static String get _appId {
    if (kIsWeb) return _webAppId;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => _iosAppId,
      TargetPlatform.android => _androidAppId,
      _ => '',
    };
  }

  static Future<void> init() async {
    if (_apiKey.isEmpty ||
        _projectId.isEmpty ||
        _senderId.isEmpty ||
        _appId.isEmpty) {
      return;
    }
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
          measurementId: _measurementId.isEmpty ? null : _measurementId,
        ),
      );
      _fa = FirebaseAnalytics.instance;
      await _fa!.setAnalyticsCollectionEnabled(true);
    } catch (e) {
      debugPrint('Analytics off: $e');
      _fa = null;
    }
  }

  /// A screen was opened (Home, Community, Guide, Delegate form, Volunteer, Help, Search…).
  static void screen(String name) {
    _fa?.logScreenView(screenName: name, screenClass: name).catchError((_) {});
  }

  static void login(String method) =>
      _fa?.logLogin(loginMethod: method).catchError((_) {});
  static void signUp(String method) =>
      _fa?.logSignUp(signUpMethod: method).catchError((_) {});
  static void search(String term) =>
      _fa?.logSearch(searchTerm: term).catchError((_) {});

  /// Other actions: delegate_register, post_create, help_request.
  static void event(String name, [Map<String, Object>? params]) {
    _fa?.logEvent(name: name, parameters: params).catchError((_) {});
  }
}

/// Logs a screen view once when a screen is first shown.
mixin TrackScreen<T extends StatefulWidget> on State<T> {
  String get screenName;

  @override
  void initState() {
    super.initState();
    Analytics.screen(screenName);
  }
}
