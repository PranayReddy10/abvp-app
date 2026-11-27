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
      final path = req.url.path;
      final Object? data = path.endsWith('/auth/me')
          ? _me(member: member)
          : path.endsWith('/conference')
          ? _conference
          : path.endsWith('/me/seva')
          ? (member ? _seva : _emptySeva)
          : path.endsWith('/events/9/teams')
          ? _tree
          : path.contains('/teams/') && path.endsWith('/messages')
          ? _chat
          : path.endsWith('/me/qr')
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
  await tester.pumpWidget(AbvpConnectApp(session: s, splash: false));
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

final _conference = {
  'id': 9,
  'title': '72nd National Conference – Bhagyanagar',
  'venue': 'Bhagyanagar',
  'starts_at': '2026-12-24T03:30:00+00:00',
  'ends_at': '2026-12-27T12:30:00+00:00',
  'helpline': '9000000000',
  'guide_enabled': false,
  'delegate_registration_open': false,
  'has_teams': true,
};
final _person = {
  'id': 1,
  'name': 'Gowtham',
  'role': 'pramukh',
  'role_label': 'Pramukh',
  'mobile': '+919800000001',
  'has_mobile': true,
  'linked': true,
  'note': null,
  'photo_url': null,
};
final _tree = {
  'event': _conference,
  'signed_in': true,
  'ghats': [
    {
      'id': 10,
      'name': 'Karyalaya',
      'name_local': null,
      'color': '#E3620C',
      'heads': [
        {
          'id': 2,
          'name': 'Shri A Shyam Kiran',
          'role': 'ghat_pramukh',
          'role_label': 'Ghat Pramukh',
          'mobile': null,
          'has_mobile': false,
          'linked': false,
          'note': null,
          'photo_url': null,
        },
      ],
      'departments': [
        {
          'id': 11,
          'name': 'Adhiveshan office',
          'name_local': null,
          'people': [_person],
        },
      ],
      'counts': {'departments': 1, 'people': 2},
    },
  ],
};
final _seva = {
  'event': _conference,
  'is_admin': false,
  'places': [
    {
      'member_id': 1,
      'role': 'pramukh',
      'role_label': 'Pramukh',
      'team': {
        'id': 11,
        'name': 'Adhiveshan office',
        'kind': 'department',
        'color': '#E3620C',
      },
      'ghat': {'id': 10, 'name': 'Karyalaya'},
      'can_manage': true,
    },
  ],
  'chats': [
    {
      'team_id': 11,
      'name': 'Adhiveshan office',
      'kind': 'department',
      'ghat': 'Karyalaya',
      'color': '#E3620C',
      'can_manage': true,
      'last': null,
    },
  ],
  'meetings': <dynamic>[],
  'tasks': <dynamic>[],
  'announcements': [
    {
      'id': 5,
      'team': 'Karyalaya',
      'body': 'Meeting at 6 pm',
      'by': 'Shri A Shyam Kiran',
      'at': '2026-12-20T12:30:00+00:00',
    },
  ],
};
final _emptySeva = {
  'event': _conference,
  'places': <dynamic>[],
  'chats': <dynamic>[],
  'meetings': <dynamic>[],
  'tasks': <dynamic>[],
  'announcements': <dynamic>[],
};
final _chat = {
  'team': {
    'id': 11,
    'name': 'Adhiveshan office',
    'kind': 'department',
    'ghat': 'Karyalaya',
    'color': '#E3620C',
  },
  'can_manage': true,
  'people': 3,
  'messages': [
    {
      'id': 1,
      'body': 'Reached the office',
      'announcement': false,
      'by': 'Ravi',
      'mine': false,
      'photo_url': null,
      'at': '2026-12-20T12:30:00+00:00',
    },
  ],
};

void main() {
  testWidgets(
    'a brand-new member opens every tab without errors',
    (t) => _openEveryTab(t, member: true),
  );
  testWidgets(
    'a new account (not a member yet) opens every tab without errors',
    (t) => _openEveryTab(t, member: false),
  );

  testWidgets('home shows my seva, the team, a ghat and its people', (
    tester,
  ) async {
    await _openEveryTab(tester, member: true);
    expect(find.text('72nd National Conference – Bhagyanagar'), findsOneWidget);
    expect(
      find.text('Pramukh · Adhiveshan office · Karyalaya'),
      findsOneWidget,
    );
    expect(find.text('Meeting at 6 pm'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Karyalaya'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Karyalaya'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Shri A Shyam Kiran'), findsOneWidget);
    expect(find.text('Adhiveshan office'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'someone with no seva sees the team and the invitation, not a chat',
    (tester) async {
      await _openEveryTab(tester, member: false);
      expect(find.text('Seva team'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Want to do seva'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Want to do seva'), findsOneWidget);
      expect(find.text('My seva'), findsNothing);
    },
  );
}
