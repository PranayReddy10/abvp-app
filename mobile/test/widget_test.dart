import 'package:abvp_connect/api/api_client.dart';
import 'package:abvp_connect/main.dart';
import 'package:abvp_connect/state/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedOutSession extends Session {
  _SignedOutSession() : super(ApiClient());

  @override
  SessionStage get stage => SessionStage.signedOut;
}

void main() {
  testWidgets('signed-out users see the sign-in screen', (tester) async {
    await tester.pumpWidget(AbvpConnectApp(session: _SignedOutSession()));

    expect(find.text('ABVP Connect'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
  });
  signInModes();
}

class _CodesOffSession extends _SignedOutSession {
  _CodesOffSession() {
    otpEnabled = false;
  }
}

void signInModes() {
  testWidgets('a password tab sits next to the SMS code', (tester) async {
    await tester.pumpWidget(AbvpConnectApp(session: _SignedOutSession()));
    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();
    expect(find.text('Send code'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets(
    'with codes switched off, only password sign-in and sign-up show',
    (tester) async {
      await tester.pumpWidget(AbvpConnectApp(session: _CodesOffSession()));
      await tester.pumpAndSettle();
      expect(find.text('Send code'), findsNothing);
      expect(find.text('Code by SMS'), findsNothing);
      expect(find.text('New here? Create an account'), findsOneWidget);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('Full name'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Create account'),
        findsOneWidget,
      );
    },
  );
}
