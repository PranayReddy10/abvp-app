import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/loader.dart';

class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key, required this.session, required this.id});
  final Session session;
  final int id;

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  Key _key = UniqueKey();
  String? _error;

  ApiClient get api => widget.session.api;

  Future<void> _act(Future<void> Function() f) async {
    try {
      await f();
      setState(() {
        _error = null;
        _key = UniqueKey();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _join() => _act(() async {
    final data =
        await api.post('/meetings/${widget.id}/join') as Map<String, dynamic>;
    final link = data['link'] as String?;
    if (link != null) {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    }
  });

  Future<void> _addToCalendar(Map<String, dynamic> m) async {
    String utc(String iso) =>
        '${DateTime.parse(iso).toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
    final uri = Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': m['title'] as String,
      'dates':
          '${utc(m['starts_at'] as String)}/${utc(m['ends_at'] as String)}',
      'details': [m['agenda'], m['link']].whereType<String>().join('\n\n'),
      'location': (m['venue'] ?? m['link'] ?? '') as String,
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meeting')),
      body: Loader<Map<String, dynamic>>(
        key: _key,
        load: () async =>
            await api.get('/meetings/${widget.id}') as Map<String, dynamic>,
        builder: (context, m, reload) {
          final text = Theme.of(context).textTheme;
          final start = DateTime.parse(m['starts_at'] as String);
          final end = DateTime.parse(m['ends_at'] as String);
          final now = DateTime.now();
          final cancelled = m['status'] == 'cancelled';
          final joinable =
              !cancelled &&
              m['link'] != null &&
              now.isAfter(start.subtract(const Duration(minutes: 15))) &&
              now.isBefore(end);
          final past = now.isAfter(end);
          final counts = Map<String, dynamic>.from(m['rsvp_counts'] as Map);
          final isOrganiser = m['is_organiser'] == true;
          final items = (m['action_items'] as List)
              .cast<Map<String, dynamic>>();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  if (cancelled)
                    const StatusPill(
                      'Cancelled',
                      color: AppColors.bad,
                      background: AppColors.badSoft,
                    )
                  else if (joinable)
                    const StatusPill(
                      'Happening now',
                      color: AppColors.saffronInk,
                      background: AppColors.saffronSoft,
                    )
                  else if (past)
                    const StatusPill('Finished'),
                  if (m['kind'] == 'call') const StatusPill('One-to-one call'),
                  if (m['audience'] != null)
                    StatusPill(m['audience'] as String),
                ],
              ),
              const SizedBox(height: 10),
              Text(m['title'] as String, style: text.headlineSmall),
              const SizedBox(height: 12),
              _row(
                Icons.schedule,
                dayTime(m['starts_at'] as String),
                'Called by ${m['organiser'] ?? ''}',
              ),
              if (m['link'] != null)
                _row(
                  Icons.videocam_outlined,
                  'Online on ${providerNames[m['provider']] ?? 'a meeting link'}',
                  null,
                ),
              if (m['venue'] != null)
                _row(Icons.place_outlined, m['venue'] as String, null),
              const SizedBox(height: 12),
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 12),
              ],
              if (joinable)
                FilledButton.icon(
                  onPressed: _join,
                  icon: const Icon(Icons.videocam),
                  label: Text(
                    'Join on ${providerNames[m['provider']] ?? 'link'}',
                  ),
                ),
              if (!past && !cancelled && !isOrganiser) ...[
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'going', label: Text('Going')),
                    ButtonSegment(value: 'maybe', label: Text('Maybe')),
                    ButtonSegment(value: 'no', label: Text("Can't")),
                  ],
                  selected: {
                    if (m['my_rsvp'] != null && m['my_rsvp'] != 'pending')
                      m['my_rsvp'] as String,
                  },
                  emptySelectionAllowed: true,
                  onSelectionChanged: (s) => s.isEmpty
                      ? null
                      : _act(
                          () async => api.post('/meetings/${widget.id}/rsvp', {
                            'rsvp': s.first,
                          }),
                        ),
                ),
              ],
              if (!past && !cancelled) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _addToCalendar(m),
                  icon: const Icon(Icons.event_available),
                  label: const Text('Add to Google Calendar'),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '${counts['going']} going · ${counts['maybe']} maybe · ${counts['pending']} no reply${past ? ' · ${m['attended']} joined' : ''}',
                style: text.bodySmall,
              ),
              if ((m['agenda'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 18),
                Text('Agenda', style: text.titleMedium),
                const SizedBox(height: 6),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(m['agenda'] as String),
                  ),
                ),
              ],
              if ((m['minutes'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 18),
                Text('Minutes', style: text.titleMedium),
                const SizedBox(height: 6),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(m['minutes'] as String),
                  ),
                ),
              ],
              if (items.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Action items', style: text.titleMedium),
                ...items.map(
                  (a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      a['done'] == true
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: a['done'] == true ? AppColors.ok : AppColors.muted,
                    ),
                    title: Text(a['title'] as String),
                    subtitle: Text(
                      [
                        a['assignee'],
                        if (a['due_on'] != null)
                          'due ${day(a['due_on'] as String)}',
                      ].whereType<String>().join(' · '),
                    ),
                  ),
                ),
              ],
              if (m['people'] != null && m['kind'] == 'call') ...[
                const SizedBox(height: 18),
                ...(m['people'] as List).cast<Map<String, dynamic>>().map(
                  (p) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Initials(p['name'] as String? ?? '?'),
                    title: Text(p['name'] as String? ?? ''),
                    subtitle: Text(switch (p['rsvp']) {
                      'going' => 'Accepted',
                      'no' =>
                        "Can't make it${p['note'] != null ? ': ${p['note']}' : ''}",
                      'maybe' => 'Maybe',
                      _ => 'Not replied yet',
                    }),
                  ),
                ),
              ],
              if (isOrganiser && !past && !cancelled) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => _act(
                    () async => api.post('/meetings/${widget.id}/cancel'),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.bad),
                  child: const Text('Cancel this meeting'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(IconData icon, String title, String? sub) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.saffron),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (sub != null)
                Text(sub, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}
