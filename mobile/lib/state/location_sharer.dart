import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';

/// Sends this phone's position while the member has chosen to share, and only
/// while the app is open. Stops by itself when the chosen time runs out.
class LocationSharer extends ChangeNotifier {
  LocationSharer(this.api);

  final ApiClient api;
  int? sessionId;
  String? sharedWith;
  DateTime? expiresAt;
  String? error;
  Timer? _timer;

  bool get active =>
      sessionId != null && (expiresAt?.isAfter(DateTime.now()) ?? false);

  /// Asks for permission, then starts sharing. Returns an error message, or null.
  Future<String?> start({
    required int eventId,
    required int minutes,
    required String sharedWith,
    required String purpose,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Turn on location (GPS) on your phone first.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return 'Location permission is off. Allow it in your phone settings to share.';
    }

    try {
      final s = await api.post('/events/$eventId/location-sessions', {
        'minutes': minutes,
        'shared_with': sharedWith,
        'purpose': purpose,
      }) as Map<String, dynamic>;
      resume(s);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Pick up a session that is already running (e.g. after the app restarts).
  void resume(Map<String, dynamic>? session) {
    if (session == null) return;
    sessionId = session['id'] as int;
    sharedWith = session['shared_with'] as String;
    expiresAt = DateTime.parse(session['expires_at'] as String).toLocal();
    _timer?.cancel();
    _send();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _send());
    notifyListeners();
  }

  Future<void> stop() async {
    final id = sessionId;
    _clear();
    if (id != null) {
      try {
        await api.post('/location-sessions/$id/stop');
      } on ApiException {
        // Already ended on the server.
      }
    }
  }

  Future<void> _send() async {
    if (!active) return _clear();
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await api.post('/location-sessions/$sessionId/points', {
        'lat': p.latitude,
        'lng': p.longitude,
        'accuracy': p.accuracy,
      });
      error = null;
    } on ApiException catch (e) {
      if (e.status == 410 || e.status == 403) return _clear();
      error = e.message;
    } catch (_) {
      error = 'Could not read your location just now.';
    }
    notifyListeners();
  }

  void _clear() {
    _timer?.cancel();
    _timer = null;
    sessionId = null;
    expiresAt = null;
    notifyListeners();
  }
}
