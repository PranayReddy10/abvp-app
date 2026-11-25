import 'dart:convert';

import 'package:abvp_connect/api/api_client.dart';
import 'package:abvp_connect/main.dart';
import 'package:abvp_connect/models.dart';
import 'package:abvp_connect/state/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A brand-new account: nothing joined, nothing registered, no posts of their own.
Map<String, dynamic> _me({required bool member}) => {
  'id': 1,
  'name': 'Fresh Person',
  'mobile': '+919800000000',
  'email': null,
  'prant': null,
  'institution': null,
  'occupation': null,
  'gender': null,
  'is_member': member,
  'has_password': true,
  'locale': 'en',
  'profile': {
    'member_id': 'ABVP-IN-000001',
    'full_name': 'Fresh Person',
    'gender': null,
    'date_of_birth': '2003-03-03',
    'photo_url': null,
    'org_unit': {
      'id': 5,
      'name': 'Hyderabad',
      'label': 'Telangana › Hyderabad',
    },
    'institution': null,
    'course': null,
    'study_year': null,
    'bio': null,
    'languages': <String>[],
    'skills': <String>[],
    'links': <dynamic>[],
    'privacy': {
      'mobile': 'nobody',
      'email': 'office_bearers',
      'institution': 'members',
      'date_of_birth': 'nobody',
    },
    'membership_status': member ? 'approved' : 'draft',
    'verified': false,
    'social': {'followers': 0, 'following': 0, 'posts': 0},
    'verified_at': null,
    'approved_at': member ? '2026-11-25T10:00:00+00:00' : null,
    'vibhags': <dynamic>[],
    'responsibilities': <dynamic>[],
  },
  'application': null,
  'roles': <dynamic>[],
  'is_guest': false,
  'can_check_in': false,
  'permissions': <String>[],
};

class _Fresh extends Session {
  _Fresh(super.api, this._stage);
  final SessionStage _stage;
  @override
  SessionStage get stage => _stage;
}

Future<void> _openEveryTab(WidgetTester tester, {required bool member}) async {
  final api = ApiClient(
    client: MockClient((req) async {
      // Everything a new account loads is empty, except its pass.
      final Object data = req.url.path.endsWith('/auth/me')
          ? _me(member: member)
          : req.url.path.endsWith('/me/qr')
          ? {
              'token': 'T',
              'member_id': 'ABVP-IN-000001',
              'expires_at': '2026-11-26T00:00:00+00:00',
            }
          : <dynamic>[];
      return http.Response(
        jsonEncode({'success': true, 'data': data, 'meta': {}}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  final s = _Fresh(api, member ? SessionStage.member : SessionStage.account)
    ..me = Me(_me(member: member))
    ..guideLandingShown = true;
  await tester.pumpWidget(AbvpConnectApp(session: s));
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  await settle();
  expect(tester.takeException(), isNull);
  final tabs = [
    Icons.forum_rounded,
    Icons.qr_code_2_rounded,
    if (member) Icons.calendar_month_rounded,
    Icons.person_rounded,
    Icons.home_rounded,
  ];
  for (final icon in tabs) {
    await tester.tap(find.byIcon(icon).last);
    await settle();
    expect(tester.takeException(), isNull, reason: 'tab $icon');
  }
}

void main() {
  testWidgets(
    'a brand-new member opens every tab without errors',
    (t) => _openEveryTab(t, member: true),
  );
  testWidgets(
    'a new account (not a member yet) opens every tab without errors',
    (t) => _openEveryTab(t, member: false),
  );
}
