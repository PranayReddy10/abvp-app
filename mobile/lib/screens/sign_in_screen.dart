import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

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
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.saffron,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to\nABVP Connect',
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in with your mobile number. New here? You can apply for membership after verifying.',
              style: text.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            if (_error != null) ...[
              ErrorBanner(_error!),
              const SizedBox(height: 16),
            ],
            if (_sentTo == null) ...[
              TextField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixText: '+91  ',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final masked = await widget.session.sendOtp(
                          _mobile.text,
                        );
                        setState(() => _sentTo = masked);
                      }),
                child: Text(_busy ? 'Sending…' : 'Send code'),
              ),
            ] else ...[
              Text(
                'Enter the 6-digit code sent to $_sentTo',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 12,
                  fontWeight: FontWeight.w700,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: ''),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () =>
                            widget.session.verifyOtp(_mobile.text, _code.text),
                      ),
                child: Text(_busy ? 'Checking…' : 'Verify and continue'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _sentTo = null;
                  _code.clear();
                }),
                child: const Text('Use a different number'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
