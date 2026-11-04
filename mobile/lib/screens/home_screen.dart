import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/loader.dart';
import 'circulars_screen.dart';
import 'directory_screen.dart';
import 'meeting_screen.dart';
import 'notifications_screen.dart';
import 'report_activity_screen.dart';

class _HomeData {
  _HomeData(
    this.meetings,
    this.unreadCirculars,
    this.actionItems,
    this.unreadNotifications,
  );
  final List<Map<String, dynamic>> meetings;
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
  });
  final Session session;
  final VoidCallback onShowPass;
  final VoidCallback onOpenCalendar;

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
    );
  }

  void _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.session.me!.profile!;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Loader<_HomeData>(
        key: _key,
        load: _load,
        builder: (context, d, reload) {
          final next = d.meetings.isEmpty ? null : d.meetings.first;
          final soon =
              next != null &&
              DateTime.parse(next['starts_at'] as String)
                      .difference(DateTime.now())
                      .inHours <
                  24;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('नमस्ते', style: text.bodySmall),
                        Text(p.fullName, style: text.headlineSmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () =>
                        _open(NotificationsScreen(session: widget.session)),
                    icon: Badge(
                      isLabelVisible: d.unreadNotifications > 0,
                      label: Text('${d.unreadNotifications}'),
                      child: const Icon(Icons.notifications_none),
                    ),
                  ),
                  Initials(p.fullName, photoUrl: p.photoUrl),
                ],
              ),
              const SizedBox(height: 16),
              if (next != null)
                Material(
                  color: soon ? AppColors.saffron : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _open(
                      MeetingScreen(
                        session: widget.session,
                        id: next['id'] as int,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: soon
                          ? null
                          : BoxDecoration(
                              border: Border.all(color: AppColors.line),
                              borderRadius: BorderRadius.circular(16),
                            ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            next['kind'] == 'call'
                                ? 'NEXT CALL'
                                : 'NEXT MEETING',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                              color: soon
                                  ? Colors.white70
                                  : AppColors.saffronInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            next['title'] as String,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: soon ? Colors.white : AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${dayTime(next['starts_at'] as String)} · ${next['mode'] == 'in_person' ? next['venue'] : providerNames[next['provider']] ?? 'Online'}',
                            style: TextStyle(
                              color: soon ? Colors.white : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (d.unreadCirculars > 0 || d.actionItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      if (d.unreadCirculars > 0)
                        ListTile(
                          leading: const Icon(
                            Icons.campaign_outlined,
                            color: AppColors.saffron,
                          ),
                          title: Text(
                            '${d.unreadCirculars} unread circular${d.unreadCirculars == 1 ? '' : 's'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              _open(CircularsScreen(session: widget.session)),
                        ),
                      if (d.actionItems.isNotEmpty)
                        ListTile(
                          leading: const Icon(
                            Icons.task_alt,
                            color: AppColors.saffron,
                          ),
                          title: Text(
                            '${d.actionItems.length} action item${d.actionItems.length == 1 ? '' : 's'} to do',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            d.actionItems.first['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: widget.onOpenCalendar,
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _MemberCard(
                name: p.fullName,
                memberId: p.memberId ?? '',
                area: p.orgUnitLabel ?? '',
                vibhags: p.vibhags.map((v) => v.name).join(', '),
              ),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Action(
                        icon: Icons.qr_code_2,
                        label: 'My pass',
                        onTap: widget.onShowPass,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Action(
                        icon: Icons.add_a_photo_outlined,
                        label: 'Report activity',
                        onTap: () => _open(
                          ReportActivityScreen(session: widget.session),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Action(
                        icon: Icons.campaign_outlined,
                        label: 'Circulars',
                        onTap: () =>
                            _open(CircularsScreen(session: widget.session)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Action(
                        icon: Icons.people_alt_outlined,
                        label: 'Directory',
                        onTap: () =>
                            _open(DirectoryScreen(session: widget.session)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('Dayitva', style: text.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: p.responsibilities.isEmpty
                      ? Text(
                          'Responsibilities your office assigns will appear here.',
                          style: text.bodySmall,
                        )
                      : Column(
                          children: p.responsibilities
                              .map(
                                (r) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5,
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 82,
                                        child: Text(
                                          r.years,
                                          style: text.bodySmall,
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
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.saffron),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.name,
    required this.memberId,
    required this.area,
    required this.vibhags,
  });
  final String name, memberId, area, vibhags;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(
      color: Colors.white70,
      fontSize: 10,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w600,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: AppColors.ink,
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.saffron, width: 16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MEMBER ID', style: label),
                  const SizedBox(height: 2),
                  Text(
                    memberId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('AREA', style: label),
                  Text(
                    area,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (vibhags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('VIBHAGS', style: label),
                    Text(
                      vibhags,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
