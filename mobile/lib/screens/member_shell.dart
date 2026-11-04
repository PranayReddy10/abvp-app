import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'pass_screen.dart';
import 'profile_screen.dart';
import 'vibhags_screen.dart';

/// Approved members: Home, Calendar, Pass (raised, in the middle), Vibhags, Me.
class MemberShell extends StatefulWidget {
  const MemberShell({super.key, required this.session});
  final Session session;

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(session: widget.session, onShowPass: () => setState(() => _tab = 2), onOpenCalendar: () => setState(() => _tab = 1)),
      CalendarScreen(session: widget.session),
      PassScreen(session: widget.session),
      VibhagsScreen(session: widget.session),
      ProfileScreen(session: widget.session),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: AppColors.saffron, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.qr_code_2, color: Colors.white),
            ),
            label: 'Pass',
          ),
          const NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Vibhags'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
