import 'package:flutter/material.dart';

import '../state/session.dart';
import '../widgets/kit.dart';
import 'feed_screen.dart';
import 'guide/guide_hub.dart';
import 'conference/conference.dart';
import 'profile_screen.dart';
import '../analytics.dart';
import '../l10n.dart';

/// Approved members: Home, Community, Me in a floating pill bar.
class MemberShell extends StatefulWidget {
  const MemberShell({super.key, required this.session});
  final Session session;

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => maybeOpenGuide(context, widget.session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      // The national conference first: delegate side, my seva, the whole team.
      ConferenceHome(
        session: widget.session,
        onOpenCommunity: () => setState(() => _tab = 1),
      ),
      FeedScreen(session: widget.session),
      ProfileScreen(session: widget.session),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: FloatingNavBar(
        index: _tab,
        onTap: (i) {
          setState(() => _tab = i);
          Analytics.screen(
            const ['Home', 'Community', 'Me', 'Me'][i.clamp(0, 3)],
          );
        },
        items: [
          (Icons.home_rounded, tr('nav.home')),
          (Icons.forum_rounded, tr('nav.community')),
          (Icons.person_rounded, tr('nav.me')),
        ],
      ),
    );
  }
}
