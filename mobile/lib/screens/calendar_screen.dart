import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/loader.dart';
import '../widgets/motion.dart';
import 'directory_screen.dart';
import 'duties_screen.dart';
import 'events_screen.dart';
import 'meeting_screen.dart';

/// Meetings, calls and action items in one list.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.session});
  final Session session;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String _when = 'upcoming';
  Key _key = UniqueKey();

  Future<(List, List)> _load() async {
    final api = widget.session.api;
    final meetings = await api.get('/meetings?when=$_when') as List;
    final items = _when == 'upcoming'
        ? await api.get('/me/action-items') as List
        : <dynamic>[];
    return (meetings, items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DirectoryScreen(session: widget.session),
            ),
          );
          setState(() => _key = UniqueKey());
        },
        icon: const Icon(Icons.videocam_outlined),
        label: const Text('Schedule a call'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'upcoming', label: Text('Meetings')),
                ButtonSegment(value: 'events', label: Text('Events')),
                ButtonSegment(value: 'duties', label: Text('Duties')),
                ButtonSegment(value: 'past', label: Text('Past')),
              ],
              selected: {_when},
              onSelectionChanged: (s) => setState(() {
                _when = s.first;
                _key = UniqueKey();
              }),
            ),
          ),
          if (_when == 'events')
            Expanded(
              child: EventsList(key: _key, session: widget.session),
            )
          else if (_when == 'duties')
            Expanded(
              child: DutiesList(key: _key, session: widget.session),
            )
          else
            Expanded(
              child: Loader<(List, List)>(
                key: _key,
                load: _load,
                builder: (context, data, reload) {
                  final (meetings, items) = data;
                  final open = items
                      .cast<Map<String, dynamic>>()
                      .where((a) => a['done'] != true)
                      .toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    children: [
                      if (open.isNotEmpty) ...[
                        Text(
                          'To do',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        ...open.map(
                          (a) => Card(
                            child: CheckboxListTile(
                              value: false,
                              onChanged: (_) async {
                                await widget.session.api.post(
                                  '/action-items/${a['id']}/done',
                                );
                                await reload();
                              },
                              title: Text(
                                a['title'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                [
                                  if (a['due_on'] != null)
                                    '${a['overdue'] == true ? 'Overdue' : 'Due'} ${day(a['due_on'] as String)}',
                                  'From ${a['meeting']['title']}',
                                ].join(' · '),
                                style: TextStyle(
                                  color: a['overdue'] == true
                                      ? AppColors.bad
                                      : AppColors.muted,
                                ),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (meetings.isEmpty)
                        EmptyNote(
                          _when == 'upcoming'
                              ? 'No meetings coming up. Invitations from your Vibhag and unit will appear here.'
                              : 'No past meetings yet.',
                        ),
                      ...staggered(
                        meetings
                            .cast<Map<String, dynamic>>()
                            .map<Widget>(
                              (m) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: MeetingTile(
                                  session: widget.session,
                                  m: m,
                                  onBack: reload,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class MeetingTile extends StatelessWidget {
  const MeetingTile({
    super.key,
    required this.session,
    required this.m,
    required this.onBack,
  });
  final Session session;
  final Map<String, dynamic> m;
  final Future<void> Function() onBack;

  @override
  Widget build(BuildContext context) {
    final call = m['kind'] == 'call';
    final cancelled = m['status'] == 'cancelled';
    final rsvp = m['my_rsvp'] as String?;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MeetingScreen(session: session, id: m['id'] as int),
            ),
          );
          await onBack();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: cancelled
                      ? AppColors.line
                      : call
                      ? const Color(0xFF2E55C9)
                      : AppColors.saffron,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['title'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        dayTime(m['starts_at'] as String),
                        if (m['mode'] != 'in_person')
                          providerNames[m['provider']] ?? 'Online'
                        else
                          m['venue'] ?? '',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (cancelled)
                const StatusPill(
                  'Cancelled',
                  color: AppColors.bad,
                  background: AppColors.badSoft,
                )
              else if (m['is_organiser'] == true)
                const StatusPill('You called it')
              else if (rsvp == 'going')
                const StatusPill(
                  'Going',
                  color: AppColors.ok,
                  background: AppColors.okSoft,
                )
              else if (rsvp == 'pending')
                const StatusPill(
                  'Reply',
                  color: AppColors.warn,
                  background: AppColors.warnSoft,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
