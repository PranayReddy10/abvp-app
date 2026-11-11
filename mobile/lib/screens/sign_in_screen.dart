import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'guide/guide_hub.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.session});
  final Session session;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  String? _error;
  bool _busy = false;
  ({String linkToken, String email})? _googleLink;

  @override
  void initState() {
    super.initState();
    // Guests have no account: near a conference the guide opens straight away.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => maybeOpenGuide(context, widget.session),
    );
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await widget.session.signInWithGoogle();
      if (link != null && mounted) setState(() => _googleLink = link);
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        setState(
          () => _error = 'Google sign-in did not finish. Try again or use your mobile number.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Google sign-in is not available on this device. Use your mobile number.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.ground,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Brand band: saffron into ink, with the torch.
          Container(
            padding: EdgeInsets.fromLTRB(24, top + 36, 24, 44),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.saffron,
                  AppColors.saffronDeep,
                  AppColors.ink,
                ],
                stops: [0, 0.35, 1],
              ),
            ),
            child: FadeSlideIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'ABVP Connect',
                    style: TextStyle(
                      fontFamily: 'Anek',
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'एक सदस्य · एक पहचान · हर कार्यक्रम',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          // Form sheet.
          Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height * 0.62,
            ),
            decoration: const BoxDecoration(
              color: AppColors.ground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            transform: Matrix4.translationValues(0, -24, 0),
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
            child: FadeSlideIn(
              index: 2,
              child: AnimatedSwitcher(
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                child: _sentTo == null ? _mobileStep(text) : _codeStep(text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileStep(TextTheme text) => Column(
    key: const ValueKey('mobile'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GuideEntry(
        session: widget.session,
        padding: const EdgeInsets.only(bottom: 22),
      ),
      Text('Sign in', style: text.headlineSmall),
      const SizedBox(height: 6),
      Text(
        'Use your mobile number. New here? You can apply for membership after verifying.',
        style: text.bodyMedium?.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: 24),
      if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
      if (_googleLink != null) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.okSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            'Google account ${_googleLink!.email} is new here. Verify your mobile number once to link it. Next time Google signs you straight in.',
            style: const TextStyle(
              color: AppColors.ok,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      TextField(
        controller: _mobile,
        keyboardType: TextInputType.phone,
        autofillHints: const [AutofillHints.telephoneNumber],
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')),
        ],
        decoration: const InputDecoration(
          labelText: 'Mobile number',
          prefixIcon: Icon(Icons.phone_iphone),
          prefixText: '+91  ',
        ),
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: _busy
            ? null
            : () => _run(() async {
                final masked = await widget.session.sendOtp(_mobile.text);
                setState(() => _sentTo = masked);
              }),
        child: Text(_busy ? 'Sending…' : 'Send code'),
      ),
      if (_googleLink == null) ...[
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: text.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _busy ? null : _google,
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.ink,
            minimumSize: const Size.fromHeight(56),
          ),
          icon: const _GoogleMark(),
          label: const Text('Continue with Google'),
        ),
      ],
      const SizedBox(height: 18),
      Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'No passwords. A 6-digit code is sent by SMS each time.',
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    ],
  );

  Widget _codeStep(TextTheme text) => Column(
    key: const ValueKey('code'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Enter the code', style: text.headlineSmall),
      const SizedBox(height: 6),
      Text(
        'Sent to $_sentTo',
        style: text.bodyMedium?.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: 24),
      if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 16)],
      TextField(
        controller: _code,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        maxLength: 6,
        autofocus: true,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 28,
          letterSpacing: 14,
          fontWeight: FontWeight.w700,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(counterText: '', hintText: '••••••'),
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: _busy
            ? null
            : () => _run(
                () => widget.session.verifyOtp(
                  _mobile.text,
                  _code.text,
                  googleLinkToken: _googleLink?.linkToken,
                ),
              ),
        child: Text(_busy ? 'Checking…' : 'Verify and continue'),
      ),
      TextButton(
        onPressed: () => setState(() {
          _sentTo = null;
          _code.clear();
          _error = null;
        }),
        child: const Text('Use a different number'),
      ),
    ],
  );
}

/// Google's four-colour G, drawn so no image asset is needed.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 20, height: 20, child: CustomPaint(painter: _GPainter()));
}

class _GPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final w = size.width * 0.18;
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    const deg = 3.14159265 / 180;
    canvas.drawArc(r, -40 * deg, -100 * deg, false, p(const Color(0xFFEA4335)));
    canvas.drawArc(
      r,
      -140 * deg,
      -100 * deg,
      false,
      p(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(r, 120 * deg, -100 * deg, false, p(const Color(0xFF34A853)));
    canvas.drawArc(r, 20 * deg, -60 * deg, false, p(const Color(0xFF4285F4)));
    canvas.drawLine(
      Offset(size.width / 2, size.height / 2),
      Offset(size.width - 2, size.height / 2),
      p(const Color(0xFF4285F4)),
    );
  }

  @override
  bool shouldRepaint(_GPainter old) => false;
}
