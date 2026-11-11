import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../../widgets/motion.dart';
import '../help_screen.dart';
import 'guide_sections.dart';
import 'guide_widgets.dart';

/// "26 Dec · Starts in 45 days" or "Day 2 · Live now".
(String, bool) guideWhen(Json event) {
  final s = DateTime.parse(event['starts_at'] as String).toLocal();
  final e = DateTime.parse(event['ends_at'] as String).toLocal();
  final now = DateTime.now();
  if (now.isAfter(s) && now.isBefore(e)) {
    final day =
        DateTime(
          now.year,
          now.month,
          now.day,
        ).difference(DateTime(s.year, s.month, s.day)).inDays +
        1;
    return ('Day $day · Live now', true);
  }
  final days = DateTime(
    s.year,
    s.month,
    s.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  final date = '${s.day} ${monthShort(s)}';
  return (
    days <= 0
        ? '$date · Today'
        : days == 1
        ? '$date · Tomorrow'
        : '$date · in $days days',
    false,
  );
}

/// The conference guide: every service a delegate needs, with whom to call.
class GuideHub extends StatefulWidget {
  const GuideHub({
    super.key,
    required this.session,
    required this.eventId,
    this.landing = false,
  });
  final Session session;
  final int eventId;

  /// Opened by itself when the app starts near the event: shows "Continue to app".
  final bool landing;

  @override
  State<GuideHub> createState() => _GuideHubState();
}

class _GuideHubState extends State<GuideHub> {
  Json? _hub;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await widget.session.api.get(
        '/events/${widget.eventId}/guide',
      ) as Json;
      if (mounted) setState(() => _hub = h);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _openSection(Json s) {
    final hub = _hub!;
    if (s['kind'] == 'support' && hub['signed_in'] != true) {
      final helpline = (hub['event'] as Json)['helpline'] as String?;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Need help?',
                  style: TextStyle(
                    fontFamily: 'Anek',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Call the helpline now, or sign in with your mobile number to raise a ticket and get replies here.',
                  style: TextStyle(color: AppColors.muted, fontSize: 15),
                ),
                const SizedBox(height: 18),
                if (helpline != null) ...[
                  FilledButton.icon(
                    onPressed: () => callNumber(helpline),
                    icon: const Icon(Icons.call_rounded),
                    label: Text('Call helpline $helpline'),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Sign in to raise a ticket'),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    if (s['kind'] == 'support') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AskHelpScreen(
            session: widget.session,
            eventId: widget.eventId,
            eventTitle: hub['event']['title'] as String,
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => GuideSectionScreen(
          session: widget.session,
          event: hub['event'] as Json,
          kind: s['kind'] as String,
          title: s['title'] as String,
          hindi: s['hindi'] as String,
          myRegion: hub['my_region'] as String?,
        ),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hub = _hub;
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: widget.landing && hub != null
          ? PopIn(
              index: 12,
              child: Pressable(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55171A2E),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Continue to app',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: _error != null
          ? SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CircleIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ErrorBanner(_error!),
                ],
              ),
            )
          : hub == null
          ? const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: SkeletonList(rows: 6),
              ),
            )
          : RefreshIndicator(onRefresh: _load, child: _content(hub)),
    );
  }

  Widget _content(Json hub) {
    final event = hub['event'] as Json;
    final top = MediaQuery.paddingOf(context).top;
    final (whenText, live) = guideWhen(event);
    final sections = [
      ...(hub['sections'] as List).cast<Json>(),
      {
        'kind': 'support',
        'title': 'Support',
        'hindi': 'सहायता',
        'count': hub['open_tickets'] ?? 0,
      },
    ];
    final myStays = (hub['my_stays'] as List).cast<Json>();
    final helpline = event['helpline'] as String?;

    final tiles = sections.where((x) => x['kind'] != 'support').toList();
    final support = sections.firstWhere((x) => x['kind'] == 'support');

    return CustomScrollView(
      slivers: [
        // Header and the "my stay" card in one box so the card can overlap the header.
        SliverToBoxAdapter(
          child: Column(
            children: [
              Container(
                height: 330 + top,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.saffron,
                      AppColors.saffronDeep,
                      AppColors.ink,
                    ],
                    stops: [0, 0.42, 1],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(36),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (event['cover_url'] != null)
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.22,
                          child: Image.network(
                            event['cover_url'] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    const Positioned.fill(child: FloatingOrbs()),
                    Positioned(
                      left: 16,
                      right: 16,
                      top: top + 10,
                      child: Row(
                        children: [
                          if (!widget.landing)
                            CircleIconButton(
                              icon: Icons.arrow_back,
                              tooltip: 'Back',
                              onTap: () => Navigator.pop(context),
                            )
                          else
                            Pressable(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Skip',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (helpline != null)
                            Tooltip(
                              message: 'Call the helpline $helpline',
                              child: Pressable(
                                onTap: () => callNumber(helpline),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    16,
                                    10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.headset_mic_rounded,
                                        size: 18,
                                        color: AppColors.saffronInk,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Helpline',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 22,
                      right: 22,
                      bottom: 64,
                      child: FadeSlideIn(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (live)
                                    const PulseDot(
                                      color: Color(0xFF4ADE80),
                                      size: 8,
                                    )
                                  else
                                    const SizedBox(width: 6),
                                  Text(
                                    whenText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Conference guide · अधिवेशन मार्गदर्शिका',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              event['title'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Anek',
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_rounded,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    event['venue'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FadeSlideIn(
                    index: 2,
                    child: _MyStay(
                      stays: myStays,
                      region: hub['my_region'] as String?,
                      onFind: () => _openSection(sections.first),
                      onOpen: (stay) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GuideItemScreen(
                            session: widget.session,
                            event: event,
                            item: stay,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: const SectionTitle('Everything you need'),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverGrid.builder(
            itemCount: tiles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.80,
            ),
            itemBuilder: (_, i) => Transform.translate(
              offset: const Offset(0, -16),
              child: PopIn(
                index: i + 2,
                child: _Tile(
                  section: tiles[i],
                  onTap: () => _openSection(tiles[i]),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, widget.landing ? 120 : 40),
          sliver: SliverToBoxAdapter(
            child: PopIn(
              index: 11,
              child: _SupportCard(
                open: support['count'] as int? ?? 0,
                onTap: () => _openSection(support),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.open, required this.onTap});
  final int open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = kindOf('support');
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: k.gradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: k.b.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
              spreadRadius: -10,
            ),
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: 'guide-support',
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(k.icon, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'सहायता · Support',
                    style: TextStyle(
                      fontFamily: 'Anek',
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    open > 0
                        ? '$open open ticket${open == 1 ? '' : 's'} · raise another or check replies'
                        : 'Something wrong? Raise a ticket – the team replies here',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.section, required this.onTap});
  final Json section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = section['kind'] as String;
    final k = kindOf(kind);
    final count = section['count'] as int? ?? 0;
    return Semantics(
      button: true,
      label: '${section['title']}, ${section['hindi']}',
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: kind == 'emergency'
                ? const Color(0xFFFFF1F1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'guide-$kind',
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: k.gradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: k.b.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Icon(k.icon, color: Colors.white, size: 24),
                    ),
                  ),
                  const Spacer(),
                  if (count > 0)
                    CountUp(
                      count,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: k.b,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                section['hindi'] as String,
                style: const TextStyle(
                  fontFamily: 'Anek',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                  height: 1.1,
                ),
              ),
              Text(
                section['title'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyStay extends StatelessWidget {
  const _MyStay({
    required this.stays,
    required this.region,
    required this.onFind,
    required this.onOpen,
  });
  final List<Json> stays;
  final String? region;
  final VoidCallback onFind;
  final ValueChanged<Json> onOpen;

  @override
  Widget build(BuildContext context) {
    final k = kindOf('stay');
    final stay = stays.firstOrNull;
    final lead = stay == null
        ? null
        : (stay['contacts'] as List)
              .cast<Json>()
              .where((c) => c['is_lead'] == true)
              .firstOrNull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22171A2E),
            blurRadius: 30,
            offset: Offset(0, 14),
            spreadRadius: -10,
          ),
        ],
      ),
      child: stay == null
          ? Pressable(
              onTap: onFind,
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: k.gradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(k.icon, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Where am I staying?',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Pick your prant to see your stay and its lead',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            )
          : Pressable(
              onTap: () => onOpen(stay),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: k.gradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(k.icon, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR STAY · ${(region ?? '').toUpperCase()}',
                          style: TextStyle(
                            color: k.b,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          stay['title'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          [
                            stay['location'],
                            if (lead != null) 'Lead: ${lead['name']}',
                          ].whereType<String>().join(' · '),
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
                  if (lead?['phone'] != null)
                    ContactActions(phone: lead!['phone'] as String),
                ],
              ),
            ),
    );
  }
}

/// Card on Home that opens the guide; shows the countdown or "live".
class GuideBanner extends StatelessWidget {
  const GuideBanner({
    super.key,
    required this.session,
    required this.data,
    this.onClosed,
  });
  final Session session;
  final Json data;
  final VoidCallback? onClosed;

  @override
  Widget build(BuildContext context) {
    final event = data['event'] as Json;
    final (whenText, live) = guideWhen(event);
    return Pressable(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                GuideHub(session: session, eventId: event['id'] as int),
          ),
        );
        onClosed?.call();
      },
      child: Container(
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.saffron, AppColors.saffronDeep, AppColors.ink],
            stops: [0, 0.45, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: FloatingOrbs()),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (live)
                        const PulseDot(color: Color(0xFF4ADE80), size: 8),
                      Text(
                        whenText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      const GuideTag('Conference guide', onDark: true),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event['title'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Anek',
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const Text(
                              'Stay · transport · food · help, all in one place',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const ArrowBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Near the event (two days before until it ends), open the guide first, once per app launch.
/// Delegates tap Skip or "Continue to app" to reach the usual app.
Future<void> maybeOpenGuide(BuildContext context, Session session) async {
  if (session.guideLandingShown) return;
  session.guideLandingShown = true;
  try {
    final rows = (await session.api.get('/me/guide-events') as List)
        .cast<Json>();
    final next = rows.where((r) => r['open_first'] == true).firstOrNull;
    if (next == null || !context.mounted) return;
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => GuideHub(
          session: session,
          eventId: (next['event'] as Json)['id'] as int,
          landing: true,
        ),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween(
              begin: 1.04,
              end: 1.0,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  } on ApiException {
    // No guide today; the usual app is fine.
  }
}

/// Guide cards for whoever is looking, signed in or not. Shows nothing when no guide is on.
class GuideEntry extends StatefulWidget {
  const GuideEntry({
    super.key,
    required this.session,
    this.padding = EdgeInsets.zero,
  });
  final Session session;
  final EdgeInsets padding;

  @override
  State<GuideEntry> createState() => _GuideEntryState();
}

class _GuideEntryState extends State<GuideEntry> {
  List<Json> _rows = const [];

  @override
  void initState() {
    super.initState();
    widget.session.api
        .get('/guide/events')
        .then((r) {
          if (mounted) setState(() => _rows = (r as List).cast<Json>());
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutCubic,
    child: Column(
      children: [
        for (final g in _rows)
          Padding(
            padding: widget.padding,
            child: FadeSlideIn(
              child: GuideBanner(session: widget.session, data: g),
            ),
          ),
      ],
    ),
  );
}
