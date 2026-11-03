import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Where the application stands, who has it, and what to fix.
class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key, required this.session});
  final Session session;

  static const _labels = {
    'submitted': 'Application submitted',
    'resubmitted': 'Resubmitted with corrections',
    'returned': 'Returned for correction',
    'approved': 'Approved',
    'rejected': 'Not approved',
  };

  @override
  Widget build(BuildContext context) {
    final app = session.me!.application!;
    final fmt = DateFormat('d MMM, h:mm a');
    final needsFix = app.status == 'more_info_required';
    final rejected = app.status == 'rejected';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Application'),
        actions: [TextButton(onPressed: session.signOut, child: const Text('Sign out'))],
      ),
      body: RefreshIndicator(
        onRefresh: session.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Align(alignment: Alignment.centerLeft, child: StatusPill.forStatus(app.status)),
            const SizedBox(height: 16),
            if ((needsFix || rejected) && app.decisionNote != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: rejected ? AppColors.badSoft : AppColors.warnSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rejected ? 'Message from ${app.reviewingOffice ?? 'the office'}' : 'Returned by ${app.reviewingOffice ?? 'the office'}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: rejected ? AppColors.bad : AppColors.warn)),
                  const SizedBox(height: 4),
                  Text(app.decisionNote!),
                ]),
              ),
            if (needsFix) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: () => session.editApplication(true), child: const Text('Fix and resubmit')),
            ],
            if (app.status == 'submitted')
              Text('Your application is with ${app.reviewingOffice ?? 'your district office'}. You will be notified when they decide. Pull down to check again.',
                  style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _step(context, true, 'Mobile verified', null),
                  ...app.history.map((h) => _step(context, true, _labels[h.action] ?? h.action, fmt.format(h.at),
                      warn: h.action == 'returned', bad: h.action == 'rejected')),
                  if (app.status == 'submitted') _step(context, false, 'Approval and Member ID', 'Usually within 7 days', last: true),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(BuildContext context, bool done, String title, String? sub, {bool warn = false, bool bad = false, bool last = false}) {
    final color = bad ? AppColors.bad : warn ? AppColors.warn : done ? AppColors.ok : AppColors.line;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: done ? color : null, border: done ? null : Border.all(color: color, width: 2), shape: BoxShape.circle),
          child: done ? Icon(bad ? Icons.close : warn ? Icons.priority_high : Icons.check, size: 14, color: Colors.white) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: done ? AppColors.ink : AppColors.muted)),
            if (sub != null) Text(sub, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }
}
