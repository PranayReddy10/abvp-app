import 'package:flutter/material.dart';

import '../state/session.dart';
import 'home_screen.dart';
import 'pass_screen.dart';
import 'profile_screen.dart';

/// Approved members. Calendar and Vibhags tabs arrive in phase 2.
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
      HomeScreen(session: widget.session, onShowPass: () => setState(() => _tab = 1)),
      PassScreen(session: widget.session),
      ProfileScreen(session: widget.session),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.qr_code_2), label: 'Pass'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
