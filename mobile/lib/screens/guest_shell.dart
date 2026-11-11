import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme.dart';
import 'events_screen.dart';
import 'guide/guide_hub.dart';
import 'guide/guide_widgets.dart' show Json;
import 'notifications_screen.dart';
import 'pass_screen.dart';

/// Invited guests: their invitations and passes, nothing else.
class GuestShell extends StatefulWidget {
  const GuestShell({super.key, required this.session});
  final Session session;

  @override
  State<GuestShell> createState() => _GuestShellState();
}

class _GuestShellState extends State<GuestShell> {
  int _tab = 0;

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
        const SnackBar(
          content: Text(
            'The conference guide opens once your invitation is confirmed.',
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
                'Namaste${name.isEmpty ? '' : ', ${name.split(' ').take(2).join(' ')}'}',
              ),
              actions: [
                IconButton(
                  tooltip: 'Conference guide',
                  icon: const Icon(Icons.explore_outlined),
                  onPressed: _openGuide,
                ),
                IconButton(
                  tooltip: 'Notifications',
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
                  child: const Text('Sign out'),
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
                  child: const Text(
                    'You have been invited as a guest. Your invitations and entry passes are below.',
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
          PassScreen(session: widget.session),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Invitations',
          ),
          NavigationDestination(icon: Icon(Icons.qr_code_2), label: 'Pass'),
        ],
      ),
    );
  }
}
