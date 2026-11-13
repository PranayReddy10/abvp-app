import 'package:flutter/material.dart';

import '../theme.dart';
import 'motion.dart';
import '../l10n.dart';

/// Round white icon button used in top bars (back, bell, filter).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.dark = false,
    this.accent = false,
    this.badge,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool dark;
  final bool accent;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final bg = accent
        ? AppColors.saffron
        : dark
        ? AppColors.ink
        : AppColors.surface;
    final fg = accent || dark ? Colors.white : AppColors.ink;
    Widget btn = Pressable(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: accent
              ? const [
                  BoxShadow(
                    color: Color(0x55E3620C),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: fg, size: 22),
      ),
    );
    if (badge != null && badge! > 0) {
      btn = Badge(
        label: Text('$badge'),
        offset: const Offset(-4, 4),
        child: btn,
      );
    }
    return tooltip == null
        ? btn
        : Tooltip(
            message: tooltip!,
            child: Semantics(button: true, label: tooltip, child: btn),
          );
  }
}

/// Pill chip with an icon; dark when selected, as in the references.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
  });
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.ink,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w600,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain white rounded panel.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.color = AppColors.surface,
  });
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, child: box);
  }
}

/// Section title with an optional "See all" on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Anek',
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

/// Round translucent arrow used on image cards.
class ArrowBadge extends StatelessWidget {
  const ArrowBadge({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white24),
    ),
    child: const Icon(Icons.north_east, color: Colors.white, size: 20),
  );
}

/// Floating dark pill navigation bar with round icons; the selected one turns saffron.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });
  final List<(IconData, String)> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Center(
        heightFactor: 1,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40171A2E),
                blurRadius: 24,
                offset: Offset(0, 10),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: items[i].$2,
                    child: Tooltip(
                      message: items[i].$2,
                      child: Pressable(
                        onTap: () => onTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          width: i == index ? 64 : 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: i == index
                                ? AppColors.saffron
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(
                            items[i].$1,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
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
}

/// A ticket with a perforated divider and side notches, like a boarding pass.
class TicketClipper extends CustomClipper<Path> {
  TicketClipper(this.notchY, {this.radius = 14});
  final double notchY;
  final double radius;

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28)),
      );
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, notchY), radius: radius))
      ..addOval(
        Rect.fromCircle(center: Offset(size.width, notchY), radius: radius),
      );
    return Path.combine(PathOperation.difference, path, notches);
  }

  @override
  bool shouldReclip(TicketClipper old) => old.notchY != notchY;
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key, this.color = AppColors.line});
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Row(
      children: List.generate(
        (c.maxWidth / 10).floor(),
        (_) => Container(
          width: 5,
          height: 1.5,
          margin: const EdgeInsets.only(right: 5),
          color: color,
        ),
      ),
    ),
  );
}

String greeting() {
  final h = DateTime.now().hour;
  return h < 12
      ? tr('home.morning')
      : h < 17
      ? tr('home.afternoon')
      : tr('home.evening');
}
