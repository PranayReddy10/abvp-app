import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/loader.dart';
import '../widgets/motion.dart';
import 'help_screen.dart';
import 'logistics_screen.dart';

/// Status pill for an event card, from the member's point of view.
StatusPill eventPill(Map<String, dynamic> e) {
  final reg = e['my_registration'] as Map<String, dynamic>?;
  final status = reg?['status'];
  if (e['status'] == 'cancelled') {
    return const StatusPill(
      'Cancelled',
      color: AppColors.bad,
      background: AppColors.badSoft,
    );
  }
  if (reg?['checked_in_at'] != null) {
    return const StatusPill(
      'Checked in',
      color: AppColors.ok,
      background: AppColors.okSoft,
    );
  }
  if (status == 'registered') {
    return StatusPill(
      reg?['kind'] == 'guest' ? 'Invited' : 'Registered',
      color: const Color(0xFF2E55C9),
      background: const Color(0xFFE6ECFB),
    );
  }
  if (status == 'waitlisted') {
    return const StatusPill(
      'On waitlist',
      color: AppColors.warn,
      background: AppColors.warnSoft,
    );
  }
  if (status == 'pending') {
    return const StatusPill(
      'Waiting for approval',
      color: AppColors.warn,
      background: AppColors.warnSoft,
    );
  }
  if (e['eligible'] != true) return const StatusPill('Not eligible');
  if (e['registration_open'] != true) {
    return const StatusPill('Registration closed');
  }
  if (e['seats_left'] == 0) {
    return const StatusPill(
      'Full · join waitlist',
      color: AppColors.bad,
      background: AppColors.badSoft,
    );
  }
  return StatusPill(
    'Open · closes ${day(e['registration_closes_at'] as String)}',
    color: AppColors.saffronInk,
    background: AppColors.saffronSoft,
  );
}

class EventsList extends StatelessWidget {
  const EventsList({super.key, required this.session, this.when = 'upcoming'});
  final Session session;
  final String when;

