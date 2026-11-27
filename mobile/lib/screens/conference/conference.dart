import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../edit_profile_screen.dart';
import '../guide/guide_hub.dart';
import '../guide/guide_sections.dart';
import 'delegate_form.dart';
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
  _HomeData(
    this.conference,
    this.seva,
    this.tree, [
    this.delegate,
    this.posts = const [],
  ]);

  /// The newest community posts, for the strip on Home.
  final List<Json> posts;
  final Json? conference;
  final Json seva;
  final Json? tree;

  /// GET /events/{id}/delegate: whether I have filled the delegate form.
  final Json? delegate;
  bool get isDelegate => delegate?['registration'] != null;
  List<Json> get places => ((seva['places'] as List?) ?? []).cast<Json>();
  List<Json> get chats => ((seva['chats'] as List?) ?? []).cast<Json>();
  List<Json> get ghats => ((tree?['ghats'] as List?) ?? []).cast<Json>();
  Set<int> get manageable => {
    for (final c in chats)
      if (c['can_manage'] == true) c['team_id'] as int,
  };
}

Future<_HomeData> _loadHome(Session session) async {
  final conf = await session.api.get('/conference') as Json?;
  final seva = await session.api.get('/me/seva') as Json;
  Json? tree;
  Json? delegate;
  var posts = <Json>[];
  if (conf != null && conf['has_teams'] == true) {
    tree = await session.api.get('/events/${conf['id']}/teams') as Json;
  }
  if (conf != null) {
    try {
      delegate =
          await session.api.get('/events/${conf['id']}/delegate') as Json?;
    } on ApiException {
      delegate = null;
    }
  }
  try {
    posts = ((await session.api.get('/feed') as List?) ?? [])
        .cast<Json>()
        .where((p) => p['hidden'] != true)
        .take(6)
        .toList();
  } on ApiException {
    posts = [];
  }
  return _HomeData(conf, seva, tree, delegate, posts);
}

/// Home: a saffron header with me in it, the conference with a live countdown, quick actions,
/// the delegate and volunteer sides, a thought for the day, my volunteer team and the newest
/// community posts.
class ConferenceHome extends StatelessWidget {
  const ConferenceHome({
    super.key,
    required this.session,
    this.onOpenCommunity,
  });
  final Session session;
  final VoidCallback? onOpenCommunity;

