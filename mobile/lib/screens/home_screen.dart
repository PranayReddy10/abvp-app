import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.session, required this.onShowPass});
  final Session session;
  final VoidCallback onShowPass;

  @override
  Widget build(BuildContext context) {
    final p = session.me!.profile!;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: session.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('नमस्ते', style: text.bodySmall),
                  Text(p.fullName, style: text.headlineSmall),
                ]),
              ),
              Initials(p.fullName, photoUrl: p.photoUrl),
            ]),
            const SizedBox(height: 18),
            _MemberCard(name: p.fullName, memberId: p.memberId ?? '', area: p.orgUnitLabel ?? '', vibhags: p.vibhags.map((v) => v.name).join(', ')),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onShowPass, icon: const Icon(Icons.qr_code_2), label: const Text('Show my pass')),
            const SizedBox(height: 24),
            Text('Dayitva', style: text.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: p.responsibilities.isEmpty
                    ? Text('Responsibilities your office assigns will appear here.', style: text.bodySmall)
                    : Column(
                        children: p.responsibilities
                            .map((r) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(children: [
                                    SizedBox(width: 82, child: Text(r.years, style: text.bodySmall)),
                                    Expanded(child: Text('${r.title}${r.place != null ? ', ${r.place}' : ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                  ]),
                                ))
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.saffronSoft, borderRadius: BorderRadius.circular(16)),
              child: Text('Meetings, circulars, Vibhag updates and events are coming to this screen in the next update.',
                  style: text.bodyMedium?.copyWith(color: AppColors.saffronInk)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.name, required this.memberId, required this.area, required this.vibhags});
  final String name, memberId, area, vibhags;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w600);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: AppColors.ink,
        child: Stack(children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.saffron, width: 16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('MEMBER ID', style: label),
              const SizedBox(height: 2),
              Text(memberId, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
              const SizedBox(height: 14),
              const Text('AREA', style: label),
              Text(area, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              if (vibhags.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('VIBHAGS', style: label),
                Text(vibhags, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