  @override
  Widget build(BuildContext context) {
    return Loader<List<dynamic>>(
      load: () async => await session.api.get('/events?when=$when') as List,
      builder: (context, rows, reload) => rows.isEmpty
          ? ListView(
              children: const [
                EmptyNote(
                  'No events right now. Published events from your unit, district, state and national office appear here.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => FadeSlideIn(
                index: i,
                child: Builder(
                  builder: (context) {
                    final e = rows[i] as Map<String, dynamic>;
                    final start = DateTime.parse(e['starts_at'] as String)
                        .toLocal();
                    return Opacity(
                      opacity:
                          e['eligible'] == true || e['my_registration'] != null
                          ? 1
                          : 0.7,
                      child: Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventScreen(
                                  session: session,
                                  id: e['id'] as int,
                                ),
                              ),
                            );
                            await reload();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.ground,
                                    border: Border.all(color: AppColors.line),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${start.day}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        const [
                                          'JAN',
                                          'FEB',
                                          'MAR',
                                          'APR',
                                          'MAY',
                                          'JUN',
                                          'JUL',
                                          'AUG',
                                          'SEP',
                                          'OCT',
                                          'NOV',
                                          'DEC',
                                        ][start.month - 1],
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.muted,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e['title'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${e['venue']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      eventPill(e),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}

class EventScreen extends StatefulWidget {
  const EventScreen({
    super.key,
    required this.session,
    required this.id,
    this.onShowPass,
  });
  final Session session;
  final int id;
  final VoidCallback? onShowPass;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  Key _key = UniqueKey();
  String? _error;
  bool _busy = false;

  Future<void> _act(String path) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.api.post(path);
      setState(() => _key = UniqueKey());
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: Loader<Map<String, dynamic>>(
        key: _key,
        load: () async {
          final e = await widget.session.api.get(
            '/events/${widget.id}',
          ) as Map<String, dynamic>;
          final reg = e['my_registration'] as Map<String, dynamic>?;
          if (reg?['status'] == 'registered') {
            try {
              e['announcements'] = await widget.session.api.get(
                '/events/${widget.id}/announcements',
              );
            } on ApiException {
              e['announcements'] = [];
            }
          }
          return e;
        },
        builder: (context, e, _) {
          final text = Theme.of(context).textTheme;
          final reg = e['my_registration'] as Map<String, dynamic>?;
          final status = reg?['status'] as String?;
          final active =
              status != null && status != 'cancelled' && status != 'rejected';
          final cancelled = e['status'] == 'cancelled';
          final contact = e['contact'] as Map<String, dynamic>?;
          final seatsLeft = e['seats_left'] as int?;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (e['category_label'] as String).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      e['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Organised by ${e['organised_by']}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: eventPill(e)),
              const SizedBox(height: 10),
              _row(
                Icons.schedule,
                '${dayTime(e['starts_at'] as String)} –',
                dayTime(e['ends_at'] as String),
              ),
              InkWell(
                onTap: e['venue_map_url'] == null
                    ? null
                    : () => launchUrl(
                        Uri.parse(e['venue_map_url'] as String),
                        mode: LaunchMode.externalApplication,
                      ),
                child: _row(
                  Icons.place_outlined,
                  e['venue'] as String,
                  e['venue_map_url'] != null ? 'Open map' : null,
                ),
              ),
              _row(
                Icons.people_alt_outlined,
                '${e['registered_count']} registered',
                seatsLeft == null ? null : '$seatsLeft seats left',
              ),
              const SizedBox(height: 10),
              if (!cancelled && reg?['kind'] != 'guest')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: e['eligible'] == true
                        ? AppColors.okSoft
                        : AppColors.ground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        e['eligible'] == true
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        size: 18,
                        color: e['eligible'] == true
                            ? AppColors.ok
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e['eligibility'] as String,
                          style: TextStyle(
                            color: e['eligible'] == true
                                ? AppColors.ok
                                : AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (status == 'waitlisted')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'You are number ${e['waitlist_position']} on the waitlist. You will be told if a seat opens.',
                    style: text.bodyMedium,
                  ),
                ),
              if (status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'The organisers will confirm your registration. You will be notified.',
                    style: text.bodyMedium,
                  ),
                ),
              if (status == 'rejected' && reg?['note'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ErrorBanner('Not approved: ${reg!['note']}'),
                ),
              if ((e['announcements'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 18),
                Text('Announcements', style: text.titleMedium),
                const SizedBox(height: 6),
                for (final a
                    in (e['announcements'] as List)
                        .cast<Map<String, dynamic>>())
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.saffronSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.saffronInk,
                          ),
                        ),
                        Text(a['body'] as String),
                        Text(ago(a['at'] as String), style: text.bodySmall),
                      ],
                    ),
                  ),
              ],
              if (!cancelled && status == 'registered') ...[
                const SizedBox(height: 18),
                LogisticsCard(
                  session: widget.session,
                  eventId: widget.id,
                  eventTitle: e['title'] as String,
                ),
              ],
              if ((e['description'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 18),
                Text(e['description'] as String, style: text.bodyMedium),
              ],
              if (e['instructions'] != null) ...[
                const SizedBox(height: 18),
                Text('Before you come', style: text.titleMedium),
                const SizedBox(height: 6),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(e['instructions'] as String),
                  ),
                ),
              ],
              if (contact != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Initials(contact['name'] as String),
                  title: Text(contact['name'] as String),
                  subtitle: const Text('Contact for this event'),
                  trailing: contact['phone'] == null
                      ? null
                      : IconButton.filledTonal(
                          icon: const Icon(Icons.call),
                          onPressed: () =>
                              launchUrl(Uri.parse('tel:${contact['phone']}')),
                        ),
                ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 12),
              ],
              if (!cancelled &&
                  status == 'registered' &&
                  reg?['checked_in_at'] == null &&
                  widget.onShowPass != null)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onShowPass!();
                  },
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Show my pass'),
                ),
              if (!cancelled &&
                  !active &&
                  e['eligible'] == true &&
                  e['registration_open'] == true)
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _act('/events/${widget.id}/register'),
                  child: Text(
                    seatsLeft == 0
                        ? 'Join the waitlist'
                        : (e['requires_approval'] == true
                              ? 'Request a place'
                              : 'Register for this event'),
                  ),
                ),
              if (!cancelled &&
                  status == 'registered' &&
                  DateTime.now().isAfter(
                    DateTime.parse(e['starts_at'] as String)
                        .subtract(const Duration(days: 1)),
                  )) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AskHelpScreen(
                        session: widget.session,
                        eventId: widget.id,
                        eventTitle: e['title'] as String,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Ask for help'),
                ),
              ],
              if (!cancelled &&
                  active &&
                  reg?['kind'] != 'guest' &&
                  reg?['checked_in_at'] == null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _act('/events/${widget.id}/cancel-registration'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.bad),
                  child: Text(
                    status == 'waitlisted'
                        ? 'Leave the waitlist'
                        : "I can't come – cancel my registration",
                  ),
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
