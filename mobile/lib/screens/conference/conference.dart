import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../../widgets/loader.dart';
import '../../widgets/motion.dart';
import '../duties_screen.dart';
import '../guide/guide_hub.dart';
import '../meeting_screen.dart';
import '../notifications_screen.dart';

typedef Json = Map<String, dynamic>;

Color _hex(String? h, [Color fallback = AppColors.saffron]) {
  if (h == null || h.length != 7) return fallback;
  return Color(int.parse('FF${h.substring(1)}', radix: 16));
}

String _ist(String iso, String pattern) => DateFormat(pattern).format(
  DateTime.parse(iso).toUtc().add(const Duration(hours: 5, minutes: 30)),
);

Future<void> _call(String m) => launchUrl(Uri.parse('tel:$m'));
Future<void> _wa(String m) => launchUrl(
  Uri.parse('https://wa.me/${m.replaceAll(RegExp(r'\D'), '')}'),
  mode: LaunchMode.externalApplication,
);

/// Everything the home needs in one go: the conference, my seva and the team tree.
class _HomeData {
  _HomeData(this.conference, this.seva, this.tree);
  final Json? conference;
  final Json seva;
  final Json? tree;
  List<Json> get places => ((seva['places'] as List?) ?? []).cast<Json>();
  List<Json> get chats => ((seva['chats'] as List?) ?? []).cast<Json>();
  List<Json> get ghats => ((tree?['ghats'] as List?) ?? []).cast<Json>();
  Set<int> get manageable => {
    for (final c in chats)
      if (c['can_manage'] == true) c['team_id'] as int,
  };
}

/// Home, built around the national conference: the delegate side (guide, pass, help desk),
/// the volunteer side (my seva: role, team chat, tasks, meetings, announcements) and the whole
/// conference team as colourful ghat tiles.
class ConferenceHome extends StatelessWidget {
  const ConferenceHome({super.key, required this.session, this.onShowPass});
  final Session session;
  final VoidCallback? onShowPass;

  Future<_HomeData> _load() async {
    final conf = await session.api.get('/conference') as Json?;
    final seva = await session.api.get('/me/seva') as Json;
    Json? tree;
    if (conf != null && conf['has_teams'] == true) {
      tree = await session.api.get('/events/${conf['id']}/teams') as Json;
    }
    return _HomeData(conf, seva, tree);
  }

