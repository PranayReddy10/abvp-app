import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n.dart';
import '../state/session.dart';
import 'common.dart';

/// Bottom sheet to set a password, or change it (asks for the current one).
Future<void> showPasswordSheet(BuildContext context, Session session) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PasswordSheet(session: session),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('me.passwordSaved'))));
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({required this.session});
  final Session session;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  Future<void> _save() async {
    if (_new.text.length < 8) {
      setState(() => _error = tr('signin.short'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.setPassword(
        _new.text,
        current: widget.session.me?.hasPassword == true ? _current.text : null,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = widget.session.me?.hasPassword == true;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            has ? tr('me.passwordChange') : tr('me.passwordSet'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(tr('me.passwordHint')),
          const SizedBox(height: 16),
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          if (has) ...[
            TextField(
              controller: _current,
              obscureText: !_show,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: tr('me.currentPassword')),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _new,
            obscureText: !_show,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: tr('signin.newPassword'),
              suffixIcon: IconButton(
                icon: Icon(
                  _show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(
              _busy
                  ? '…'
                  : (has ? tr('me.passwordChange') : tr('me.passwordSet')),
            ),
          ),
        ],
      ),
    );
  }
}
