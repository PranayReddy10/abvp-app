import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/kit.dart';
import '../widgets/loader.dart';
import '../widgets/motion.dart';
import 'circulars_screen.dart';
import 'directory_screen.dart';
import 'duties_screen.dart';
import 'events_screen.dart';
import 'meeting_screen.dart';
import 'notifications_screen.dart';
import 'report_activity_screen.dart';
import 'vibhags_screen.dart';

class _HomeData {
  _HomeData(
    this.meetings,
    this.unreadCirculars,
    this.actionItems,
    this.unreadNotifications,
    this.duties,
    this.passes,
    this.events,
  );
  final List<Map<String, dynamic>> duties;
  final List<Map<String, dynamic>> passes;
  final List<Map<String, dynamic>> meetings;
  final List<Map<String, dynamic>> events;
  final int unreadCirculars;
  final List<Map<String, dynamic>> actionItems;
  final int unreadNotifications;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.onShowPass,
    required this.onOpenCalendar,
    this.onOpenFeed,
  });
  final Session session;
  final VoidCallback onShowPass;
  final VoidCallback onOpenCalendar;
  final VoidCallback? onOpenFeed;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Key _key = UniqueKey();

  Future<_HomeData> _load() async {
    final api = widget.session.api;
    final results = await Future.wait([
      api.get('/meetings?when=upcoming'),
      api.getWithMeta('/circulars'),
      api.get('/me/action-items'),
      api.getWithMeta('/notifications'),
      api.get('/me/duties'),
      api.get('/me/passes'),
      api.get('/events?when=upcoming'),
    ]);
    await widget.session.refresh();
    return _HomeData(
      (results[0] as List)
          .cast<Map<String, dynamic>>()
          .where((m) => m['status'] != 'cancelled')
          .toList(),
      ((results[1] as Map)['meta']['unread'] as int?) ?? 0,
      (results[2] as List)
          .cast<Map<String, dynamic>>()
          .where((a) => a['done'] != true)
          .toList(),
      ((results[3] as Map)['meta']['unread'] as int?) ?? 0,
      (results[4] as List).cast<Map<String, dynamic>>(),
      (results[5] as List).cast<Map<String, dynamic>>(),
      (results[6] as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['status'] != 'cancelled')
          .toList(),
    );
  }

  void _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.session.me!.profile!;
    final first = p.fullName.split(' ').first;

    return SafeArea(
      bottom: false,
      child: Loader<_HomeData>(
        key: _key,
        load: _load,
        builder: (context, d, reload) {
          final next = d.meetings.isEmpty ? null : d.meetings.first;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
              children: staggered([
                // Top bar: avatar, area pill, bell.
                Row(
                  children: [
                    Initials(p.fullName, photoUrl: p.photoUrl, size: 50),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                size: 18,
                                color: AppColors.saffron,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  (p.orgUnitLabel ?? '').split('›').last.trim(),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    CircleIconButton(
                      icon: Icons.notifications_none_rounded,
                      tooltip: 'Notifications',
                      badge: d.unreadNotifications,
                      onTap: () =>
                          _open(NotificationsScreen(session: widget.session)),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  '${greeting()},',
                  style: const TextStyle(color: AppColors.muted, fontSize: 17),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$first 👋',
                        style: const TextStyle(
                          fontFamily: 'Anek',
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (p.verified) ...[
                      const SizedBox(width: 8),
                      const VerifiedBadge(size: 24),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                // Search pill + saffron button, as in the references.
                Row(
                  children: [
                    Expanded(
                      child: Pressable(
                        onTap: () =>
                            _open(DirectoryScreen(session: widget.session)),
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: AppColors.muted,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Find karyakartas, colleges…',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleIconButton(
                      icon: Icons.tune_rounded,
                      tooltip: 'Office bearers',
                      accent: true,
                      onTap: () =>
                          _open(DirectoryScreen(session: widget.session)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      const PillChip(
                        label: 'For you',
                        icon: Icons.auto_awesome_rounded,
                        selected: true,
                      ),
                      const SizedBox(width: 8),
                      PillChip(
                        label: 'Community',
                        icon: Icons.forum_outlined,
                        onTap: widget.onOpenFeed,
                      ),
                      const SizedBox(width: 8),
                      PillChip(
                        label: 'Vibhags',
                        icon: Icons.grid_view_rounded,
                        onTap: () => _open(
                          Scaffold(
                            appBar: AppBar(title: const Text('Vibhags')),
                            body: VibhagsScreen(session: widget.session),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PillChip(
                        label: d.unreadCirculars > 0
                            ? 'Circulars · ${d.unreadCirculars}'
                            : 'Circulars',
                        icon: Icons.campaign_outlined,
                        onTap: () =>
                            _open(CircularsScreen(session: widget.session)),
                      ),
                      const SizedBox(width: 8),
                      PillChip(
                        label: 'Report activity',
                        icon: Icons.add_a_photo_outlined,
                        onTap: () => _open(
                          ReportActivityScreen(session: widget.session),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ..._eventDay(context, d),
                if (d.events.isNotEmpty) ...[
                  SectionTitle(
                    'Upcoming events',
                    action: 'See all',
                    onAction: widget.onOpenCalendar,
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 300,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: d.events.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (_, i) => EventImageCard(
                        event: d.events[i],
                        width: d.events.length == 1
                            ? MediaQuery.sizeOf(context).width - 40
                            : 250,
                        onTap: () => _open(
                          EventScreen(
                            session: widget.session,
                            id: d.events[i]['id'] as int,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (next != null) ...[
                  const SectionTitle('Next up'),
                  const SizedBox(height: 8),
                  _NextMeeting(
                    meeting: next,
                    onTap: () => _open(
                      MeetingScreen(
                        session: widget.session,
                        id: next['id'] as int,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (d.actionItems.isNotEmpty) ...[
                  Panel(
                    onTap: widget.onOpenCalendar,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: AppColors.saffronSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.task_alt_rounded,
                            color: AppColors.saffronInk,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${d.actionItems.length} action item${d.actionItems.length == 1 ? '' : 's'} to do',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                d.actionItems.first['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                const SectionTitle('My card'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: widget.onShowPass,
                  child: _MemberCard(
                    verified: p.verified,
                    name: p.fullName,
                    memberId: p.memberId ?? '',
                    area: p.orgUnitLabel ?? '',
                    vibhags: p.vibhags.map((v) => v.name).join(', '),
                  ),
                ),
                if (p.responsibilities.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const SectionTitle('Dayitva'),
                  const SizedBox(height: 8),
                  Panel(
                    child: Column(
                      children: p.responsibilities
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 82,
                                    child: Text(
                                      r.years,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${r.title}${r.place != null ? ', ${r.place}' : ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _NextMeeting extends StatelessWidget {
  const _NextMeeting({required this.meeting, required this.onTap});
  final Map<String, dynamic> meeting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(meeting['starts_at'] as String).toLocal();
    final soon = start.difference(DateTime.now()).inHours < 24;
    final fg = soon ? Colors.white : AppColors.ink;
    final sub = soon ? Colors.white70 : AppColors.muted;
    return Panel(
      onTap: onTap,
      color: soon ? AppColors.ink : AppColors.surface,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: soon ? AppColors.saffron : AppColors.ground,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  monthShort(start).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: soon ? Colors.white : AppColors.muted,
                  ),
                ),
                Text(
                  '${start.day}',
                  style: TextStyle(
                    fontFamily: 'Anek',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: soon ? Colors.white : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting['kind'] == 'call' ? 'CALL' : 'MEETING',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: soon ? AppColors.saffron : AppColors.saffronInk,
                  ),
                ),
                Text(
                  meeting['title'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                Text(
                  '${TimeOfDay.fromDateTime(start).format(context)} · ${meeting['mode'] == 'in_person' ? meeting['venue'] : providerNames[meeting['provider']] ?? 'Online'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: sub),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: soon ? Colors.white12 : AppColors.ground,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.north_east, size: 18, color: fg),
          ),
        ],
      ),
    );
  }
}

bool _isToday(String startIso, String endIso) {
  final now = DateTime.now();
  final s = DateTime.parse(startIso).toLocal();
  return now.isAfter(DateTime(s.year, s.month, s.day)) &&
      now.isBefore(DateTime.parse(endIso).toLocal());
}

extension on _HomeScreenState {
  /// Event-day mode: today's duty (or today's pass) first, everything else below.
  List<Widget> _eventDay(BuildContext context, _HomeData d) {
    final duty = d.duties
        .where(
          (x) =>
              !['done', 'declined', 'cancelled'].contains(x['status']) &&
              _isToday(x['starts_at'] as String, x['ends_at'] as String),
        )
        .firstOrNull;
    final pass = d.passes
        .where(
          (p) =>
              p['token'] != null &&
              p['checked_in_at'] == null &&
              _isToday(
                p['event']['starts_at'] as String,
                p['event']['ends_at'] as String,
              ),
        )
        .firstOrNull;
    if (duty == null && pass == null) return [];

    const white = TextStyle(color: Colors.white);
    final report = duty?['report_to'] as Map<String, dynamic>?;
    final start = duty == null
        ? null
        : DateTime.parse(duty['starts_at'] as String).toLocal();
    return [
      Material(
        color: AppColors.saffron,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: duty == null
              ? widget.onShowPass
              : () => _open(DutyScreen(session: widget.session, duty: duty)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY · ${(duty?['event']?['title'] ?? pass?['event']?['title'] ?? '').toString().toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (duty != null) ...[
                  Text(
                    '${duty['title']}${duty['location'] != null ? ' · ${duty['location']}' : ''}',
                    style: white.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Report by ${TimeOfDay.fromDateTime(start!).format(context)}${report != null ? ' to ${report['name']}' : ''}',
                    style: white,
                  ),
                  if (duty['status'] == 'assigned')
                    Text(
                      'Please accept this duty',
                      style: white.copyWith(fontWeight: FontWeight.w700),
                    ),
                ] else
                  Text(
                    'Show your pass at the gate',
                    style: white.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    if (pass != null)
                      ActionChip(
                        onPressed: widget.onShowPass,
                        avatar: const Icon(
                          Icons.qr_code_2,
                          size: 18,
                          color: AppColors.saffronInk,
                        ),
                        label: const Text(
                          'Show pass',
                          style: TextStyle(
                            color: AppColors.saffronInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide.none,
                      ),
                    if (report?['phone'] != null)
                      ActionChip(
                        onPressed: () =>
                            launchUrl(Uri.parse('tel:${report['phone']}')),
                        avatar: const Icon(
                          Icons.call,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Call ${(report!['name'] as String).split(' ').first}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: AppColors.saffron,
                        side: const BorderSide(color: Colors.white),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.name,
    required this.memberId,
    required this.area,
    required this.vibhags,
    this.verified = false,
  });
  final String name, memberId, area, vibhags;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
      color: Colors.white60,
      fontSize: 10.5,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w700,
    );
    const value = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 14.5,
    );
    return Hero(
      tag: 'member-card',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.inkSoft, AppColors.ink],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33171A2E),
              blurRadius: 24,
              offset: Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: -46,
              top: -46,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.saffron, width: 18),
                ),
              ),
            ),
            Positioned(
              right: 34,
              bottom: -60,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: AppColors.saffron,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text('ABVP CONNECT · MEMBER', style: label),
                      const Spacer(),
                      if (verified)
                        Container(
                          padding: const EdgeInsets.fromLTRB(6, 2, 10, 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                color: Color(0xFF7FC0FF),
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Anek',
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    memberId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('AREA', style: label),
                  const SizedBox(height: 2),
                  Text(area, style: value),
                  if (vibhags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('VIBHAGS', style: label),
                    const SizedBox(height: 2),
                    Text(vibhags, style: value),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