  @override
  Widget build(BuildContext context) {
    return Loader<_HomeData>(
      load: _load,
      builder: (context, d, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.paddingOf(context).top + 12,
            16,
            120,
          ),
          children: [
            _Greeting(session: session),
            const SizedBox(height: 14),
            if (d.conference == null)
              const EmptyNote(
                'The conference details appear here once it is published.',
              )
            else ...[
              FadeSlideIn(child: _Hero(conf: d.conference!)),
              const SizedBox(height: 14),
              FadeSlideIn(
                index: 1,
                child: _SideTiles(
                  session: session,
                  data: d,
                  onShowPass: onShowPass,
                ),
              ),
              if (d.places.isNotEmpty) ...[
                const SizedBox(height: 18),
                FadeSlideIn(
                  index: 2,
                  child: _MySeva(session: session, data: d, onChanged: reload),
                ),
              ],
              if (d.ghats.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionTitle(
                  'Conference team',
                  action: 'Search',
                  onAction: () => showSearch(
                    context: context,
                    delegate: _TeamSearch(
                      session: session,
                      ghats: d.ghats,
                      manageable: d.manageable,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _GhatGrid(
                  session: session,
                  ghats: d.ghats,
                  manageable: d.manageable,
                  onChanged: reload,
                ),
              ],
              if (d.places.isEmpty && d.ghats.isNotEmpty) ...[
                const SizedBox(height: 16),
                Panel(
                  color: AppColors.saffronSoft,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.volunteer_activism_outlined,
                        color: AppColors.saffronInk,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Want to do seva at the conference? Call the Ghat Pramukh of the ghat you would like to join. They will add you, and your team chat and tasks appear here.',
                          style: TextStyle(
                            color: AppColors.saffronInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final me = session.me;
    final name = me?.profile?.fullName.isNotEmpty == true
        ? me!.profile!.fullName
        : (me?.name ?? '');
    return Row(
      children: [
        Expanded(
          child: Text(
            'Namaste${name.isEmpty ? '' : ', ${name.split(' ').first}'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        CircleIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationsScreen(session: session),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.conf});
  final Json conf;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(conf['starts_at'] as String);
    final end = DateTime.parse(conf['ends_at'] as String);
    final now = DateTime.now();
    final days = start.difference(now).inHours / 24;
    final status = now.isAfter(end)
        ? 'Concluded'
        : now.isAfter(start)
        ? 'Happening now'
        : days < 1
        ? 'Starts tomorrow'
        : 'in ${days.ceil()} days';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFF08A3C), AppColors.saffron, Color(0xFF13235B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, 0.45, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.saffron.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  conf['title'] as String,
                  style: const TextStyle(
                    fontFamily: 'Anek',
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_ist(conf['starts_at'] as String, 'd')}–${_ist(conf['ends_at'] as String, 'd MMM yyyy')} · ${conf['venue']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (conf['helpline'] != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _call(conf['helpline'] as String),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Helpline ${conf['helpline']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Image.asset('assets/brand/emblem.png'),
          ),
        ],
      ),
    );
  }
}

/// Delegate side and volunteer side, side by side.
class _SideTiles extends StatelessWidget {
  const _SideTiles({
    required this.session,
    required this.data,
    this.onShowPass,
  });
  final Session session;
  final _HomeData data;
  final VoidCallback? onShowPass;

  @override
  Widget build(BuildContext context) {
    final conf = data.conference!;
    final guide = conf['guide_enabled'] == true;
    final seva = data.places.isNotEmpty;
    Widget tile(
      String title,
      String sub,
      IconData icon,
      List<Color> colors,
      VoidCallback onTap,
    ) => Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        tile(
          'Delegate',
          guide
              ? 'Stay, transport, food, help desk'
              : 'Your pass · guide opens soon',
          Icons.explore_rounded,
          const [Color(0xFF3E8BF0), Color(0xFF13235B)],
          () => guide
              ? Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        GuideHub(session: session, eventId: conf['id'] as int),
                  ),
                )
              : onShowPass?.call(),
        ),
        const SizedBox(width: 12),
        tile(
          seva ? 'My seva' : 'Seva team',
          seva
              ? (data.places.first['team'] as Json)['name'] as String
              : 'Ghats and departments',
          Icons.volunteer_activism_rounded,
          const [Color(0xFFF08A3C), Color(0xFFC24F06)],
          () => seva
              ? Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamChatScreen(
                      session: session,
                      teamId: data.chats.first['team_id'] as int,
                    ),
                  ),
                )
              : showSearch(
                  context: context,
                  delegate: _TeamSearch(
                    session: session,
                    ghats: data.ghats,
                    manageable: data.manageable,
                  ),
                ),
        ),
      ],
    );
  }
}

/// My role(s), my team chats, next meeting, tasks and announcements.
class _MySeva extends StatelessWidget {
  const _MySeva({
    required this.session,
    required this.data,
    required this.onChanged,
  });
  final Session session;
  final _HomeData data;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final seva = data.seva;
    final meetings = ((seva['meetings'] as List?) ?? []).cast<Json>();
    final tasks = ((seva['tasks'] as List?) ?? []).cast<Json>();
    final news = ((seva['announcements'] as List?) ?? []).cast<Json>();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('My seva'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in data.places)
              _RoleChip(
                color: _hex((p['team'] as Json)['color'] as String?),
                text:
                    '${p['role_label']} · ${(p['team'] as Json)['name']}${p['ghat'] != null ? ' · ${(p['ghat'] as Json)['name']}' : ''}',
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final c in data.chats)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.all(14),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamChatScreen(
                      session: session,
                      teamId: c['team_id'] as int,
                    ),
                  ),
                );
                onChanged();
              },
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _hex(c['color'] as String?)
                        .withValues(alpha: 0.15),
                    child: Icon(
                      Icons.forum_rounded,
                      color: _hex(c['color'] as String?),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c['name']}${c['kind'] == 'ghat' ? ' ghat' : ''}',
                          style: text.titleSmall,
                        ),
                        Text(
                          c['last'] == null
                              ? 'No messages yet'
                              : '${(c['last'] as Json)['by']}: ${(c['last'] as Json)['body']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        if (meetings.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final m in meetings.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                color: AppColors.infoSoft,
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MeetingScreen(session: session, id: m['id'] as int),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups_rounded, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['title'] as String, style: text.titleSmall),
                          Text(
                            '${_ist(m['starts_at'] as String, 'EEE d MMM, h:mm a')} · ${m['team'] ?? ''}',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (m['link'] != null)
                      FilledButton(
                        onPressed: () => launchUrl(
                          Uri.parse(m['link'] as String),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('Join'),
                      ),
                  ],
                ),
              ),
            ),
        ],
        if (news.isNotEmpty) ...[
          const SizedBox(height: 6),
          Panel(
            color: AppColors.saffronSoft,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📣 Announcements',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.saffronInk,
                  ),
                ),
                for (final n in news.take(3)) ...[
                  const SizedBox(height: 8),
                  Text(n['body'] as String),
                  Text(
                    '${n['by']} · ${n['team']} · ${_ist(n['at'] as String, 'd MMM, h:mm a')}',
                    style: text.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('My tasks', style: text.titleMedium),
          const SizedBox(height: 6),
          for (final t in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DutyCard(session: session, d: t, onChanged: onChanged),
            ),
        ],
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}

