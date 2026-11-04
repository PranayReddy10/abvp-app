import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import 'meeting_screen.dart';

/// Propose a one-to-one call with another member: time plus any meeting link.
class ScheduleCallScreen extends StatefulWidget {
  const ScheduleCallScreen({super.key, required this.session, required this.memberId, required this.name});
  final Session session;
  final String memberId;
  final String name;

  @override
  State<ScheduleCallScreen> createState() => _ScheduleCallScreenState();
}

class _ScheduleCallScreenState extends State<ScheduleCallScreen> {
  final _title = TextEditingController();
  final _link = TextEditingController();
  late DateTime _start;
  int _minutes = 30;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = DateTime.now().add(const Duration(days: 1));
    _start = DateTime(t.year, t.month, t.day, 19);
    _link.addListener(() => setState(() {}));
  }

  Future<void> _pick() async {
    final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 120)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (t == null) return;
    setState(() => _start = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.session.api.post('/meetings', {
        'kind': 'call',
        'title': _title.text.trim().isEmpty ? 'Call with ${widget.name}' : _title.text.trim(),
        'mode': 'online',
        'link': _link.text.trim(),
        'starts_at': _start.toUtc().toIso8601String(),
        'ends_at': _start.add(Duration(minutes: _minutes)).toUtc().toIso8601String(),
        'member_ids': [widget.memberId],
      }) as Map<String, dynamic>;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MeetingScreen(session: widget.session, id: data['id'] as int)));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = providerFor(_link.text);
    return Scaffold(
      appBar: AppBar(title: Text('Call ${widget.name.split(' ').first}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
        TextField(controller: _title, decoration: InputDecoration(labelText: 'What is it about?', hintText: 'Call with ${widget.name}')),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.schedule),
          label: Text(DateFormat('EEE d MMM, h:mm a').format(_start)),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [ButtonSegment(value: 15, label: Text('15 min')), ButtonSegment(value: 30, label: Text('30 min')), ButtonSegment(value: 60, label: Text('1 hour'))],
          selected: {_minutes},
          onSelectionChanged: (s) => setState(() => _minutes = s.first),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _link,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: 'Meeting link',
            hintText: 'https://meet.google.com/…',
            suffixIcon: provider == null ? null : const Icon(Icons.check_circle, color: AppColors.ok),
            helperText: provider == null ? 'Paste a Google Meet, Zoom, Teams, Jitsi or any https link' : 'Recognised: ${providerNames[provider]}',
          ),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 12)],
        FilledButton(onPressed: _busy || provider == null ? null : _submit, child: Text(_busy ? 'Sending…' : 'Send call request')),
        const SizedBox(height: 8),
        Text('${widget.name.split(' ').first} gets a notification and can accept or say they can\'t make it.',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
