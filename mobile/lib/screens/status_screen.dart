import 'package:flutter/material.dart';

import '../l10n.dart';

import 'package:intl/intl.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Where the application stands, who has it, and what to fix.
class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key, required this.session});
  final Session session;

  static Map<String, String> get _labels => {
    'submitted': t('Application submitted'),
    'resubmitted': t('Resubmitted with corrections'),
    'returned': t('Returned for correction'),
    'approved': t('Approved'),
    'rejected': t('Not approved'),
  };

  @override
  Widget build(BuildContext context) {
    final app = session.me!.application!;
    final fmt = DateFormat('d MMM, h:mm a');
    final needsFix = app.status == 'more_info_required';
    final rejected = app.status == 'rejected';

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Application')),
        actions: [
          TextButton(onPressed: session.signOut, child: Text(t('Sign out'))),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: session.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: StatusPill.forStatus(app.status),
            ),
            const SizedBox(height: 16),
            if ((needsFix || rejected) && app.decisionNote != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: rejected ? AppColors.badSoft : AppColors.warnSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rejected
                          ? t('Message from {x}', {
                              'x': app.reviewingOffice ?? t('the office'),
                            })
                          : t('Returned by {x}', {
                              'x': app.reviewingOffice ?? t('the office'),
                            }),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: rejected ? AppColors.bad : AppColors.warn,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(app.decisionNote!),
                  ],
                ),
              ),
            if (needsFix) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => session.editApplication(true),
                child: Text(t('Fix and resubmit')),
              ),
            ],
            if (app.status == 'submitted')
              Text(
                t(
                  'Your application is with {x}. You will be notified when they decide. Pull down to check again.',
                  {'x': app.reviewingOffice ?? t('your district office')},
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _step(context, true, t('Mobile verified'), null),
                    ...app.history.map(
                      (h) => _step(
                        context,
                        true,
                        _labels[h.action] ?? h.action,
                        fmt.format(h.at),
                        warn: h.action == 'returned',
                        bad: h.action == 'rejected',
                      ),
                    ),
                    if (app.status == 'submitted')
                      _step(
                        context,
                        false,
                        t('Approval and Member ID'),
                        t('Usually within 7 days'),
                        last: true,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(
    BuildContext context,
    bool done,
    String title,
    String? sub, {
    bool warn = false,
    bool bad = false,
    bool last = false,
  }) {
    final color = bad
        ? AppColors.bad
        : warn
        ? AppColors.warn
        : done
        ? AppColors.ok
        : AppColors.line;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done ? color : null,
              border: done ? null : Border.all(color: color, width: 2),
              shape: BoxShape.circle,
            ),
            child: done
                ? Icon(
                    bad
                        ? Icons.close
                        : warn
                        ? Icons.priority_high
                        : Icons.check,
                    size: 14,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: done ? AppColors.ink : AppColors.muted,
                  ),
                ),
                if (sub != null)
                  Text(sub, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
