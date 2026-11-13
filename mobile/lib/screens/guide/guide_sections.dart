import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../api/api_client.dart';
import '../../l10n.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/kit.dart';
import '../../widgets/loader.dart';
import '../../widgets/motion.dart';
import 'guide_widgets.dart';

/// One guide section (stay, transport, food…): a coloured header, then the places in it.
class GuideSectionScreen extends StatefulWidget {
  const GuideSectionScreen({
    super.key,
    required this.session,
    required this.event,
    required this.kind,
    required this.title,
    required this.hindi,
    this.region,
    this.myRegion,
  });
  final Session session;
  final Json event;
  final String kind;
  final String title;
  final String hindi;
  final String? region;
  final String? myRegion;

  @override
  State<GuideSectionScreen> createState() => _GuideSectionScreenState();
}

class _GuideSectionScreenState extends State<GuideSectionScreen> {
  List<Json>? _items;
  List<Json> _regions = [];
  String? _error;
  String _q = '';
  String? _tag;
  Position? _here;
  bool _locating = false;

  GuideKind get k => kindOf(widget.kind);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.session.api.getWithMeta(
        '/events/${widget.event['id']}/guide/${widget.kind}',
      );
      if (!mounted) return;
      setState(() {
        _items = (r['data'] as List).cast<Json>();
        _regions = ((r['meta']?['regions'] as List?) ?? []).cast<Json>();
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('denied');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) setState(() => _here = p);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('sec.locFail'))));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  double? _kmFromMe(Json i) {
    if (_here == null || i['lat'] == null) return null;
    const r = 6371.0;
    double rad(num d) => d * math.pi / 180;
    final dLat = rad((i['lat'] as num) - _here!.latitude);
    final dLng = rad((i['lng'] as num) - _here!.longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(_here!.latitude)) *
            math.cos(rad(i['lat'] as num)) *
            math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void _open(Json item) => Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => GuideItemScreen(
        session: widget.session,
        event: widget.event,
        item: item,
      ),
      transitionsBuilder: (_, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(c),
            child: child,
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final count = widget.region == null
        ? _items?.length
        : _items?.where((i) => i['region'] == widget.region).length;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 190 + top,
                decoration: BoxDecoration(
                  gradient: k.gradient,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(34),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    const Positioned.fill(child: FloatingOrbs()),
                    Positioned(
                      left: 16,
                      top: top + 10,
                      child: CircleIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back',
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    Positioned(
                      right: 20,
                      bottom: 22,
                      child: Hero(
                        tag: 'guide-${widget.kind}',
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Icon(k.icon, color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      right: 110,
                      bottom: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appLang.value == 'en' ? widget.hindi : widget.title,
                            style: const TextStyle(
                              fontFamily: 'Anek',
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            widget.region ?? tr('kind.${widget.kind}'),
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
                          if (count != null)
                            Text(
                              widget.kind == 'stay' && widget.region == null
                                  ? tr('sec.prantsPlaces', {
                                      'p': _regions.length,
                                      'n': count,
                                    })
                                  : tr('sec.places', {'n': count}),
                              style: const TextStyle(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
              sliver: SliverList.list(children: _body()),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body() {
    if (_error != null) return [ErrorBanner(_error!)];
    final items = _items;
    if (items == null) return const [SkeletonList(rows: 4)];
    if (items.isEmpty) {
      return [EmptyNote(tr('sec.empty'))];
    }
    return switch (widget.kind) {
      'stay' when widget.region == null => _regionsGrid(),
      'stay' => _cards(
        items.where((i) => i['region'] == widget.region).toList(),
      ),
      'arrival' => _arrivals(items),
      'food' || 'facility' || 'office' => _filtered(items),
      'exhibit' => [ExhibitCarousel(items: items, onOpen: _open)],
      'tourist' => [ExhibitCarousel(items: items, onOpen: _open, tall: false)],
      'session' => _sessions(items),
      'emergency' => _emergency(items),
      _ => _cards(items),
    };
  }

  // ---- Accommodation: pick your prant ----
  List<Widget> _regionsGrid() {
    final q = _q.toLowerCase();
    final regions = _regions
        .where((r) => (r['region'] as String).toLowerCase().contains(q))
        .toList();
    final mine = widget.myRegion;
    if (mine != null) {
      regions.sort(
        (a, b) => (a['region'] == mine ? 0 : 1).compareTo(
          b['region'] == mine ? 0 : 1,
        ),
      );
    }
    return [
      TextField(
        onChanged: (v) => setState(() => _q = v),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded),
          hintText: tr('sec.searchPrant'),
        ),
      ),
      const SizedBox(height: 16),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: regions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
        ),
        itemBuilder: (_, i) {
          final r = regions[i];
          final name = r['region'] as String;
          final isMine = name == mine;
          return PopIn(
            index: i,
            child: Pressable(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GuideSectionScreen(
                    session: widget.session,
                    event: widget.event,
                    kind: 'stay',
                    title: widget.title,
                    hindi: widget.hindi,
                    region: name,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: isMine ? k.gradient : null,
                  color: isMine ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isMine
                                ? Colors.white24
                                : k.a.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            name.substring(0, 1),
                            style: TextStyle(
                              fontFamily: 'Anek',
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: isMine ? Colors.white : k.b,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isMine)
                          GuideTag(tr('sec.yourPrant'), onDark: true)
                        else
                          Icon(Icons.north_east, size: 18, color: k.b),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        height: 1.15,
                        color: isMine ? Colors.white : AppColors.ink,
                      ),
                    ),
                    Text(
                      '${r['count']} place${r['count'] == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isMine ? Colors.white70 : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ];
  }

  // ---- Transport: find the nearest desk ----
  List<Widget> _arrivals(List<Json> items) {
    final sorted = [...items];
    if (_here != null) {
      sorted.sort(
        (a, b) => (_kmFromMe(a) ?? 1e9).compareTo(_kmFromMe(b) ?? 1e9),
      );
    }
    final nearest = _here == null ? null : sorted.first;
    return [
      Pressable(
        onTap: _locating ? null : _locate,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: k.gradient,
                  shape: BoxShape.circle,
                ),
                child: _locating
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nearest == null
                          ? tr('sec.justArrived')
                          : tr('sec.nearestDesk'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      nearest == null
                          ? tr('sec.findNearest')
                          : '${nearest['title']} · ${tr('sec.kmAway', {'km': _kmFromMe(nearest)!.toStringAsFixed(1)})}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      for (final (i, it) in sorted.indexed)
        FadeSlideIn(
          index: i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GuideCard(
              item: it,
              highlight: nearest != null && it == nearest,
              leading: _arrivalIcon(it['title'] as String),
              fromMeKm: _kmFromMe(it),
              onTap: () => _open(it),
            ),
          ),
        ),
    ];
  }

  IconData _arrivalIcon(String t) {
    final s = t.toLowerCase();
    if (s.contains('airport')) return Icons.flight_land_rounded;
    if (s.contains('bus')) return Icons.directions_bus_rounded;
    return Icons.train_rounded;
  }

  // ---- Food, offices, campus: filter by tag ----
  List<Widget> _filtered(List<Json> items) {
    final tags = <String>{
      for (final i in items) ...(i['tags'] as List).cast<String>(),
    }.toList();
    final shown = _tag == null
        ? items
        : items.where((i) => (i['tags'] as List).contains(_tag)).toList();
    return [
      if (tags.length > 1) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              PillChip(
                label: tr('sec.all'),
                selected: _tag == null,
                onTap: () => setState(() => _tag = null),
              ),
              for (final t in tags) ...[
                const SizedBox(width: 8),
                PillChip(
                  label: t,
                  selected: _tag == t,
                  onTap: () => setState(() => _tag = t),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      ..._cards(shown),
    ];
  }

  List<Widget> _cards(List<Json> items) => [
    for (final (i, it) in items.indexed)
      FadeSlideIn(
        index: i,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GuideCard(item: it, onTap: () => _open(it)),
        ),
      ),
  ];

  // ---- Baithak: the programme, day by day ----
  List<Widget> _sessions(List<Json> items) {
    final out = <Widget>[];
    String? day;
    for (final (i, it) in items.indexed) {
      final t = (it['timings'] as String?) ?? '';
      final parts = t.split(' · ');
      final d = parts.length > 1 ? parts.first : null;
      if (d != null && d != day) {
        day = d;
        out.add(
          Padding(
            padding: EdgeInsets.only(top: out.isEmpty ? 0 : 10, bottom: 10),
            child: Text(
              d,
              style: const TextStyle(
                fontFamily: 'Anek',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      out.add(
        FadeSlideIn(
          index: i,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    parts.length > 1 ? parts.last.split('–').first.trim() : t,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: k.b,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Container(
                  width: 3,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    gradient: k.gradient,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      onTap: () => _open(it),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it['title'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          if (it['subtitle'] != null)
                            Text(
                              it['subtitle'] as String,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          if (it['location'] != null) ...[
                            const SizedBox(height: 6),
                            _Line(
                              Icons.place_rounded,
                              it['location'] as String,
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
        ),
      );
    }
    return out;
  }

  // ---- Emergency: one big button and every number ----
  List<Widget> _emergency(List<Json> items) {
    bool isNumber(Json i) {
      final c = (i['contacts'] as List).cast<Json>();
      return c.isNotEmpty &&
          c.every(
            (x) =>
                ((x['phone'] as String?) ?? '')
                    .replaceAll(RegExp(r'[^0-9]'), '')
                    .length <
                6,
          );
    }

    final numbers = items.where(isNumber).toList();
    final halls = items.where((i) => !isNumber(i)).toList();
    final sos = numbers.firstOrNull;
    final sosPhone = sos == null
        ? null
        : (sos['contacts'] as List).first['phone'] as String;

    return [
      if (sosPhone != null) ...[
        Center(
          child: SosButton(
            label: sos!['title'] as String,
            phone: sosPhone,
            onTap: () => callNumber(sosPhone),
          ),
        ),
        Center(
          child: Text(
            tr('em.tapToCall'),
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 18),
      ],
      if (numbers.length > 1) ...[
        SectionTitle(tr('em.numbers')),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: numbers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final n = numbers[i];
              final phone = (n['contacts'] as List).first['phone'] as String;
              return PopIn(
                index: i,
                child: Pressable(
                  onTap: () => callNumber(phone),
                  child: Container(
                    width: 132,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0x33C81E1E)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.call_rounded,
                              color: Color(0xFFC81E1E),
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFC81E1E),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          n['title'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
      ],
      if (halls.isNotEmpty) ...[
        SectionTitle(tr('em.byHall')),
        Text(
          tr('em.byHallSub'),
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        for (final (i, h) in halls.indexed)
          FadeSlideIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _HallCard(item: h, onTap: () => _open(h)),
            ),
          ),
      ],
    ];
  }
}

/// One hall (or room) with its emergency lead members, ready to call.
class _HallCard extends StatelessWidget {
  const _HallCard({required this.item, required this.onTap});
  final Json item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = kindOf('emergency');
    final contacts = (item['contacts'] as List).cast<Json>();
    final hall = (item['location'] as String?) ?? (item['title'] as String);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(gradient: k.gradient),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.meeting_room_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hall,
                          style: const TextStyle(
                            fontFamily: 'Anek',
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          [item['title'], item['subtitle']]
                              .whereType<String>()
                              .where((t) => t != hall)
                              .join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (item['landmark'] != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: _Line(
                      Icons.info_outline_rounded,
                      item['landmark'] as String,
                      color: AppColors.ink,
                    ),
                  ),
                if (contacts.isEmpty)
                  const SizedBox.shrink()
                else
                  ContactTree(contacts: contacts, kind: k),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text, {this.color = AppColors.muted});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: TextStyle(color: color, fontSize: 13.5)),
        ),
      ],
    ),
  );
}

/// A place in the guide: accent colour, how to spot it, and its lead one tap away.
class GuideCard extends StatelessWidget {
  const GuideCard({
    super.key,
    required this.item,
    required this.onTap,
    this.leading,
    this.highlight = false,
    this.fromMeKm,
  });
  final Json item;
  final VoidCallback onTap;
  final IconData? leading;
  final bool highlight;
  final double? fromMeKm;

  @override
  Widget build(BuildContext context) {
    final k = kindOf(item['kind'] as String);
    final accent = hexColor(item['color'] as String?) ?? k.a;
    final lead = (item['contacts'] as List)
        .cast<Json>()
        .where((c) => c['is_lead'] == true)
        .firstOrNull;
    final photos = (item['photo_urls'] as List).cast<String>();
    final tags = (item['tags'] as List).cast<String>();
    final km = item['distance_km'] as num?;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          border: highlight ? Border.all(color: accent, width: 2) : null,
          boxShadow: highlight
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                    spreadRadius: -8,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photos.isNotEmpty)
              SizedBox(
                height: 140,
                child: Image.network(
                  photos.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: accent),
                ),
              )
            else
              Container(height: 6, color: accent),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(leading ?? k.icon, color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (highlight)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  children: [
                                    PulseDot(color: accent, size: 7),
                                    Text(
                                      tr('sec.nearestToYou'),
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              item['title'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16.5,
                                height: 1.2,
                              ),
                            ),
                            if (item['subtitle'] != null)
                              Text(
                                item['subtitle'] as String,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (km != null || fromMeKm != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            GuideTag(
                              '${(fromMeKm ?? km!).toStringAsFixed(fromMeKm != null ? 1 : 0)} km',
                              color: accent,
                            ),
                            if (fromMeKm != null)
                              Text(
                                tr('sec.fromYou'),
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  if (item['location'] != null &&
                      item['kind'] != 'arrival') ...[
                    const SizedBox(height: 10),
                    _Line(
                      Icons.place_rounded,
                      item['location'] as String,
                      color: AppColors.ink,
                    ),
                  ],
                  if (item['landmark'] != null)
                    _Line(
                      item['kind'] == 'emergency'
                          ? Icons.info_outline_rounded
                          : Icons.visibility_rounded,
                      item['kind'] == 'emergency'
                          ? item['landmark'] as String
                          : tr('sec.lookFor', {
                              'x': item['landmark'] as String,
                            }),
                    ),
                  if (item['timings'] != null)
                    _Line(Icons.schedule_rounded, item['timings'] as String),
                  if (item['travel_time'] != null && item['kind'] == 'arrival')
                    _Line(
                      Icons.route_rounded,
                      '${km != null ? '${km.toStringAsFixed(0)} km to venue · ' : ''}${item['travel_time']}',
                    ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in tags.take(4))
                          GuideTag(t, color: accent),
                      ],
                    ),
                  ],
                  // Emergency numbers: the number itself is the button.
                  if (lead != null &&
                      item['kind'] == 'emergency' &&
                      lead['name'] == item['title'] &&
                      lead['phone'] != null) ...[
                    const SizedBox(height: 12),
                    Pressable(
                      onTap: () => callNumber(lead['phone'] as String),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFC81E1E)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.call_rounded, color: Colors.white),
                            const SizedBox(width: 10),
                            Text(
                              tr('em.call', {'n': lead['phone'] as String}),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (lead != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                      decoration: BoxDecoration(
                        color: AppColors.ground,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Initials(lead['name'] as String, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lead['name'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  (lead['role'] as String?) ?? tr('d.lead'),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (lead['phone'] != null)
                            ContactActions(phone: lead['phone'] as String),
                        ],
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

/// Swipeable big picture cards; the picture slides slower than the card (parallax).
class ExhibitCarousel extends StatefulWidget {
  const ExhibitCarousel({
    super.key,
    required this.items,
    required this.onOpen,
    this.tall = true,
  });
  final List<Json> items;
  final ValueChanged<Json> onOpen;
  final bool tall;

  @override
  State<ExhibitCarousel> createState() => _ExhibitCarouselState();
}

class _ExhibitCarouselState extends State<ExhibitCarousel> {
  final _pc = PageController(viewportFraction: 0.86);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.tall ? 420.0 : 340.0;
    return Column(
      children: [
        SizedBox(
          height: h,
          child: OverflowBox(
            maxWidth: MediaQuery.sizeOf(context).width,
            child: PageView.builder(
              controller: _pc,
              itemCount: widget.items.length,
              itemBuilder: (_, i) {
                final it = widget.items[i];
                final d = (i - _page).clamp(-1.0, 1.0);
                final photos = (it['photo_urls'] as List).cast<String>();
                final k = kindOf(it['kind'] as String);
                return Transform.scale(
                  scale: 1 - d.abs() * 0.07,
                  child: Pressable(
                    onTap: () => widget.onOpen(it),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: k.gradient,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (photos.isNotEmpty)
                            Image.network(
                              photos.first,
                              fit: BoxFit.cover,
                              alignment: Alignment(d * 0.9, 0),
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x00000000),
                                  Color(0x00000000),
                                  Color(0xDD000000),
                                ],
                                stops: [0, 0.4, 1],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 20,
                            child: Transform.translate(
                              offset: Offset(d * 40, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (photos.length > 1)
                                    GuideTag(
                                      '${photos.length} photos',
                                      onDark: true,
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    it['title'] as String,
                                    style: const TextStyle(
                                      fontFamily: 'Anek',
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      height: 1.05,
                                    ),
                                  ),
                                  if (it['subtitle'] != null)
                                    Text(
                                      it['subtitle'] as String,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 15,
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (it['distance_km'] != null)
                                        GuideTag(
                                          '${(it['distance_km'] as num).toStringAsFixed(0)} km from venue',
                                          onDark: true,
                                        )
                                      else if (it['location'] != null)
                                        GuideTag(
                                          it['location'] as String,
                                          onDark: true,
                                        ),
                                      const Spacer(),
                                      const ArrowBadge(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.items.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: (_page.round() == i) ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: (_page.round() == i) ? AppColors.ink : AppColors.line,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Big red button with rings rippling out of it.
class SosButton extends StatefulWidget {
  const SosButton({
    super.key,
    required this.label,
    required this.phone,
    required this.onTap,
  });
  final String label;
  final String phone;
  final VoidCallback onTap;

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Call ${widget.label}, ${widget.phone}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 230,
          height: 230,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Stack(
              alignment: Alignment.center,
              children: [
                for (var r = 0; r < 3; r++)
                  Builder(
                    builder: (_) {
                      final v = (_c.value + r / 3) % 1;
                      return Container(
                        width: 130 + 100 * v,
                        height: 130 + 100 * v,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEF4444)
                              .withValues(alpha: 0.22 * (1 - v)),
                        ),
                      );
                    },
                  ),
                Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF6B6B), Color(0xFFC81E1E)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66C81E1E),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.call_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                      Text(
                        widget.phone,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
}

/// Everything about one place: photos, where, how to spot it, how to reach, whom to call.
class GuideItemScreen extends StatefulWidget {
  const GuideItemScreen({
    super.key,
    required this.session,
    required this.event,
    required this.item,
  });
  final Session session;
  final Json event;
  final Json item;

  @override
  State<GuideItemScreen> createState() => _GuideItemScreenState();
}

class _GuideItemScreenState extends State<GuideItemScreen> {
  int _photo = 0;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final k = kindOf(it['kind'] as String);
    final accent = hexColor(it['color'] as String?) ?? k.a;
    final photos = (it['photo_urls'] as List).cast<String>();
    final tags = (it['tags'] as List).cast<String>();
    final steps = (it['steps'] as List).cast<String>();
    final contacts = (it['contacts'] as List).cast<Json>();
    final km = it['distance_km'] as num?;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: photos.isEmpty ? 230 : 320,
            backgroundColor: k.b,
            foregroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(
                child: CircleIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ),
            leadingWidth: 68,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              titlePadding: const EdgeInsetsDirectional.only(
                start: 72,
                bottom: 16,
                end: 16,
              ),
              title: Text(
                it['title'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Anek',
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: photos.isEmpty && it['color'] != null
                          ? LinearGradient(
                              colors: [
                                accent,
                                Color.lerp(accent, Colors.black, 0.45)!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : k.gradient,
                    ),
                  ),
                  if (photos.isEmpty) ...[
                    const FloatingOrbs(),
                    Positioned(
                      right: 24,
                      top: MediaQuery.paddingOf(context).top + 56,
                      child: Icon(
                        k.icon,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ] else
                    PageView.builder(
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _photo = i),
                      itemBuilder: (_, i) => Image.network(
                        photos[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x55000000),
                          Color(0x00000000),
                          Color(0xAA000000),
                        ],
                        stops: [0, 0.4, 1],
                      ),
                    ),
                  ),
                  if (photos.length > 1)
                    Positioned(
                      right: 16,
                      bottom: 52,
                      child: GuideTag(
                        '${_photo + 1} / ${photos.length}',
                        onDark: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            sliver: SliverList.list(
              children: staggered([
                if (it['region'] != null)
                  Text(
                    (it['region'] as String).toUpperCase(),
                    style: TextStyle(
                      color: k.b,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      fontSize: 12.5,
                    ),
                  ),
                Text(
                  it['title'] as String,
                  style: const TextStyle(
                    fontFamily: 'Anek',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                if (it['subtitle'] != null)
                  Text(
                    it['subtitle'] as String,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 15.5,
                    ),
                  ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in tags) GuideTag(t, color: accent),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Panel(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Column(
                    children: [
                      if (it['location'] != null)
                        _InfoRow(
                          Icons.place_rounded,
                          tr('d.where'),
                          it['location'] as String,
                          accent,
                        ),
                      if (it['landmark'] != null)
                        _InfoRow(
                          Icons.visibility_rounded,
                          tr('d.lookFor'),
                          it['landmark'] as String,
                          accent,
                          swatch: it['color'] != null ? accent : null,
                        ),
                      if (it['timings'] != null)
                        _InfoRow(
                          Icons.schedule_rounded,
                          tr('d.timings'),
                          it['timings'] as String,
                          accent,
                        ),
                      if (km != null || it['travel_time'] != null)
                        _InfoRow(
                          Icons.route_rounded,
                          it['kind'] == 'arrival'
                              ? tr('d.toVenue')
                              : tr('d.fromVenue'),
                          [
                            if (km != null)
                              '${km.toStringAsFixed(km < 10 ? 1 : 0)} km${it['distance_is_road'] == true ? '' : ' ${tr('d.straight')}'}',
                            if (it['travel_time'] != null)
                              it['travel_time'] as String,
                          ].join(' · '),
                          accent,
                        ),
                    ],
                  ),
                ),
                if (it['directions_url'] != null || it['map_url'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (it['directions_url'] != null)
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: k.b),
                            onPressed: () =>
                                openUrl(it['directions_url'] as String),
                            icon: const Icon(Icons.navigation_rounded),
                            label: Text(
                              it['kind'] == 'arrival'
                                  ? tr('d.route')
                                  : tr('d.directions'),
                            ),
                          ),
                        ),
                      if (it['map_url'] != null) ...[
                        const SizedBox(width: 10),
                        CircleIconButton(
                          icon: Icons.map_rounded,
                          tooltip: 'Open map',
                          onTap: () => openUrl(it['map_url'] as String),
                        ),
                      ],
                    ],
                  ),
                ],
                if (it['description'] != null) ...[
                  const SizedBox(height: 22),
                  SectionTitle(tr('d.about')),
                  const SizedBox(height: 6),
                  Text(
                    it['description'] as String,
                    style: const TextStyle(fontSize: 15.5, height: 1.55),
                  ),
                ],
                if (steps.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  SectionTitle(
                    it['kind'] == 'arrival'
                        ? tr('d.howVenue')
                        : tr('d.howThere'),
                  ),
                  const SizedBox(height: 10),
                  StepsTimeline(steps: steps, kind: k),
                ],
                if (contacts.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  SectionTitle(
                    it['kind'] == 'emergency' ? tr('d.leads') : tr('d.contact'),
                  ),
                  const SizedBox(height: 10),
                  ContactTree(contacts: contacts, kind: k),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value, this.accent, {this.swatch});
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color? swatch;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  if (swatch != null) ...[
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