  @override
  Widget build(BuildContext context) {
    return Loader<_HomeData>(
      load: () => _loadHome(session),
      builder: (context, d, reload) => RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _HomeHeader(session: session, data: d),
            Transform.translate(
              offset: const Offset(0, -46),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (d.conference == null)
                      const Panel(
                        child: EmptyNote(
                          'The conference details appear here once it is published.',
                        ),
                      )
                    else ...[
                      FadeSlideIn(child: _Countdown(conf: d.conference!)),
                      const SizedBox(height: 18),
                      FadeSlideIn(
                        index: 1,
                        child: _QuickButtons(
                          session: session,
                          data: d,
                          onChanged: reload,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FadeSlideIn(
                        index: 2,
                        child: _SideTiles(
                          session: session,
                          data: d,
                          onChanged: reload,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const FadeSlideIn(index: 3, child: _Thought()),
                    if (d.places.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      FadeSlideIn(
                        index: 4,
                        child: _MySeva(
                          session: session,
                          data: d,
                          onChanged: reload,
                        ),
                      ),
                    ],
                    if (d.posts.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      FadeSlideIn(
                        index: 5,
                        child: _CommunityStrip(
                          posts: d.posts,
                          onOpen: onOpenCommunity,
                        ),
                      ),
                    ],
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

/// The whole conference team: my volunteer place, every ghat as a card, and how to join.
class VolunteerScreen extends StatelessWidget {
  const VolunteerScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Loader<_HomeData>(
        load: () => _loadHome(session),
        builder: (context, d, reload) => RefreshIndicator(
          onRefresh: reload,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 150,
                backgroundColor: const Color(0xFFC24F06),
                foregroundColor: Colors.white,
                actions: [
                  if (d.ghats.isNotEmpty)
                    IconButton(
                      tooltip: 'Search the team',
                      icon: const Icon(Icons.search_rounded),
                      onPressed: () => showSearch(
                        context: context,
                        delegate: _TeamSearch(
                          session: session,
                          ghats: d.ghats,
                          manageable: d.manageable,
                        ),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text(
                    'Volunteer',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  background: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF08A3C), Color(0xFFC24F06)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Align(
                      alignment: const Alignment(0.85, 0.1),
                      child: Icon(
                        Icons.volunteer_activism_rounded,
                        size: 90,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                sliver: SliverList.list(
                  children: [
                    if (d.places.isNotEmpty) ...[
                      _MySeva(session: session, data: d, onChanged: reload),
                      const SizedBox(height: 22),
                    ],
                    if (d.ghats.isEmpty)
                      const EmptyNote('The conference team appears here soon.')
                    else ...[
                      const SectionTitle('Conference team'),
                      const SizedBox(height: 10),
                      _GhatGrid(
                        session: session,
                        ghats: d.ghats,
                        manageable: d.manageable,
                        onChanged: reload,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The saffron header of Home: me (photo with a turning ring), greeting, member ID, area, what I
/// am at the conference, and notifications. Soft circles drift behind it.
class _HomeHeader extends StatefulWidget {
  const _HomeHeader({required this.session, required this.data});
  final Session session;
  final _HomeData data;

  @override
  State<_HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<_HomeHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final me = session.me;
    final p = me?.profile;
    final name = p?.fullName.isNotEmpty == true
        ? p!.fullName
        : (me?.name ?? '');
    final hour = DateTime.now().hour;
    final hello = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final chips = <(IconData, String)>[
      if (widget.data.isDelegate) (Icons.badge_rounded, 'Delegate'),
      for (final pl in widget.data.places.take(2))
        (
          Icons.volunteer_activism_rounded,
          '${pl['role_label']} · ${(pl['team'] as Json)['name']}',
        ),
      if (p?.status == 'approved') (Icons.verified_rounded, 'Member'),
    ];
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 14, 20, 66),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF59A4C), AppColors.saffron, Color(0xFFB8430A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Drifting circles: a gentle sense of motion behind the header.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _spin,
              builder: (_, _) {
                final t = _spin.value * 2 * 3.14159;
                Widget dot(double size, double x, double y, double a) =>
                    Positioned(
                      right: x + 10 * math.cos(t + a),
                      top: y + 8 * math.sin(t + a),
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                    );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    dot(140, -50, -60, 0),
                    dot(70, 90, 40, 2),
                    dot(36, 30, 96, 4),
                  ],
                );
              },
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(session: session),
                      ),
                    ),
                    child: SizedBox(
                      width: 66,
                      height: 66,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          RotationTransition(
                            turns: _spin,
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    Colors.white,
                                    Color(0xFFFFD7AE),
                                    Color(0x00FFFFFF),
                                    Colors.white,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 59,
                            height: 59,
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Initials(
                              name,
                              photoUrl: p?.photoUrl,
                              size: 55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$hello ',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const _Wave(),
                          ],
                        ),
                        Text(
                          name.isEmpty ? 'Welcome' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Anek',
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          [p?.memberId, p?.orgUnitLabel]
                              .whereType<String>()
                              .where((x) => x.isNotEmpty)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Notifications',
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotificationsScreen(session: session),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (icon, label) in chips)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 15, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A small namaste that bows now and then.
class _Wave extends StatefulWidget {
  const _Wave();

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      final t = _c.value;
      final bow = t < 0.3 ? (t < 0.15 ? t / 0.15 : (0.3 - t) / 0.15) : 0.0;
      return Transform.rotate(angle: -0.35 * bow, child: child);
    },
    child: const Text('🙏', style: TextStyle(fontSize: 14)),
  );
}

/// Delegate: the form the first time (when registration is open); after that the guide.
/// With [edit], a registered delegate opens their form again to change it.
Future<void> _openDelegate(
  BuildContext context,
  Session session,
  _HomeData data,
  Future<void> Function() onChanged, {
  bool edit = false,
}) async {
  final conf = data.conference!;
  final id = conf['id'] as int;
  if (!data.isDelegate || edit) {
    final d = data.delegate;
    if (d == null || (!data.isDelegate && d['open'] != true)) {
      await _registrationClosed(context, session);
      return;
    }
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DelegateFormScreen(session: session, eventId: id, data: d),
      ),
    );
    await onChanged();
    if (done != true || edit || !context.mounted) return;
  }
  if (!context.mounted) return;
  if (conf['guide_enabled'] == true) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuideHub(session: session, eventId: id),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'You are registered as a delegate. The guide opens closer to the conference.',
        ),
      ),
    );
  }
}

/// The guide is for delegates: anyone else is asked to fill the delegate form first.
Future<void> _openGuide(
  BuildContext context,
  Session session,
  _HomeData data,
  Future<void> Function() onChanged,
) async {
  if (data.isDelegate) {
    return _openDelegate(context, session, data, onChanged);
  }
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.explore_rounded,
        size: 36,
        color: AppColors.saffron,
      ),
      title: const Text('Fill the delegate form first'),
      content: const Text(
        'The conference guide – your stay, transport, food and help desk – opens once you have filled the delegate form.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Fill the form'),
        ),
      ],
    ),
  );
  if (go == true && context.mounted) {
    await _openDelegate(context, session, data, onChanged);
  }
}

/// Registration is switched off for the event: say so clearly (and tell admins where to switch it on).
Future<void> _registrationClosed(BuildContext context, Session session) {
  final perms = ((session.me?.json['permissions'] as List?) ?? [])
      .cast<String>();
  final admin = perms.contains('events.manage');
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(
        Icons.event_busy_rounded,
        size: 36,
        color: AppColors.saffron,
      ),
      title: const Text('Delegate registration is not open yet'),
      content: Text(
        admin
            ? 'Switch it on in the admin panel: Events → the conference → Guide → "Delegate registration". The form opens here straight away after that.'
            : 'The form opens here as soon as registration starts. You will get a notification.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Round actions: guide (delegates), gallery, the team, helpline.
class _QuickButtons extends StatelessWidget {
  const _QuickButtons({
    required this.session,
    required this.data,
    required this.onChanged,
  });
  final Session session;
  final _HomeData data;
  final Future<void> Function() onChanged;
  Json get conf => data.conference!;

  @override
  Widget build(BuildContext context) {
    final guide = conf['guide_enabled'] == true;
    Widget b(IconData icon, String label, List<Color> colors, VoidCallback f) =>
        Expanded(
          child: Pressable(
            onTap: f,
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.last.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
    return Row(
      children: [
        b(Icons.explore_rounded, 'Guide', const [
          Color(0xFFF59A4C),
          AppColors.saffronDeep,
        ], () => _openGuide(context, session, data, onChanged)),
        b(
          Icons.photo_library_rounded,
          'Gallery',
          const [Color(0xFFFFB35C), Color(0xFFD9730D)],
          () => guide
              ? Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GuideSectionScreen(
                      session: session,
                      event: conf,
                      kind: 'gallery',
                      title: 'Gallery',
                      hindi: 'चित्र दीर्घा',
                    ),
                  ),
                )
              : ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Photos appear here during the conference.'),
                  ),
                ),
        ),
        b(
          Icons.diversity_3_rounded,
          'Team',
          const [Color(0xFFEF8354), Color(0xFFB8430A)],
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VolunteerScreen(session: session),
            ),
          ),
        ),
        b(
          Icons.support_agent_rounded,
          'Helpline',
          const [Color(0xFFFF9F43), Color(0xFFC75C00)],
          () {
            final h = conf['helpline'] as String?;
            if (h != null) _call(h);
          },
        ),
      ],
    );
  }
}

/// The conference with a live countdown: days, hours, minutes and seconds ticking.
class _Countdown extends StatefulWidget {
  const _Countdown({required this.conf});
  final Json conf;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conf = widget.conf;
    final start = DateTime.parse(conf['starts_at'] as String);
    final end = DateTime.parse(conf['ends_at'] as String);
    final now = DateTime.now();
    final left = start.difference(now);
    final live = now.isAfter(start) && now.isBefore(end);
    final over = now.isAfter(end);
    Widget unit(int v, String label) => Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.saffronSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (c, a) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, -0.5),
                  end: Offset.zero,
                ).animate(a),
                child: FadeTransition(opacity: a, child: c),
              ),
              child: Text(
                v.toString().padLeft(2, '0'),
                key: ValueKey(v),
                style: const TextStyle(
                  fontFamily: 'Anek',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.saffronDeep,
                ),
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.saffronInk,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.saffron.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.saffronSoft, width: 2),
                ),
                child: Image.asset('assets/brand/emblem.png'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conf['title'] as String,
                      style: const TextStyle(
                        fontFamily: 'Anek',
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_ist(conf['starts_at'] as String, 'd')}–${_ist(conf['ends_at'] as String, 'd MMM yyyy')} · ${conf['venue']}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (over)
            const Text(
              'Thank you for being part of it.',
              style: TextStyle(fontWeight: FontWeight.w700),
            )
          else if (live)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59A4C), AppColors.saffronDeep],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '● Happening now',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            )
          else
            Row(
              children: [
                unit(left.inDays, 'DAYS'),
                unit(left.inHours % 24, 'HOURS'),
                unit(left.inMinutes % 60, 'MINS'),
                unit(left.inSeconds % 60, 'SECS'),
              ],
            ),
        ],
      ),
    );
  }
}

