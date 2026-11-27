import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'api/api_client.dart';
import 'l10n.dart';
import 'screens/apply_screen.dart';
import 'screens/account_shell.dart';
import 'screens/guest_shell.dart';
import 'screens/member_shell.dart';
import 'screens/sign_in_screen.dart';
import 'screens/splash_screen.dart';
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
  // Dates (weekdays, months) follow the chosen language.
  try {
    await initializeDateFormatting();
  } catch (_) {}
  Intl.defaultLocale = appLang.value;
  appLang.addListener(() => Intl.defaultLocale = appLang.value);
  final session = Session(api)..start();
  runApp(AbvpConnectApp(session: session));
}

class AbvpConnectApp extends StatelessWidget {
  const AbvpConnectApp({super.key, required this.session, this.splash = true});
  final Session session;

  /// Play the animated ABVP opening first (off in widget tests).
  final bool splash;

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
        home: _SplashGate(
          enabled: splash,
          session: session,
          child: ListenableBuilder(
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
              SessionStage.account => AccountShell(session: session),
            },
          ),
        ),
      ),
    );
  }
}

/// Shows [AbvpSplash] once per launch, then fades into the app as soon as both the animation
/// has played and the session has finished loading.
class _SplashGate extends StatefulWidget {
  const _SplashGate({
    required this.enabled,
    required this.session,
    required this.child,
  });
  final bool enabled;
  final Session session;
  final Widget child;

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  late bool _played = !widget.enabled;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final show =
            !_played ||
            widget.session.stage == SessionStage.loading && widget.enabled;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeOut,
          child: show
              ? AbvpSplash(
                  key: const ValueKey('splash'),
                  onDone: () {
                    if (mounted) setState(() => _played = true);
                  },
                )
              : KeyedSubtree(key: const ValueKey('app'), child: widget.child),
        );
      },
    );
  }
}
