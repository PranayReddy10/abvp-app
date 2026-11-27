import 'dart:convert';

import 'package:abvp_connect/api/api_client.dart';
import 'package:abvp_connect/l10n.dart';
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
      final Object data = path.endsWith('/auth/me')
          ? _me(member: member)
          : path.endsWith('/conference')
          ? _conference
          : path.endsWith('/me/seva')
          ? (member ? _seva : _emptySeva)
          : path.endsWith('/events/9/teams')
          ? _tree
          : path.endsWith('/events/9/delegate')
          ? {..._delegate, 'open': _delegateOpen}
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
    if (member) Icons.calendar_month_rounded,
    Icons.person_rounded,
    Icons.home_rounded,
  ];
  for (final icon in tabs) {
    await tester.tap(find.byIcon(icon).last);
    await settle();
    expect(tester.takeException(), isNull, reason: 'tab $icon');
    if (icon == Icons.person_rounded) {
      // No passes anywhere.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              RegExp(r'\bpass\b', caseSensitive: false).hasMatch(w.data ?? ''),
        ),
        findsNothing,
      );
      // The full profile editor opens from Me.
      await tester.tap(find.textContaining('Edit profile').first);
      await settle();
      expect(find.text('Add photo'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'edit profile');
      await tester.pageBack();
      await settle();
      expect(find.text('Gate check-in'), findsNothing);
    }
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
  'member_id': 'ABVP-TS-HYD-000009',
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
    await tester.scrollUntilVisible(
      find.text('Meeting at 6 pm'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Pramukh · Adhiveshan office · Karyalaya'),
      findsOneWidget,
    );
    expect(find.text('Meeting at 6 pm'), findsOneWidget);
    // The team is no longer on Home: it lives behind the Volunteer tile.
    expect(find.text('Karyalaya'), findsNothing);
    await tester.ensureVisible(find.text('Team'));
    await tester.pump();
    await tester.tap(find.text('Team'));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.scrollUntilVisible(
      find.text('Karyalaya'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Karyalaya'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Shri A Shyam Kiran'), findsOneWidget);
    expect(find.text('Adhiveshan office'), findsOneWidget);
    expect(find.textContaining('reachable'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Adhiveshan office'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Gowtham'), findsOneWidget);
    expect(find.text('KARYALAYA'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tapping a person opens their details as a popup.
    await tester.tap(find.text('Gowtham'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Using ABVP Connect'), findsOneWidget);
    expect(find.text('Adhiveshan office · Karyalaya'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('View profile'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'someone with no seva sees the team and the invitation, not a chat',
    (tester) async {
      await _openEveryTab(tester, member: false);
      expect(find.text('Volunteer'), findsOneWidget);
      await tester.tap(find.text('Volunteer'));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Want to volunteer'), findsNothing);
      expect(find.text('Karyalaya'), findsOneWidget);
    },
  );

  testWidgets('Delegate opens the form first, filled from the account', (
    tester,
  ) async {
    await _openEveryTab(tester, member: false);
    expect(find.text('Fill the delegate form'), findsOneWidget);
    await tester.tap(find.text('Delegate'));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Delegate registration'), findsOneWidget);
    expect(find.text('Fresh'), findsOneWidget); // first name
    expect(find.text('Person'), findsOneWidget); // surname
    expect(find.text('9800000000'), findsOneWidget);
    expect(find.text('Responsibility'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('The guide opens only after the delegate form', (tester) async {
    await _openEveryTab(tester, member: false);
    await tester.tap(find.text('Guide'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Fill the delegate form first'), findsOneWidget);
    await tester.tap(find.text('Fill the form'));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Delegate registration'), findsOneWidget);
  });

  testWidgets('Delegate explains clearly when registration is closed', (
    tester,
  ) async {
    _delegateOpen = false;
    addTearDown(() => _delegateOpen = true);
    await _openEveryTab(tester, member: false);
    await tester.tap(find.text('Delegate'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Delegate registration is not open yet'), findsOneWidget);
  });

  testWidgets('Help on Home opens the help page with an emergency call', (
    tester,
  ) async {
    await _openEveryTab(tester, member: false);
    await tester.tap(find.text('Help'));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Emergency – call now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home speaks Hindi and Telugu', (tester) async {
    addTearDown(() => appLang.value = 'en');
    await _openEveryTab(tester, member: true);
    appLang.value = 'hi';
    rebuildAll(tester.element(find.byType(Scaffold).first));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final w in ['मार्गदर्शिका', 'चित्र दीर्घा', 'सहायता', 'प्रतिनिधि', 'आज का विचार']) {
      expect(find.text(w), findsWidgets, reason: w);
    }
    expect(find.text('Guide'), findsNothing);
    appLang.value = 'te';
    rebuildAll(tester.element(find.byType(Scaffold).first));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final w in ['మార్గదర్శి', 'సహాయం', 'నేటి సూక్తి']) {
      expect(find.text(w), findsWidgets, reason: w);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home starts with my details and quick buttons', (tester) async {
    await _openEveryTab(tester, member: true);
    expect(find.text('Fresh Person'), findsWidgets);
    expect(find.textContaining('ABVP-IN-000001'), findsWidgets);
    for (final b in ['Guide', 'Gallery', 'Team', 'Help', 'DAYS']) {
      expect(find.text(b), findsOneWidget, reason: b);
    }
    expect(find.text('My pass'), findsNothing);
    expect(find.text('THOUGHT FOR TODAY'), findsOneWidget);
  });
}

var _delegateOpen = true;

final _delegate = {
  'event': _conference,
  'open': true,
  'registration': null,
  'prefill': {
    'full_name': 'Fresh Person',
    'first_name': 'Fresh',
    'surname': 'Person',
    'mobile': '9800000000',
    'email': null,
    'gender': null,
    'prant': 'Telangana',
    'institution': null,
    'responsibility': null,
  },
  'options': {
    'prants': ['Delhi', 'Telangana'],
    'arrival_points': ['Secunderabad Railway Station'],
    'modes': [
      {'key': 'train', 'label': 'Train'},
      {'key': 'bus', 'label': 'Bus'},
    ],
    'food': <dynamic>[],
  },
};