/// Delegate side and volunteer side, side by side, in saffron.
class _SideTiles extends StatelessWidget {
  const _SideTiles({
    required this.session,
    required this.data,
    required this.onChanged,
  });
  final Session session;
  final _HomeData data;
  final Future<void> Function() onChanged;

  /// Registered delegates choose: open the guide or change their form.
  Future<void> _delegate(BuildContext context) async {
    if (!data.isDelegate) {
      return _openDelegate(context, session, data, onChanged);
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.explore_rounded,
                color: AppColors.saffron,
              ),
              title: const Text('Open the conference guide'),
              onTap: () => Navigator.pop(ctx, 'guide'),
            ),
            ListTile(
              leading: const Icon(
                Icons.edit_note_rounded,
                color: AppColors.saffron,
              ),
              title: const Text('Change my delegate form'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    await _openDelegate(
      context,
      session,
      data,
      onChanged,
      edit: choice == 'edit',
    );
  }

  @override
  Widget build(BuildContext context) {
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
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -14,
                bottom: -14,
                child: Icon(
                  icon,
                  size: 90,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
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
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    maxLines: 2,
                  ),
                ],
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
          data.isDelegate
              ? 'Registered ✓ · open guide'
              : 'Fill the delegate form',
          data.isDelegate ? Icons.verified_rounded : Icons.badge_rounded,
          const [Color(0xFFF59A4C), Color(0xFFC24F06)],
          () => _delegate(context),
        ),
        const SizedBox(width: 12),
        tile(
          'Volunteer',
          seva
              ? (data.places.first['team'] as Json)['name'] as String
              : 'Ghats, departments, team',
          Icons.volunteer_activism_rounded,
          const [Color(0xFFFFB35C), Color(0xFFD9730D)],
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VolunteerScreen(session: session),
              ),
            );
            onChanged();
          },
        ),
      ],
    );
  }
}