class _GhatGrid extends StatelessWidget {
  const _GhatGrid({
    required this.session,
    required this.ghats,
    required this.manageable,
    required this.onChanged,
  });
  final Session session;
  final List<Json> ghats;
  final Set<int> manageable;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemCount: ghats.length,
      itemBuilder: (context, i) {
        final g = ghats[i];
        final c = _hex(g['color'] as String?);
        final pramukh = ((g['heads'] as List).cast<Json>())
            .where((h) => h['role'] == 'ghat_pramukh')
            .map((h) => h['name'])
            .join(', ');
        return FadeSlideIn(
          index: i,
          child: Pressable(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GhatScreen(
                    session: session,
                    ghat: g,
                    manageable: manageable,
                  ),
                ),
              );
              onChanged();
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [c, Color.lerp(c, Colors.black, 0.3)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g['name'] as String,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.15,
                    ),
                  ),
                  const Spacer(),
                  if (pramukh.isNotEmpty)
                    Text(
                      pramukh,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    '${(g['counts'] as Json)['departments']} dept · ${(g['counts'] as Json)['people']} people',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One person, with Call and WhatsApp when their number is known.
class PersonTile extends StatelessWidget {
  const PersonTile({super.key, required this.p, this.dense = false});
  final Json p;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final m = p['mobile'] as String?;
    return ListTile(
      dense: dense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Initials(
        p['name'] as String,
        photoUrl: p['photo_url'] as String?,
        size: dense ? 36 : 44,
      ),
      title: Text(
        p['name'] as String,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          p['role_label'],
          if (m == null && p['has_mobile'] != true) 'no phone yet',
        ].join(' · '),
      ),
      trailing: m == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Call',
                  icon: const Icon(Icons.call_rounded, color: AppColors.ok),
                  onPressed: () => _call(m),
                ),
                IconButton(
                  tooltip: 'WhatsApp',
                  icon: const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF25D366),
                  ),
                  onPressed: () => _wa(m),
                ),
              ],
            ),
    );
  }
}

/// A ghat: its three heads and every department with its people. Heads get their tools here.
class GhatScreen extends StatelessWidget {
  const GhatScreen({
    super.key,
    required this.session,
    required this.ghat,
    required this.manageable,
  });
  final Session session;
  final Json ghat;
  final Set<int> manageable;

