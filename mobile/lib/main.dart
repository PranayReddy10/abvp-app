import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/api_client.dart';
import 'l10n.dart';
import 'screens/apply_screen.dart';
import 'screens/guest_shell.dart';
import 'screens/member_shell.dart';
import 'screens/sign_in_screen.dart';
import 'screens/status_screen.dart';
import 'state/session.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  try {
    final saved = await api.readCache('lang');
    if (saved != null && appLanguages.any((l) => l.code == saved)) {
      appLang.value = saved;
    }
  } catch (_) {
    // First run or storage unavailable: the phone's language is used.
  }
  final session = Session(api)..start();
  runApp(AbvpConnectApp(session: session));
}

class AbvpConnectApp extends StatelessWidget {
  const AbvpConnectApp({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      key: appRootKey,
      valueListenable: appLang,
      builder: (context, lang, _) => MaterialApp(
        title: 'ABVP Connect',
        debugShowCheckedModeBanner: false,
        locale: Locale(lang),
        supportedLocales: [for (final l in appLanguages) Locale(l.code)],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(),
        home: ListenableBuilder(
          listenable: session,
          builder: (context, _) => switch (session.stage) {
            SessionStage.loading => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            SessionStage.signedOut => SignInScreen(session: session),
            SessionStage.applying => ApplyScreen(session: session),
            SessionStage.waiting => StatusScreen(session: session),
            SessionStage.member => MemberShell(session: session),
            SessionStage.guest => GuestShell(session: session),
          },
        ),
      ),
    );
  }
}
