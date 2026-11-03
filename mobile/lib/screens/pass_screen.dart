import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Daily-rotating member pass. Cached on the phone so it works with no signal.
class PassScreen extends StatefulWidget {
  const PassScreen({super.key, required this.session});
  final Session session;

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  String? _token;
  DateTime? _validUntil;
  bool _offline = false;
  String? _error;

  ApiClient get api => widget.session.api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await api.get('/me/qr') as Map<String, dynamic>;
      await api.writeCache('pass', jsonEncode(data));
      _apply(data, offline: false);
    } on ApiException catch (e) {
      final cached = await api.readCache('pass');
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        if (DateTime.parse(data['valid_until'] as String).isAfter(DateTime.now())) {
          return _apply(data, offline: true);
        }
      }
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _apply(Map<String, dynamic> data, {required bool offline}) {
    if (!mounted) return;
    setState(() {
      _token = data['token'] as String;
      _validUntil = DateTime.parse(data['valid_until'] as String).toLocal();
      _offline = offline;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.session.me!.profile!;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(children: [
              Expanded(child: Text('My pass', style: Theme.of(context).textTheme.headlineSmall)),
              if (_token != null)
                StatusPill(_offline ? 'Saved on phone' : 'Valid today',
                    color: AppColors.ok, background: AppColors.okSoft),
            ]),
            const SizedBox(height: 20),
            if (_error != null) ErrorBanner(_error!),
            if (_token != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.line)),
                child: Column(children: [
                  QrImageView(
                    data: _token!,
                    size: 240,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.ink),
                  ),
                  const SizedBox(height: 10),
                  Text(p.memberId ?? '', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AppColors.ink)),
                  Text(p.fullName, style: const TextStyle(color: AppColors.muted)),
                ]),
              ),
            const SizedBox(height: 16),
            Text(
              'Show this at the entry desk. The code changes every day, so an old screenshot will not work.'
              '${_validUntil != null ? ' Valid until midnight.' : ''}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
