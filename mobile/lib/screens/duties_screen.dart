import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/loader.dart';
import '../widgets/motion.dart';

/// [forLead] words it for someone looking at another person's duty.
StatusPill dutyPill(String status, {bool forLead = false}) => switch (status) {
  'assigned' => StatusPill(
    forLead ? 'Not accepted yet' : 'Please accept',
    color: AppColors.warn,
    background: AppColors.warnSoft,
  ),
  'accepted' => const StatusPill(
    'Accepted',
    color: Color(0xFF2E55C9),
    background: Color(0xFFE6ECFB),
  ),
  'in_progress' => const StatusPill(
    'On duty',
    color: Color(0xFF2E55C9),
    background: Color(0xFFE6ECFB),
  ),
  'done' => const StatusPill(
    'Done',
    color: AppColors.ok,
    background: AppColors.okSoft,
  ),
  'blocked' => StatusPill(
    forLead ? 'Problem' : 'Problem reported',
    color: AppColors.bad,
    background: AppColors.badSoft,
  ),
  'declined' => StatusPill(
    forLead ? "Can't do it" : "You can't do this",
    color: AppColors.bad,
    background: AppColors.badSoft,
  ),
  _ => const StatusPill('Cancelled'),
};

class DutiesList extends StatelessWidget {
  const DutiesList({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return Loader<List<dynamic>>(
      load: () async => await session.api.get('/me/duties') as List,
      builder: (context, rows, reload) => rows.isEmpty
          ? ListView(
              children: const [
                EmptyNote(
                  'No duties. When an event team gives you a duty, it appears here with where to go and whom to report to.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => FadeSlideIn(
                index: i,
                child: DutyCard(
                  session: session,
                  d: rows[i] as Map<String, dynamic>,
                  onChanged: reload,
                ),
              ),
            ),
    );
  }
}

class DutyCard extends StatelessWidget {
  const DutyCard({
    super.key,
    required this.session,
    required this.d,
    required this.onChanged,
  });
  final Session session;
  final Map<String, dynamic> d;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final status = d['status'] as String;
    final stripe = switch (status) {
      'done' => AppColors.ok,
      'blocked' || 'declined' => AppColors.bad,
      'assigned' => AppColors.warn,
      _ => AppColors.saffron,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DutyScreen(session: session, duty: d),
            ),
          );
          await onChanged();
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: stripe, width: 4)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      d['title'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  dutyPill(status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${dayTime(d['starts_at'] as String)} · ${d['location'] ?? d['event']?['venue'] ?? ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                d['event']?['title'] as String? ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (d['report_to'] != null)
                Text(
                  'Report to ${d['report_to']['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One duty: when, where, whom to report to, and the buttons for each stage.
class DutyScreen extends StatefulWidget {
  const DutyScreen({super.key, required this.session, required this.duty});
  final Session session;
  final Map<String, dynamic> duty;

  @override
  State<DutyScreen> createState() => _DutyScreenState();
}

class _DutyScreenState extends State<DutyScreen> {
  late Map<String, dynamic> d = widget.duty;
  bool _busy = false;
  String? _error;

  ApiClient get api => widget.session.api;

  Future<void> _post(String path, Map<String, dynamic> body) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await api.post(path, body) as Map<String, dynamic>;
      setState(() => d = r);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask(String title, String hint) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = d['status'] as String;
    final text = Theme.of(context).textTheme;
    final report = d['report_to'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('Duty')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Align(alignment: Alignment.centerLeft, child: dutyPill(status)),
          const SizedBox(height: 8),
          Text(d['title'] as String, style: text.headlineSmall),
          if (d['team'] != null)
            Text('${d['team']['name']} team', style: text.bodySmall),
          const SizedBox(height: 14),
          _row(
            Icons.schedule,
            dayTime(d['starts_at'] as String),
            'until ${dayTime(d['ends_at'] as String)}',
          ),
          _row(
            Icons.place_outlined,
            (d['location'] ?? d['event']?['venue'] ?? '') as String,
            d['event']?['title'] as String?,
          ),
          if (report != null)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                leading: Initials(report['name'] as String? ?? '?'),
                title: NameWithBadge(
                  report['name'] as String? ?? '',
                  verified: report['verified'] == true,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    'Report to',
                    report['phone'],
                  ].whereType<String>().join(' · '),
                ),
                trailing: report['phone'] == null
                    ? null
                    : IconButton.filledTonal(
                        icon: const Icon(Icons.call),
                        onPressed: () =>
                            launchUrl(Uri.parse('tel:${report['phone']}')),
                      ),
              ),
            ),
          if ((d['instructions'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Text('Instructions', style: text.titleMedium),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(d['instructions'] as String),
              ),
            ),
          ],
          if ((d['team_contacts'] as List?)?.isNotEmpty == true) ...[
            const SizedBox(height: 18),
            Text('Your team', style: text.titleMedium),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: [
                  for (final c
                      in (d['team_contacts'] as List)
                          .cast<Map<String, dynamic>>())
                    ListTile(
                      leading: Initials(c['name'] as String? ?? '?'),
                      title: NameWithBadge(
                        c['name'] as String? ?? '',
                        verified: c['verified'] == true,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          c['role'],
                          c['duty'],
                          c['location'],
                          c['phone'],
                        ].whereType<String>().join(' · '),
                      ),
                      trailing: c['phone'] == null
                          ? null
                          : IconButton.filledTonal(
                              tooltip: 'Call',
                              icon: const Icon(Icons.call),
                              onPressed: () =>
                                  launchUrl(Uri.parse('tel:${c['phone']}')),
                            ),
                    ),
                ],
              ),
            ),
          ],
          if (d['status_note'] != null) ...[
            const SizedBox(height: 12),
            Text('Note: ${d['status_note']}', style: text.bodySmall),
          ],
          const SizedBox(height: 20),
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          if (status == 'assigned') ...[
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _post('/duties/${d['id']}/respond', {
                      'response': 'accept',
                    }),
              child: const Text("I'll do this"),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final reason = await _ask(
                        "Can't do this duty?",
                        'Tell the coordinator why, so they can find someone else',
                      );
                      if (reason != null && reason.isNotEmpty) {
                        await _post('/duties/${d['id']}/respond', {
                          'response': 'decline',
                          'reason': reason,
                        });
                      }
                    },
              child: const Text("I can't do this"),
            ),
          ],
          if (status == 'accepted' || status == 'blocked')
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _post('/duties/${d['id']}/progress', {
                      'status': 'in_progress',
                    }),
              icon: const Icon(Icons.play_arrow),
              label: Text(
                status == 'blocked'
                    ? 'Problem solved, back on duty'
                    : "I've reached, starting now",
              ),
            ),
          if (status == 'in_progress')
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _post('/duties/${d['id']}/progress', {
                      'status': 'done',
                    }),
              icon: const Icon(Icons.check),
              label: const Text('Mark as done'),
            ),
          if (status == 'accepted' || status == 'in_progress') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final note = await _ask(
                        'Report a problem',
                        'What is wrong? Your team lead is told right away.',
                      );
                      if (note != null && note.isNotEmpty) {
                        await _post('/duties/${d['id']}/progress', {
                          'status': 'blocked',
                          'note': note,
                        });
                      }
                    },
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report a problem'),
            ),
          ],
        ],
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

