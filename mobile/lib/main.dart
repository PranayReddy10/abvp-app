import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'screens/apply_screen.dart';
import 'screens/member_shell.dart';
import 'screens/sign_in_screen.dart';
import 'screens/status_screen.dart';
import 'state/session.dart';
import 'theme.dart';

void main() {
  final session = Session(ApiClient())..start();
  runApp(AbvpConnectApp(session: session));
}

class AbvpConnectApp extends StatelessWidget {
  const AbvpConnectApp({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ABVP Connect',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => switch (session.stage) {
          SessionStage.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
          SessionStage.signedOut => SignInScreen(session: session),
          SessionStage.applying => ApplyScreen(session: session),
          SessionStage.waiting => StatusScreen(session: session),
          SessionStage.member => MemberShell(session: session),
        },
      ),
    );
  }
}
