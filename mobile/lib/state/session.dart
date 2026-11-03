import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models.dart';

enum SessionStage { loading, signedOut, applying, waiting, member }

/// Who is signed in and where they are in the membership journey.
class Session extends ChangeNotifier {
  Session(this.api);

  final ApiClient api;
  Me? me;
  bool _loading = true;
  bool editingApplication = false;

  SessionStage get stage {
    if (_loading) return SessionStage.loading;
    final m = me;
    if (m == null) return SessionStage.signedOut;
    if (m.isMember) return SessionStage.member;
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

  Future<void> verifyOtp(String mobile, String code) async {
    final data = await api.post('/auth/verify-otp', {'mobile': mobile, 'code': code, 'device_name': 'mobile'});
    await api.saveToken(data['token'] as String);
    me = Me(data['user'] as Map<String, dynamic>);
    notifyListeners();
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
    await api.clearToken();
    me = null;
    editingApplication = false;
    notifyListeners();
  }
}
