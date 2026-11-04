import 'package:flutter/material.dart';

import '../theme.dart';

/// Fades and lifts its child into place, with a short delay per [index] so lists
/// arrive one item after another. Off when the phone asks for reduced motion.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  // The stagger delay is part of the curve (an Interval), so no timers are left running.
  static const _base = 420;
  late final int _delay = 40 * widget.index.clamp(0, 8);
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: _base + _delay))..forward();
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Interval(_delay / (_base + _delay), 1, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - _t.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Wraps each item so a list arrives in a gentle cascade.
List<Widget> staggered(List<Widget> items) => [
  for (var i = 0; i < items.length; i++) FadeSlideIn(index: i, child: items[i]),
];

/// Shrinks slightly while pressed, like a physical button.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Placeholder boxes with a moving sheen, shown while a screen loads.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.rows = 5});
  final int rows;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final shader = LinearGradient(
          colors: const [
            Color(0xFFECEEF3),
            Color(0xFFF8F9FB),
            Color(0xFFECEEF3),
          ],
          stops: const [0.1, 0.5, 0.9],
          begin: Alignment(-1.5 + 3 * _c.value, 0),
          end: Alignment(-0.5 + 3 * _c.value, 0),
        );
        Widget box(double h, {double? w, double r = 12}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            gradient: shader,
            borderRadius: BorderRadius.circular(r),
          ),
        );
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          children: [
            for (var i = 0; i < widget.rows; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      box(44, w: 44, r: 14),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            box(14, w: 180),
                            const SizedBox(height: 8),
                            box(12, w: 120),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Blue tick for profiles an office has verified.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 18, this.label = false});
  final double size;
  final bool label;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.verified,
      size: size,
      color: AppColors.verified,
      semanticLabel: 'Verified',
    );
    if (!label) return Tooltip(message: 'Verified by the office', child: icon);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 10, 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F0FD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          const Text(
            'Verified',
            style: TextStyle(
              color: AppColors.verified,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// A name with the blue tick after it when verified.
class NameWithBadge extends StatelessWidget {
  const NameWithBadge(
    this.name, {
    super.key,
    required this.verified,
    this.style,
    this.badgeSize = 16,
  });
  final String name;
  final bool verified;
  final TextStyle? style;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name),
          if (verified)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: VerifiedBadge(size: badgeSize),
              ),
            ),
        ],
      ),
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
