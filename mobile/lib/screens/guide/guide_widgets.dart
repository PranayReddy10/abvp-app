import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

typedef Json = Map<String, dynamic>;

/// Look of each guide section: icon and a two-colour gradient.
class GuideKind {
  const GuideKind(this.icon, this.a, this.b);
  final IconData icon;
  final Color a;
  final Color b;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [a, b],
  );
}

const guideKinds = <String, GuideKind>{
  'stay': GuideKind(Icons.bed_rounded, Color(0xFF8B7BFF), Color(0xFF5A46D6)),
  'arrival': GuideKind(
    Icons.directions_bus_rounded,
    Color(0xFF4A9BFF),
    Color(0xFF1E5FD0),
  ),
  'food': GuideKind(
    Icons.restaurant_rounded,
    Color(0xFFFFA24C),
    Color(0xFFE3620C),
  ),
  'office': GuideKind(
    Icons.apartment_rounded,
    Color(0xFF2CC7B4),
    Color(0xFF0E8577),
  ),
  'session': GuideKind(Icons.mic_rounded, Color(0xFF7B88FF), Color(0xFF3B47C4)),
  'exhibit': GuideKind(
    Icons.photo_library_rounded,
    Color(0xFFF06AAE),
    Color(0xFFB72F72),
  ),
  'facility': GuideKind(
    Icons.local_parking_rounded,
    Color(0xFF7C8BA3),
    Color(0xFF3B4659),
  ),
  'tourist': GuideKind(
    Icons.temple_hindu_rounded,
    Color(0xFFF5B83D),
    Color(0xFFC07F00),
  ),
  'emergency': GuideKind(
    Icons.emergency_rounded,
    Color(0xFFFF6363),
    Color(0xFFC81E1E),
  ),
  'support': GuideKind(
    Icons.support_agent_rounded,
    Color(0xFF3DD68C),
    Color(0xFF138A4F),
  ),
};

GuideKind kindOf(String k) => guideKinds[k] ?? guideKinds['office']!;

Color? hexColor(String? hex) {
  if (hex == null || hex.length != 7) return null;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

/// Digits only, with India's code for a 10-digit number. Short numbers (108, 112) stay as they are.
String dialable(String phone) {
  final d = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  return d;
}

Future<void> callNumber(String phone) =>
    launchUrl(Uri.parse('tel:${dialable(phone)}'));

Future<void> whatsapp(String phone) {
  var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 10) d = '91$d';
  return launchUrl(
    Uri.parse('https://wa.me/$d'),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> openUrl(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Slowly drifting translucent circles over a gradient: the guide's living header.
class FloatingOrbs extends StatefulWidget {
  const FloatingOrbs({super.key, this.color = Colors.white});
  final Color color;

  @override
  State<FloatingOrbs> createState() => _FloatingOrbsState();
}

class _FloatingOrbsState extends State<FloatingOrbs>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return CustomPaint(painter: _OrbPainter(0, widget.color));
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) =>
          CustomPaint(painter: _OrbPainter(_c.value, widget.color)),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const orbs = [
      (0.85, 0.15, 0.42, 0.10, 0.0),
      (0.10, 0.70, 0.30, 0.07, 1.7),
      (0.55, 0.95, 0.26, 0.08, 3.1),
      (0.35, 0.25, 0.14, 0.12, 4.4),
      (0.95, 0.75, 0.18, 0.06, 5.2),
    ];
    for (final (x, y, r, alpha, phase) in orbs) {
      final a = t * 2 * math.pi + phase;
      final c = Offset(
        size.width * (x + 0.04 * math.sin(a)),
        size.height * (y + 0.05 * math.cos(a * 0.8)),
      );
      canvas.drawCircle(
        c,
        size.width * r,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
    // A thin ring, like the brand mark on the member card.
    final ring = Offset(
      size.width * (0.92 + 0.02 * math.sin(t * 2 * math.pi)),
      size.height * 0.05,
    );
    canvas.drawCircle(
      ring,
      size.width * 0.22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = color.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}

/// Pops in with a little overshoot, one after another by [index].
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 420 + widget.index.clamp(0, 12) * 55),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start =
        (widget.index.clamp(0, 12) * 55) /
        (420 + widget.index.clamp(0, 12) * 55);
    final scale = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1, curve: Curves.easeOutBack),
    );
    final fade = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween(begin: 0.82, end: 1.0).animate(scale),
        child: widget.child,
      ),
    );
  }
}

