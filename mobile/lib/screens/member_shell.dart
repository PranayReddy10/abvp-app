import 'package:flutter/material.dart';

import '../state/session.dart';
import '../widgets/kit.dart';
import 'calendar_screen.dart';
import 'feed_screen.dart';
import 'guide/guide_hub.dart';
import 'home_screen.dart';
import 'pass_screen.dart';
import 'profile_screen.dart';

/// Approved members: Home, Community, Pass, Calendar, Me in a floating pill bar.
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
      HomeScreen(
        session: widget.session,
        onShowPass: () => setState(() => _tab = 2),
        onOpenCalendar: () => setState(() => _tab = 3),
        onOpenFeed: () => setState(() => _tab = 1),
      ),
      FeedScreen(session: widget.session),
      PassScreen(session: widget.session),
      CalendarScreen(session: widget.session),
      ProfileScreen(session: widget.session),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: FloatingNavBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          (Icons.home_rounded, 'Home'),
          (Icons.forum_rounded, 'Community'),
          (Icons.qr_code_2_rounded, 'Pass'),
          (Icons.calendar_month_rounded, 'Calendar'),
          (Icons.person_rounded, 'Me'),
        ],
      ),
    );
  }
}