  @override
  Widget build(BuildContext context) {
    final c = _hex(ghat['color'] as String?);
    final heads = (ghat['heads'] as List).cast<Json>();
    final depts = (ghat['departments'] as List).cast<Json>();
    final canGhat = manageable.contains(ghat['id']);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 150,
            backgroundColor: c,
            foregroundColor: Colors.white,
            actions: [
              if (canGhat)
                IconButton(
                  tooltip: 'Ghat chat',
                  icon: const Icon(Icons.forum_rounded),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeamChatScreen(
                        session: session,
                        teamId: ghat['id'] as int,
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                ghat['name'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c, Color.lerp(c, Colors.black, 0.35)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            sliver: SliverList.list(
              children: [
                Text(
                  'Ghat heads',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Panel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [for (final h in heads) PersonTile(p: h)],
                  ),
                ),
                if (canGhat) ...[
                  const SizedBox(height: 10),
                  _HeadActions(
                    session: session,
                    teamId: ghat['id'] as int,
                    isGhat: true,
                    people: [
                      for (final d in depts)
                        ...(d['people'] as List).cast<Json>(),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Departments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                for (final d in depts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          leading: Container(
                            width: 6,
                            height: 34,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          title: Text(
                            d['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            (d['people'] as List).isEmpty
                                ? 'No one yet'
                                : (d['people'] as List)
                                      .cast<Json>()
                                      .where((p) => p['role'] != 'volunteer')
                                      .map((p) => p['name'])
                                      .join(', '),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            10,
                          ),
                          children: [
                            for (final p in (d['people'] as List).cast<Json>())
                              PersonTile(p: p, dense: true),
                            if (manageable.contains(d['id']) || canGhat) ...[
                              const SizedBox(height: 6),
                              _HeadActions(
                                session: session,
                                teamId: d['id'] as int,
                                isGhat: false,
                                people: (d['people'] as List).cast<Json>(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Team chat, refreshed every 5 seconds. Heads can post an announcement and use their tools.
class TeamChatScreen extends StatefulWidget {
  const TeamChatScreen({
    super.key,
    required this.session,
    required this.teamId,
  });
  final Session session;
  final int teamId;

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final List<Json> _messages = [];
  Json? _team;
  bool _canManage = false;
  bool _announce = false;
  bool _sending = false;
  String? _error;
  Timer? _timer;

  ApiClient get api => widget.session.api;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _load(after: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool after = false}) async {
    try {
      final last = _messages.isEmpty ? null : _messages.last['id'];
      final r = await api.get(
        '/teams/${widget.teamId}/messages${after && last != null ? '?after=$last' : ''}',
      ) as Json;
      if (!mounted) return;
      final rows = (r['messages'] as List).cast<Json>();
      setState(() {
        _team = r['team'] as Json;
        _canManage = r['can_manage'] == true;
        if (!after) _messages.clear();
        _messages.addAll(rows);
        _error = null;
      });
      if (rows.isNotEmpty) _toBottom();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      final m = await api.post('/teams/${widget.teamId}/messages', {
        'body': body,
        'announcement': _announce,
      }) as Json;
      setState(() {
        _messages.add(m);
        _text.clear();
        _announce = false;
      });
      _toBottom();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _hex(_team?['color'] as String?);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _team?['name'] as String? ?? 'Team chat',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            if (_team?['ghat'] != null)
              Text(
                '${_team!['ghat']} ghat',
                style: const TextStyle(fontSize: 12.5, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          if (_canManage)
            IconButton(
              tooltip: 'Team tools',
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: _HeadActions(
                    session: widget.session,
                    teamId: widget.teamId,
                    isGhat: _team?['kind'] == 'ghat',
                    people: const [],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: ErrorBanner(_error!),
            ),
          Expanded(
            child: _messages.isEmpty
                ? const EmptyNote('No messages yet. Say namaste to your team!')
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) =>
                        _Bubble(m: _messages[i], color: c),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_canManage)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilterChip(
                        label: const Text('📣 Send as announcement'),
                        selected: _announce,
                        onSelected: (v) => setState(() => _announce = v),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            hintText: 'Message your team',
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        style: IconButton.styleFrom(backgroundColor: c),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m, required this.color});
  final Json m;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final mine = m['mine'] == true;
    final ann = m['announcement'] == true;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: ann
              ? AppColors.saffronSoft
              : mine
              ? color.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ann ? AppColors.saffron : AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine || ann)
              Text(
                '${ann ? '📣 ' : ''}${m['by']}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: ann ? AppColors.saffronInk : color,
                ),
              ),
            Text(m['body'] as String),
            Text(
              _ist(m['at'] as String, 'd MMM, h:mm a'),
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Heads' tools for a ghat or department: chat, add a person, schedule a meeting, assign a task.
class _HeadActions extends StatelessWidget {
  const _HeadActions({
    required this.session,
    required this.teamId,
    required this.isGhat,
    required this.people,
  });
  final Session session;
  final int teamId;
  final bool isGhat;
  final List<Json> people;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData i, String l, VoidCallback f) =>
        ActionChip(avatar: Icon(i, size: 18), label: Text(l), onPressed: f);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          Icons.forum_outlined,
          'Team chat',
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeamChatScreen(session: session, teamId: teamId),
            ),
          ),
        ),
        chip(
          Icons.person_add_alt_1_outlined,
          isGhat ? 'Add ghat head' : 'Add volunteer',
          () => _addPerson(context),
        ),
        chip(Icons.event_outlined, 'Meeting', () => _meeting(context)),
        if (people.isNotEmpty)
          chip(Icons.task_alt_outlined, 'Assign task', () => _task(context)),
      ],
    );
  }

  Future<void> _sheet(
    BuildContext context,
    String title,
    List<Widget> fields,
    Future<void> Function() submit,
  ) async {
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (error != null) ...[
                ErrorBanner(error!),
                const SizedBox(height: 10),
              ],
              ...fields,
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () async {
                  try {
                    await submit();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Done.')));
                    }
                  } on ApiException catch (e) {
                    set(() => error = e.message);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addPerson(BuildContext context) {
    final name = TextEditingController();
    final mobile = TextEditingController();
    var role = isGhat ? 'ghat_saha_pramukh' : 'volunteer';
    final roles = isGhat
        ? {
            'ghat_pramukh': 'Ghat Pramukh',
            'ghat_saha_pramukh': 'Ghat Saha Pramukh',
            'ghat_palak': 'Ghat Palak',
          }
        : {
            'volunteer': 'Volunteer',
            'pramukh': 'Pramukh',
            'saha_pramukh': 'Saha Pramukh',
          };
    return _sheet(
      context,
      isGhat ? 'Add a ghat head' : 'Add to this department',
      [
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Name'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: mobile,
          decoration: const InputDecoration(
            labelText: 'Mobile number',
            prefixText: '+91  ',
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 10),
        StatefulBuilder(
          builder: (c, set) => DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [
              for (final e in roles.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => set(() => role = v ?? role),
          ),
        ),
      ],
      () => session.api.post('/teams/$teamId/members', {
        'name': name.text.trim(),
        'mobile': mobile.text.trim().isEmpty ? null : mobile.text.trim(),
        'role': role,
      }),
    );
  }

  Future<void> _meeting(BuildContext context) {
    final title = TextEditingController(
      text: isGhat ? 'Ghat baithak' : 'Team baithak',
    );
    final link = TextEditingController();
    final venue = TextEditingController();
    var when = DateTime.now().add(const Duration(hours: 2));
    return _sheet(
      context,
      'Schedule a meeting',
      [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: link,
          decoration: const InputDecoration(
            labelText: 'Online link (Google Meet, Zoom…)',
            hintText: 'https://',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: venue,
          decoration: const InputDecoration(labelText: 'Or a place'),
        ),
        const SizedBox(height: 10),
        StatefulBuilder(
          builder: (c, set) => OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text(DateFormat('EEE d MMM, h:mm a').format(when)),
            onPressed: () async {
              final d = await showDatePicker(
                context: c,
                initialDate: when,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d == null || !c.mounted) return;
              final t = await showTimePicker(
                context: c,
                initialTime: TimeOfDay.fromDateTime(when),
              );
              if (t == null) return;
              set(
                () => when = DateTime(d.year, d.month, d.day, t.hour, t.minute),
              );
            },
          ),
        ),
      ],
      () {
        final hasLink = link.text.trim().isNotEmpty;
        final hasVenue = venue.text.trim().isNotEmpty;
        return session.api.post('/teams/$teamId/meetings', {
          'title': title.text.trim(),
          'mode': hasLink && hasVenue
              ? 'hybrid'
              : hasLink
              ? 'online'
              : 'in_person',
          if (hasLink) 'link': link.text.trim(),
          if (hasVenue) 'venue': venue.text.trim(),
          'starts_at': when.toIso8601String(),
          'ends_at': when.add(const Duration(hours: 1)).toIso8601String(),
        });
      },
    );
  }

  Future<void> _task(BuildContext context) {
    final title = TextEditingController();
    final where = TextEditingController();
    int? member = people.isEmpty ? null : people.first['id'] as int;
    final start = DateTime.now().add(const Duration(hours: 1));
    return _sheet(
      context,
      'Assign a task',
      [
        StatefulBuilder(
          builder: (c, set) => DropdownButtonFormField<int>(
            initialValue: member,
            decoration: const InputDecoration(labelText: 'To'),
            items: [
              for (final p in people)
                DropdownMenuItem(
                  value: p['id'] as int,
                  child: Text('${p['name']} · ${p['role_label']}'),
                ),
            ],
            onChanged: (v) => set(() => member = v),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'What to do'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: where,
          decoration: const InputDecoration(labelText: 'Where (optional)'),
        ),
      ],
      () => session.api.post('/teams/$teamId/tasks', {
        'member_id': member,
        'title': title.text.trim(),
        if (where.text.trim().isNotEmpty) 'location': where.text.trim(),
        'starts_at': start.toIso8601String(),
        'ends_at': start.add(const Duration(hours: 4)).toIso8601String(),
      }),
    );
  }
}

/// Search across the whole team: a person, a phone number, a department or a ghat.
class _TeamSearch extends SearchDelegate<void> {
  _TeamSearch({
    required this.session,
    required this.ghats,
    required this.manageable,
  }) : super(searchFieldLabel: 'Name, phone or department – e.g. parking');
  final Session session;
  final List<Json> ghats;
  final Set<int> manageable;

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final q = query.trim().toLowerCase();
    final rows = <Widget>[];
    for (final g in ghats) {
      final gHit = q.isEmpty || (g['name'] as String).toLowerCase().contains(q);
      final heads = (g['heads'] as List).cast<Json>();
      final people = <Json>[
        for (final h in heads) {...h, 'where': '${g['name']} ghat'},
        for (final d in (g['departments'] as List).cast<Json>())
          for (final p in (d['people'] as List).cast<Json>())
            {...p, 'where': '${d['name']} · ${g['name']}', 'dept': d['name']},
      ];
      final hits = people
          .where(
            (p) =>
                gHit ||
                (p['name'] as String).toLowerCase().contains(q) ||
                ((p['mobile'] as String?) ?? '').contains(q) ||
                ((p['dept'] as String?) ?? '').toLowerCase().contains(q),
          )
          .toList();
      if (!gHit && hits.isEmpty) continue;
      rows.add(
        ListTile(
          leading: CircleAvatar(
            backgroundColor: _hex(g['color'] as String?),
            child: const Icon(Icons.groups_rounded, color: Colors.white),
          ),
          title: Text(
            g['name'] as String,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('${(g['counts'] as Json)['departments']} departments'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  GhatScreen(session: session, ghat: g, manageable: manageable),
            ),
          ),
        ),
      );
      if (q.isNotEmpty) {
        for (final p in hits.take(12)) {
          rows.add(
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PersonTile(p: p, dense: true),
                  Padding(
                    padding: const EdgeInsets.only(left: 52, bottom: 4),
                    child: Text(
                      p['where'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }
    return rows.isEmpty
        ? const EmptyNote('No one found.')
        : ListView(children: rows);
  }
}
