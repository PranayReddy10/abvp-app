import 'package:flutter/material.dart';

import '../theme.dart';

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.color = AppColors.muted,
    this.background = AppColors.ground,
  });

  factory StatusPill.forStatus(String status) => switch (status) {
    'approved' => const StatusPill(
      'Approved',
      color: AppColors.ok,
      background: AppColors.okSoft,
    ),
    'submitted' => const StatusPill(
      'Under review',
      color: AppColors.warn,
      background: AppColors.warnSoft,
    ),
    'more_info_required' => const StatusPill(
      'Needs correction',
      color: AppColors.warn,
      background: AppColors.warnSoft,
    ),
    'rejected' => const StatusPill(
      'Not approved',
      color: AppColors.bad,
      background: AppColors.badSoft,
    ),
    _ => const StatusPill('Draft'),
  };

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.badSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bad.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.bad, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.bad,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Initials extends StatelessWidget {
  const Initials(this.name, {super.key, this.size = 40, this.photoUrl});
  final String name;
  final double size;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.saffronSoft,
      foregroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
      child: Text(
        letters.toUpperCase(),
        style: TextStyle(
          color: AppColors.saffronInk,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// Label above a value, used on profile and review screens.
class Fact extends StatelessWidget {
  const Fact(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '–' : value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