/// A dot with a ring that keeps expanding out of it: "live", "open now", SOS.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = AppColors.ok, this.size = 10});
  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.4,
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s * (1 + 1.4 * _c.value),
              height: s * (1 + 1.4 * _c.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
              ),
            ),
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded tag.
class GuideTag extends StatelessWidget {
  const GuideTag(
    this.label, {
    super.key,
    this.color = AppColors.ink,
    this.onDark = false,
  });
  final String label;
  final Color color;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: onDark
          ? Colors.white.withValues(alpha: 0.18)
          : color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: onDark ? Colors.white : color,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
    ),
  );
}

/// Round call / WhatsApp buttons.
class ContactActions extends StatelessWidget {
  const ContactActions({super.key, required this.phone, this.light = false});
  final String phone;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final short = phone.replaceAll(RegExp(r'[^0-9]'), '').length < 6;
    Widget btn(
      IconData icon,
      String tip,
      Color bg,
      Color fg,
      VoidCallback onTap,
    ) => Tooltip(
      message: tip,
      child: Pressable(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, color: fg, size: 20),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!short)
          btn(
            Icons.chat_rounded,
            'WhatsApp $phone',
            light ? Colors.white24 : const Color(0xFFE7F8EE),
            light ? Colors.white : const Color(0xFF1FA855),
            () => whatsapp(phone),
          ),
        btn(
          Icons.call_rounded,
          'Call $phone',
          light ? Colors.white : AppColors.ok,
          light ? AppColors.ink : Colors.white,
          () => callNumber(phone),
        ),
      ],
    );
  }
}

/// Lead(s) on top in a bold card, the team below joined by a tree line.
class ContactTree extends StatelessWidget {
  const ContactTree({super.key, required this.contacts, required this.kind});
  final List<Json> contacts;
  final GuideKind kind;

  @override
  Widget build(BuildContext context) {
    final leads = contacts.where((c) => c['is_lead'] == true).toList();
    final team = contacts.where((c) => c['is_lead'] != true).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in leads.indexed)
          FadeSlideIn(
            index: i,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              decoration: BoxDecoration(
                gradient: kind.gradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: kind.b.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(c['name'] as String),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                (c['role'] as String?) ?? tr('d.lead'),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        NameWithBadge(
                          c['name'] as String,
                          verified: c['verified'] == true,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                          ),
                        ),
                        if (c['phone'] != null)
                          Text(
                            c['phone'] as String,
                            style: const TextStyle(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                  if (c['phone'] != null)
                    ContactActions(phone: c['phone'] as String, light: true),
                ],
              ),
            ),
          ),
        for (final (i, c) in team.indexed)
          FadeSlideIn(
            index: leads.length + i,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 30,
                    child: CustomPaint(
                      painter: _TreeLine(
                        last: i == team.length - 1,
                        color: kind.b.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Initials(c['name'] as String, size: 38),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                NameWithBadge(
                                  c['name'] as String,
                                  verified: c['verified'] == true,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  [
                                    c['role'],
                                    c['phone'],
                                  ].whereType<String>().join(' · '),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (c['phone'] != null)
                            ContactActions(phone: c['phone'] as String),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w[0].toUpperCase())
    .join();

class _TreeLine extends CustomPainter {
  _TreeLine({required this.last, required this.color});
  final bool last;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final x = 14.0;
    final mid = (size.height - 8) / 2;
    final path = Path()
      ..moveTo(x, -10)
      ..lineTo(x, mid - 10)
      ..quadraticBezierTo(x, mid, x + 10, mid)
      ..lineTo(size.width, mid);
    canvas.drawPath(path, p);
    if (!last) canvas.drawLine(Offset(x, mid - 10), Offset(x, size.height), p);
  }

  @override
  bool shouldRepaint(_TreeLine old) => old.last != last || old.color != color;
}

/// Numbered steps joined by a line that draws itself in.
class StepsTimeline extends StatelessWidget {
  const StepsTimeline({super.key, required this.steps, required this.kind});
  final List<String> steps;
  final GuideKind kind;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, s) in steps.indexed)
          FadeSlideIn(
            index: i + 1,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 36,
                    child: Column(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: kind.gradient,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (i < steps.length - 1)
                          Expanded(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(milliseconds: 500 + i * 180),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, _) => Align(
                                alignment: Alignment.topCenter,
                                child: FractionallySizedBox(
                                  heightFactor: v,
                                  child: Container(
                                    width: 2,
                                    color: kind.a.withValues(alpha: 0.45),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 18),
                      child: Text(
                        s,
                        style: const TextStyle(fontSize: 15, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Count that rolls up from zero.
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.style});
  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text('${v.round()}', style: style),
  );
}
