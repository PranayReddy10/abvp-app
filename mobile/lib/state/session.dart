import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models.dart';
import 'location_sharer.dart';

enum SessionStage { loading, signedOut, applying, waiting, member, guest }

/// Who is signed in and where they are in the membership journey.
class Session extends ChangeNotifier {
  Session(this.api) : location = LocationSharer(api);

  /// The conference guide opens by itself once per app launch.
  bool guideLandingShown = false;

  final ApiClient api;
  final LocationSharer location;
  Me? me;
  bool _loading = true;
  bool editingApplication = false;

  SessionStage get stage {
    if (_loading) return SessionStage.loading;
    final m = me;
    if (m == null) return SessionStage.signedOut;
    if (m.isMember) return SessionStage.member;
    // Invited guests who have not applied see only their invitations and passes.
    if (m.isGuest && m.application == null && !editingApplication) {
      return SessionStage.guest;
    }
    final app = m.application;
    if (app == null || editingApplication) return SessionStage.applying;
    return SessionStage.waiting;
  }

  Future<void> start() async {
    if (await api.restoreToken()) {
      try {
        await refresh();
      } on ApiException catch (e) {
        if (e.status == 401) await api.clearToken();
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<String> sendOtp(String mobile) async {
    final data = await api.post('/auth/send-otp', {'mobile': mobile});
    return data['mobile'] as String;
  }

  Future<void> verifyOtp(
    String mobile,
    String code, {
    String? googleLinkToken,
  }) async {
    final data = await api.post('/auth/verify-otp', {
      'mobile': mobile,
      'code': code,
      'device_name': 'mobile',
      'google_link_token': ?googleLinkToken,
    });
    await api.saveToken(data['token'] as String);
    me = Me(data['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  bool _googleReady = false;

  /// Google sign-in. Returns null when signed in; otherwise the link token and email to
  /// carry into the one-time mobile verification that links this Google account.
  Future<({String linkToken, String email})?> signInWithGoogle() async {
    final g = GoogleSignIn.instance;
    if (!_googleReady) {
      await g.initialize(
        serverClientId: googleServerClientId.isEmpty
            ? null
            : googleServerClientId,
      );
      _googleReady = true;
    }
    if (!g.supportsAuthenticate()) {
      throw ApiException(
        'GOOGLE_UNSUPPORTED',
        'Google sign-in works in the Android and iPhone app. Use your mobile number here.',
      );
    }
    final account = await g.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw ApiException(
        'GOOGLE_NO_TOKEN',
        'Google did not return a sign-in token. Try again or use your mobile number.',
      );
    }
    final data = await api.post('/auth/google', {
      'id_token': idToken,
      'device_name': 'mobile',
    });
    if (data['linked'] == true) {
      await api.saveToken(data['token'] as String);
      me = Me(data['user'] as Map<String, dynamic>);
      notifyListeners();
      return null;
    }
    return (
      linkToken: data['link_token'] as String,
      email: (data['email'] as String?) ?? account.email,
    );
  }

  Future<void> refresh() async {
    me = Me(await api.get('/auth/me') as Map<String, dynamic>);
    notifyListeners();
  }

  void editApplication(bool editing) {
    editingApplication = editing;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await api.post('/auth/logout');
    } catch (_) {
      // Token may already be invalid; sign out locally anyway.
    }
    await location.stop();
    await api.clearToken();
    me = null;
    editingApplication = false;
    notifyListeners();
  }
}
