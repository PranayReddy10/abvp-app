import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/loader.dart';

const helpCategories = {
  'medical': 'Medical',
  'registration': 'Registration or pass',
  'stay': 'Stay',
  'food': 'Food',
  'transport': 'Transport',
  'venue': 'Venue or directions',
  'lost': 'Lost and found',
  'other': 'Something else',
};

class AskHelpScreen extends StatefulWidget {
  const AskHelpScreen({
    super.key,
    required this.session,
    required this.eventId,
    required this.eventTitle,
  });
  final Session session;
  final int eventId;
  final String eventTitle;

  @override
  State<AskHelpScreen> createState() => _AskHelpScreenState();
}

class _AskHelpScreenState extends State<AskHelpScreen> {
  String _category = 'other';
  final _message = TextEditingController();
  final _where = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.session.api.post(
        '/events/${widget.eventId}/help',
        {
          'category': _category,
          'message': _message.text.trim(),
          if (_where.text.trim().isNotEmpty) 'location': _where.text.trim(),
        },
      ) as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r['emergency_note'] as String? ??
                'Sent. The event team will reply in the app.',
          ),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MyHelpScreen(session: widget.session),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask for help')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(widget.eventTitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in helpCategories.entries)
                ChoiceChip(
                  label: Text(c.value),
                  selected: _category == c.key,
                  selectedColor: c.key == 'medical'
                      ? AppColors.badSoft
                      : AppColors.saffronSoft,
                  onSelected: (_) => setState(() => _category = c.key),
                ),
            ],
          ),
          if (_category == 'medical') ...[
            const SizedBox(height: 12),
            const ErrorBanner(
              'Emergency? Call 108 first. This request alerts the event team, but it does not replace an ambulance.',
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _message,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'What do you need?'),
          ),
          TextField(
            controller: _where,
            decoration: const InputDecoration(
              labelText: 'Where are you? (optional)',
              hintText: 'Hall B entrance',
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _busy ? null : _send,
            child: Text(_busy ? 'Sending…' : 'Send to event team'),
          ),
        ],
      ),
    );
  }
}

class MyHelpScreen extends StatefulWidget {
  const MyHelpScreen({super.key, required this.session});
  final Session session;

  @override
  State<MyHelpScreen> createState() => _MyHelpScreenState();
}

class _MyHelpScreenState extends State<MyHelpScreen> {
  Key _key = UniqueKey();

  Future<void> _reply(Map<String, dynamic> h) async {
    final c = TextEditingController();
    final body = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reply'),
        content: TextField(controller: c, autofocus: true, maxLines: 3),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (body == null || body.isEmpty) return;
    try {
      await widget.session.api.post('/help/${h['id']}/reply', {'body': body});
      setState(() => _key = UniqueKey());
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My help requests')),
      body: Loader<List<dynamic>>(
        key: _key,
        load: () async => await widget.session.api.get('/me/help') as List,
        builder: (context, rows, _) => rows.isEmpty
            ? ListView(
                children: const [
                  EmptyNote(
                    'No help requests. At an event, open the event and tap "Ask for help".',
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  for (final h in rows.cast<Map<String, dynamic>>())
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${h['category_label']} · ${h['event']['title']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                                switch (h['status']) {
                                  'resolved' => const StatusPill(
                                    'Resolved',
                                    color: AppColors.ok,
                                    background: AppColors.okSoft,
                                  ),
                                  'in_progress' => const StatusPill(
                                    'Being handled',
                                    color: Color(0xFF2E55C9),
                                    background: Color(0xFFE6ECFB),
                                  ),
                                  _ => const StatusPill(
                                    'Sent',
                                    color: AppColors.warn,
                                    background: AppColors.warnSoft,
                                  ),
                                },
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              h['message'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              ago(h['at'] as String),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            for (final r
                                in (h['replies'] as List)
                                    .cast<Map<String, dynamic>>())
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: r['from_team'] == true
                                      ? AppColors.saffronSoft
                                      : AppColors.ground,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${r['from_team'] == true ? r['by'] : 'You'}: ${r['body']}',
                                ),
                              ),
                            if (h['status'] != 'resolved')
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _reply(h),
                                  child: const Text('Reply'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
