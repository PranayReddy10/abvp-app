import 'package:flutter/material.dart';

import '../l10n.dart';
import '../state/session.dart';
import '../theme.dart';
import 'events_screen.dart';
import 'guide/guide_hub.dart';
import 'guide/guide_widgets.dart' show Json;
import 'notifications_screen.dart';

/// Invited guests: their invitations and passes, nothing else.
class GuestShell extends StatefulWidget {
  const GuestShell({super.key, required this.session});
  final Session session;

  @override
  State<GuestShell> createState() => _GuestShellState();
}

class _GuestShellState extends State<GuestShell> {
  final int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => maybeOpenGuide(context, widget.session),
    );
  }

  Future<void> _openGuide() async {
    final rows = (await widget.session.api.get('/me/guide-events') as List)
        .cast<Json>();
    if (!mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('The conference guide opens once your invitation is confirmed.'),
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GuideHub(
          session: widget.session,
          eventId: (rows.first['event'] as Json)['id'] as int,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.session.me?.name ?? '';
    return Scaffold(
      appBar: _tab == 0
          ? AppBar(
              title: Text(
                '${t('Namaste')}${name.isEmpty ? '' : ', ${name.split(' ').take(2).join(' ')}'}',
              ),
              actions: [
                IconButton(
                  tooltip: t('Conference guide'),
                  icon: const Icon(Icons.explore_outlined),
                  onPressed: _openGuide,
                ),
                IconButton(
                  tooltip: t('Notifications'),
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          NotificationsScreen(session: widget.session),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.session.signOut,
                  child: Text(t('Sign out')),
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _tab,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.saffronSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    t(
                      'You have been invited as a guest. Your invitations are below.',
                    ),
                    style: TextStyle(
                      color: AppColors.saffronInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(child: EventsList(session: widget.session)),
            ],
          ),
        ],
      ),
    );
  }
}