/// A thought for the day – a new one each day.
class _Thought extends StatelessWidget {
  const _Thought();

  static const _thoughts = [
    (
      'Arise, awake, and stop not till the goal is reached.',
      'Swami Vivekananda',
    ),
    (
      'Education is the manifestation of the perfection already in man.',
      'Swami Vivekananda',
    ),
    ('Take up one idea. Make that one idea your life.', 'Swami Vivekananda'),
    ('Strength is life, weakness is death.', 'Swami Vivekananda'),
    ('The future depends on what you do today.', 'Mahatma Gandhi'),
    ('Be the change that you wish to see in the world.', 'Mahatma Gandhi'),
    ('Character, once lost, is lost forever.', 'Swami Vivekananda'),
  ];

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().difference(DateTime(2026)).inDays;
    final (text, by) = _thoughts[day % _thoughts.length];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: AppColors.saffronSoft, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFF59A4C), AppColors.saffronDeep],
              ),
            ),
            child: const Icon(
              Icons.format_quote_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THOUGHT FOR TODAY',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.saffron,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '“$text”',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '— $by',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
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

/// The newest community posts as swipeable cards.
class _CommunityStrip extends StatelessWidget {
  const _CommunityStrip({required this.posts, this.onOpen});
  final List<Json> posts;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'From the community',
          action: onOpen == null ? null : 'See all',
          onAction: onOpen,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 170,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final p = posts[i];
              final a = (p['author'] as Json?) ?? {};
              final photos = ((p['photo_urls'] as List?) ?? []).cast<String>();
              return Pressable(
                onTap: onOpen,
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.saffron.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Initials(
                            a['name'] as String? ?? '?',
                            photoUrl: a['photo_url'] as String?,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              a['name'] as String? ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: photos.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  photos.first,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      Container(color: AppColors.saffronSoft),
                                ),
                              )
                            : Text(
                                p['body'] as String? ?? '',
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(height: 1.3),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            size: 15,
                            color: AppColors.saffron,
                          ),
                          const SizedBox(width: 4),
                          Text('${p['likes'] ?? 0}'),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.chat_bubble_rounded,
                            size: 14,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Text('${p['comments'] ?? 0}'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
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
        const SectionTitle('Volunteer'),
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
      // No inherited MediaQuery padding: inside the home list it left a big gap below.
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 196,
      ),
      itemCount: ghats.length,
      itemBuilder: (context, i) {
        final g = ghats[i];
        final c = _hex(g['color'] as String?);
        final heads = (g['heads'] as List).cast<Json>();
        final pramukh = heads
            .where((h) => h['role'] == 'ghat_pramukh')
            .toList();
        final counts = g['counts'] as Json;
        final bg = HSLColor.fromColor(c).withLightness(0.95).toColor();
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: c.withValues(alpha: 0.14)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: 34,
                    child: Icon(
                      _ghatIcon(g['name'] as String),
                      size: 70,
                      color: c.withValues(alpha: 0.07),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(c, Colors.white, 0.2)!,
                                  Color.lerp(c, Colors.black, 0.15)!,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _ghatIcon(g['name'] as String),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_outward_rounded,
                              size: 18,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        g['name'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          height: 1.15,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${counts['departments']} departments',
                        style: TextStyle(
                          color: Color.lerp(c, Colors.black, 0.2),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          if (heads.isNotEmpty) _AvatarStack(heads),
                          Expanded(
                            child: Text(
                              pramukh.isEmpty
                                  ? '${counts['people']} people'
                                  : (pramukh.first['name'] as String)
                                        .replaceFirst(
                                          RegExp(r'^(Shri|Kum|Dr|Smt)\.? '),
                                          '',
                                        ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

/// An icon for each ghat, falling back to the department icons.
IconData _ghatIcon(String name) {
  final n = name.toLowerCase();
  const map = <String, IconData>{
    'karyalaya': Icons.apartment_rounded,
    'baithak': Icons.forum_rounded,
    'yatha': Icons.directions_bus_rounded,
    'nivas': Icons.hotel_rounded,
    'bhojan': Icons.restaurant_rounded,
    'jala': Icons.water_drop_rounded,
    'nirmaan': Icons.construction_rounded,
    'karyakram': Icons.theater_comedy_rounded,
    'dvani': Icons.speaker_rounded,
    'prachar': Icons.campaign_rounded,
    'parisar': Icons.place_rounded,
    'athidi': Icons.emoji_people_rounded,
    'kosh': Icons.account_balance_wallet_rounded,
    'karyakarta': Icons.diversity_3_rounded,
    'aapoorti': Icons.local_shipping_rounded,
    'pradarshini': Icons.museum_rounded,
    'shobhayathra': Icons.flag_rounded,
  };
  for (final e in map.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return _deptIcon(name);
}

/// Role colours so a list of people reads at a glance.
Color _roleColor(String? role) => switch (role) {
  'ghat_pramukh' || 'pramukh' => AppColors.saffron,
  'ghat_saha_pramukh' || 'saha_pramukh' => const Color(0xFF7C4DDB),
  'ghat_palak' => const Color(0xFF0E9F8E),
  _ => const Color(0xFF2E55C9),
};

/// One person as a small card. Tap opens their details in a popup.
class PersonTile extends StatelessWidget {
  const PersonTile({super.key, required this.p, this.dense = false, this.team});
  final Json p;
  final bool dense;
  final String? team;

  @override
  Widget build(BuildContext context) {
    final m = p['mobile'] as String?;
    final rc = _roleColor(p['role'] as String?);
    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 6 : 10),
      child: Pressable(
        onTap: () => showPersonSheet(context, p, team: team),
        child: Container(
          padding: EdgeInsets.all(dense ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF171A2E).withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: rc, width: 2),
                ),
                child: Initials(
                  p['name'] as String,
                  photoUrl: p['photo_url'] as String?,
                  size: dense ? 36 : 44,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: rc.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            p['role_label'] as String? ?? '',
                            style: TextStyle(
                              color: rc,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (p['linked'] == true) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: AppColors.ok,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (m != null) ...[
                _RoundIcon(Icons.call_rounded, AppColors.ok, () => _call(m)),
                const SizedBox(width: 8),
                _RoundIcon(
                  Icons.chat_rounded,
                  const Color(0xFF25D366),
                  () => _wa(m),
                ),
              ] else
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A person's details as a popup: photo, role, team, phone, and Call / WhatsApp / Copy.
Future<void> showPersonSheet(BuildContext context, Json p, {String? team}) {
  final m = p['mobile'] as String?;
  final rc = _roleColor(p['role'] as String?);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    showDragHandle: false,
    builder: (ctx) => Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      rc.withValues(alpha: 0.18),
                      rc.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: rc, width: 3),
                      ),
                      child: Initials(
                        p['name'] as String,
                        photoUrl: p['photo_url'] as String?,
                        size: 88,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      p['name'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: rc,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        p['role_label'] as String? ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (team != null)
                      _InfoRow(Icons.groups_rounded, 'Team', team),
                    _InfoRow(
                      Icons.phone_rounded,
                      'Mobile',
                      m ??
                          (p['has_mobile'] == true
                              ? 'Sign in to see the number'
                              : 'No phone yet'),
                    ),
                    _InfoRow(
                      p['linked'] == true
                          ? Icons.verified_rounded
                          : Icons.phone_android_rounded,
                      'App',
                      p['linked'] == true
                          ? 'Using ABVP Connect'
                          : 'Not signed in yet',
                    ),
                    if (p['note'] != null &&
                        (p['note'] as String).trim().isNotEmpty)
                      _InfoRow(
                        Icons.notes_rounded,
                        'Note',
                        p['note'] as String,
                      ),
                    if (m != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.ok,
                                minimumSize: const Size.fromHeight(50),
                              ),
                              onPressed: () => _call(m),
                              icon: const Icon(Icons.call_rounded),
                              label: const Text('Call'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                minimumSize: const Size.fromHeight(50),
                              ),
                              onPressed: () => _wa(m),
                              icon: const Icon(Icons.chat_rounded),
                              label: const Text('WhatsApp'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: m));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Number copied')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy number'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.ground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.inkSoft),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
                const _Heading('Ghat heads'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    scrollDirection: Axis.horizontal,
                    itemCount: heads.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => FadeSlideIn(
                      index: i,
                      child: _HeadCard(
                        p: heads[i],
                        color: c,
                        team: ghat['name'] as String,
                      ),
                    ),
                  ),
                ),
                if (canGhat) ...[
                  const SizedBox(height: 12),
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
                const SizedBox(height: 22),
                _Heading('Departments', trailing: '${depts.length}'),
                const SizedBox(height: 10),
                for (var i = 0; i < depts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FadeSlideIn(
                      index: i,
                      child: _DeptCard(
                        dept: depts[i],
                        ghatName: ghat['name'] as String,
                        color: c,
                        shade: i,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DepartmentScreen(
                              session: session,
                              dept: depts[i],
                              ghatName: ghat['name'] as String,
                              color: c,
                              canManage:
                                  canGhat ||
                                  manageable.contains(depts[i]['id']),
                            ),
                          ),
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

/// Small section heading with an optional count pill.
class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        text,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      if (trailing != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.ground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            trailing!,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    ],
  );
}

/// An icon that fits the department, picked from its name.
IconData _deptIcon(String name) {
  final n = name.toLowerCase();
  const map = <String, IconData>{
    'kitchen': Icons.soup_kitchen_rounded,
    'bhojan': Icons.restaurant_rounded,
    'distribution': Icons.room_service_rounded,
    'tea': Icons.emoji_food_beverage_rounded,
    'leftover': Icons.recycling_rounded,
    'store': Icons.inventory_2_rounded,
    'apoorthi': Icons.local_shipping_rounded,
    'aapoorti': Icons.local_shipping_rounded,
    'medical': Icons.medical_services_rounded,
    'enquiry': Icons.support_agent_rounded,
    'suraksha': Icons.shield_rounded,
    'parking': Icons.local_parking_rounded,
    'sound': Icons.speaker_rounded,
    'light': Icons.lightbulb_rounded,
    'live': Icons.live_tv_rounded,
    'media': Icons.newspaper_rounded,
    'social': Icons.share_rounded,
    'photo': Icons.photo_camera_rounded,
    'stall': Icons.storefront_rounded,
    'decoration': Icons.celebration_rounded,
    'sajavat': Icons.celebration_rounded,
    'water': Icons.water_drop_rounded,
    'clean': Icons.cleaning_services_rounded,
    'tent': Icons.festival_rounded,
    'plumb': Icons.plumbing_rounded,
    'flag': Icons.flag_rounded,
    'stage': Icons.theater_comedy_rounded,
    'sabhagar': Icons.event_seat_rounded,
    'cultural': Icons.music_note_rounded,
    'conference': Icons.groups_rounded,
    'guest': Icons.emoji_people_rounded,
    'welcome': Icons.waving_hand_rounded,
    'reservation': Icons.confirmation_number_rounded,
    'paryatan': Icons.tour_rounded,
    'pratinidhi': Icons.badge_rounded,
    'boys': Icons.hotel_rounded,
    'girls': Icons.hotel_rounded,
    'teacher': Icons.school_rounded,
    'house': Icons.house_rounded,
    'office': Icons.apartment_rounded,
    'printing': Icons.print_rounded,
    'smaarika': Icons.menu_book_rounded,
    'nimantran': Icons.mail_rounded,
    'anumathi': Icons.verified_user_rounded,
    'account': Icons.account_balance_wallet_rounded,
    'vignapana': Icons.campaign_rounded,
    'vastu': Icons.category_rounded,
    'baithak': Icons.forum_rounded,
    'prastav': Icons.description_rounded,
    'samiti': Icons.groups_2_rounded,
    'nec': Icons.groups_2_rounded,
    'vistarak': Icons.directions_walk_rounded,
    'reserved': Icons.bolt_rounded,
    'pradarshini': Icons.museum_rounded,
    'shobhayathra': Icons.directions_run_rounded,
    'speech': Icons.mic_rounded,
    'central': Icons.hub_rounded,
    'vyavasta': Icons.settings_suggest_rounded,
  };
  for (final e in map.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return Icons.groups_rounded;
}

/// Soft pastel tints around the ghat colour, so a list of cards is lively but still belongs to its ghat.
Color _tint(Color c, int i) {
  final hsl = HSLColor.fromColor(c);
  final shifts = [0.0, 28.0, -24.0, 52.0];
  return hsl
      .withHue((hsl.hue + shifts[i % shifts.length]) % 360)
      .withSaturation((hsl.saturation * 0.75).clamp(0.35, 0.8))
      .withLightness(0.93)
      .toColor();
}

Color _deep(Color tint) {
  final hsl = HSLColor.fromColor(tint);
  return hsl.withLightness(0.36).withSaturation(0.6).toColor();
}

/// One ghat head: Pramukh, Saha Pramukh or Palak.
class _HeadCard extends StatelessWidget {
  const _HeadCard({required this.p, required this.color, this.team});
  final Json p;
  final Color color;
  final String? team;

  @override
  Widget build(BuildContext context) {
    final m = p['mobile'] as String?;
    return Pressable(
      onTap: () => showPersonSheet(context, p, team: team),
      child: _card(m),
    );
  }

  Widget _card(String? m) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Initials(
            p['name'] as String,
            photoUrl: p['photo_url'] as String?,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            p['name'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            p['role_label'] as String? ?? '',
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (m != null)
            Row(
              children: [
                _RoundIcon(Icons.call_rounded, AppColors.ok, () => _call(m)),
                const SizedBox(width: 8),
                _RoundIcon(
                  Icons.chat_rounded,
                  const Color(0xFF25D366),
                  () => _wa(m),
                ),
              ],
            )
          else
            const Text(
              'No phone yet',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon, this.color, this.onTap);
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.12),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(icon, size: 18, color: color),
      ),
    ),
  );
}

/// Overlapping initials, then +N.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack(this.people);
  final List<Json> people;
  static const max = 3;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(max).toList();
    final more = people.length - shown.length;
    return SizedBox(
      height: 32,
      width: shown.length * 22.0 + 10 + (more > 0 ? 34 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 22.0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Initials(
                  shown[i]['name'] as String,
                  photoUrl: shown[i]['photo_url'] as String?,
                  size: 28,
                ),
              ),
            ),
          if (more > 0)
            Positioned(
              left: shown.length * 22.0 + 6,
              top: 7,
              child: Text(
                '+$more',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A department as a soft card: icon, name, lead, how many can be reached, people, arrow.
class _DeptCard extends StatelessWidget {
  const _DeptCard({
    required this.dept,
    required this.ghatName,
    required this.color,
    required this.shade,
    required this.onTap,
  });
  final Json dept;
  final String ghatName;
  final Color color;
  final int shade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final people = (dept['people'] as List).cast<Json>();
    final leads = people
        .where((p) => p['role'] == 'pramukh' || p['role'] == 'saha_pramukh')
        .map((p) => p['name'] as String)
        .toList();
    final bg = _tint(color, shade);
    final ink = _deep(bg);
    final name = dept['name'] as String;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -6,
              top: -6,
              child: Icon(
                _deptIcon(name),
                size: 64,
                color: ink.withValues(alpha: 0.08),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [Color.lerp(ink, Colors.white, 0.25)!, ink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ink.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        _deptIcon(name),
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              leads.isEmpty ? 'Needs a Pramukh' : 'Pramukh',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: leads.isEmpty ? AppColors.bad : ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            leads.isEmpty ? ghatName : leads.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (people.isNotEmpty)
                      _AvatarStack(people)
                    else
                      const Text(
                        'No one yet',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    const SizedBox(width: 8),
                    if (people.isNotEmpty)
                      Text(
                        '${people.length} ${people.length == 1 ? 'person' : 'people'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    const Spacer(),
                    Container(
                      width: 44,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One department: its people with call and WhatsApp, and the heads' tools.
class DepartmentScreen extends StatelessWidget {
  const DepartmentScreen({
    super.key,
    required this.session,
    required this.dept,
    required this.ghatName,
    required this.color,
    required this.canManage,
  });
  final Session session;
  final Json dept;
  final String ghatName;
  final Color color;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final people = (dept['people'] as List).cast<Json>();
    final bg = _tint(color, 0);
    final ink = _deep(bg);
    final name = dept['name'] as String;
    final order = {'pramukh': 0, 'saha_pramukh': 1, 'volunteer': 2};
    final sorted = [
      ...people,
    ]..sort((a, b) => (order[a['role']] ?? 3).compareTo(order[b['role']] ?? 3));
    return Scaffold(
      backgroundColor: AppColors.ground,
      appBar: AppBar(backgroundColor: bg, foregroundColor: AppColors.ink),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'dept-${dept['id']}',
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: ink,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(_deptIcon(name), color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ghatName.toUpperCase(),
                        style: TextStyle(
                          color: ink,
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '${people.length} ${people.length == 1 ? 'person' : 'people'}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canManage) ...[
                  _HeadActions(
                    session: session,
                    teamId: dept['id'] as int,
                    isGhat: false,
                    people: people,
                  ),
                  const SizedBox(height: 14),
                ],
                if (sorted.isEmpty)
                  const EmptyNote('No one in this department yet.')
                else
                  for (var i = 0; i < sorted.length; i++)
                    FadeSlideIn(
                      index: i,
                      child: PersonTile(
                        p: sorted[i],
                        team: '$name · $ghatName',
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
    final idq = TextEditingController();
    Json? found;
    String? findError;
    return _sheet(
      context,
      isGhat ? 'Add a ghat head' : 'Add to this department',
      [
        StatefulBuilder(
          builder: (c, set) {
            Future<void> find() async {
              final q = idq.text.trim();
              if (q.length < 4) return;
              try {
                final r = await session.api.get(
                  '/team-members/lookup?q=${Uri.encodeQueryComponent(q)}',
                ) as Json;
                found = r;
                name.text = r['name'] as String? ?? '';
                mobile.text = (r['mobile'] as String? ?? '').replaceFirst(
                  '+91',
                  '',
                );
                set(() => findError = null);
              } on ApiException catch (e) {
                found = null;
                set(() => findError = e.message);
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: idq,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => find(),
                  onChanged: (_) {
                    if (found != null) set(() => found = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Member ID or mobile',
                    hintText: 'ABVP-TG-000123',
                    helperText: found == null
                        ? 'Fills the name and phone for you'
                        : null,
                    errorText: findError,
                    suffixIcon: IconButton(
                      tooltip: 'Find',
                      icon: const Icon(Icons.search_rounded),
                      onPressed: find,
                    ),
                  ),
                ),
                if (found != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.ok.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.ok,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              found!['name'],
                              found!['member_id'],
                              found!['area'],
                            ].whereType<String>().join(' · '),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
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
        if (found != null)
          'member_id': (found!['member_id'] ?? found!['mobile']) as String,
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
