import 'package:abvp_connect/api/api_client.dart';
import 'package:abvp_connect/main.dart';
import 'package:abvp_connect/state/session.dart';
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
}