/// Team leads: every duty in their teams, with quick status changes and a call button.
class MyTeamsScreen extends StatefulWidget {
  const MyTeamsScreen({super.key, required this.session});
  final Session session;

  @override
  State<MyTeamsScreen> createState() => _MyTeamsScreenState();
}

class _MyTeamsScreenState extends State<MyTeamsScreen> {
  Key _key = UniqueKey();

  String _summary(List<Map<String, dynamic>> duties) {
    int n(String s) => duties.where((d) => d['status'] == s).length;
    return '${duties.length} people · ${n('in_progress')} on duty · ${n('done')} done · '
        '${n('blocked') + n('declined')} ${n('blocked') + n('declined') == 1 ? 'problem' : 'problems'} · ${n('assigned')} not accepted';
  }

  Future<void> _set(
    BuildContext context,
    Map<String, dynamic> d,
    String s,
  ) async {
    try {
      await widget.session.api.post('/duties/${d['id']}/progress', {
        'status': s,
        if (s == 'blocked') 'note': 'Reported by team lead',
      });
      setState(() => _key = UniqueKey());
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My teams')),
      body: Loader<List<dynamic>>(
        key: _key,
        load: () async => await widget.session.api.get('/me/teams') as List,
        builder: (context, teams, _) => teams.isEmpty
            ? ListView(
                children: const [
                  EmptyNote('You are not leading a team at any current event.'),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  for (final t in teams.cast<Map<String, dynamic>>()) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${t['name']} · ${t['event']['title']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _summary(
                        (t['duties'] as List).cast<Map<String, dynamic>>(),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    for (final d
                        in (t['duties'] as List).cast<Map<String, dynamic>>())
                      Card(
                        child: ListTile(
                          leading: d['assignee_phone'] == null
                              ? null
                              : IconButton(
                                  icon: const Icon(
                                    Icons.call,
                                    color: AppColors.ok,
                                  ),
                                  onPressed: () => launchUrl(
                                    Uri.parse('tel:${d['assignee_phone']}'),
                                  ),
                                ),
                          title: Text(
                            d['assignee']['name'] as String? ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              d['title'],
                              d['location'],
                              if (d['status_note'] != null)
                                '“${d['status_note']}”',
                            ].whereType<String>().join(' · '),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Change status',
                            onSelected: (s) => _set(context, d, s),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'in_progress',
                                child: Text('On duty'),
                              ),
                              PopupMenuItem(value: 'done', child: Text('Done')),
                              PopupMenuItem(
                                value: 'blocked',
                                child: Text('Problem'),
                              ),
                            ],
                            child: dutyPill(
                              d['status'] as String,
                              forLead: true,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}
