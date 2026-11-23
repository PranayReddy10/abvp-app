import 'package:flutter/material.dart';

import '../l10n.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/password_sheet.dart';
import 'events_screen.dart';
import 'feed_screen.dart';
import 'guide/guide_hub.dart';
import 'notifications_screen.dart';
import 'pass_screen.dart';

/// Everyone signed in who is not (yet) an approved member: conference delegates, guests,
/// applicants. Community, events, the guide and passes work straight away; membership is
/// applied for from the Me tab.
class AccountShell extends StatefulWidget {
  const AccountShell({super.key, required this.session});
  final Session session;

  @override
  State<AccountShell> createState() => _AccountShellState();
}

class _AccountShellState extends State<AccountShell> {
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
      _Home(session: widget.session, onMe: () => setState(() => _tab = 3)),
      FeedScreen(session: widget.session),
      PassScreen(session: widget.session),
      AccountMeScreen(session: widget.session),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: FloatingNavBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          (Icons.home_rounded, tr('nav.home')),
          (Icons.forum_rounded, tr('nav.community')),
          (Icons.qr_code_2_rounded, tr('nav.pass')),
          (Icons.person_rounded, tr('nav.me')),
        ],
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.session, required this.onMe});
  final Session session;
  final VoidCallback onMe;

  @override
  Widget build(BuildContext context) {
    final me = session.me!;
    final name = me.profile?.fullName.isNotEmpty == true
        ? me.profile!.fullName
        : (me.name ?? '');
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Namaste${name.isEmpty ? '' : ', ${name.split(' ').first}'}',
                    style: text.headlineSmall,
                  ),
                ),
                CircleIconButton(
                  icon: Icons.notifications_none,
                  tooltip: 'Notifications',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationsScreen(session: session),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: GuideEntry(session: session),
          ),
          if (me.profile?.orgUnitId == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: FadeSlideIn(
                child: Panel(
                  color: AppColors.saffronSoft,
                  onTap: onMe,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        color: AppColors.saffronInk,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Add your district and photo in Me, so you see events and posts near you and can apply for membership.',
                          style: TextStyle(
                            color: AppColors.saffronInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.saffronInk,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text(tr('nav.events'), style: text.titleLarge),
          ),
          Expanded(child: EventsList(session: session)),
        ],
      ),
    );
  }
}

/// Me for non-members: details and area, membership, password, language, sign out.
class AccountMeScreen extends StatelessWidget {
  const AccountMeScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final me = session.me;
        if (me == null) return const SizedBox.shrink();
        final p = me.profile;
        final app = me.application;
        final name = p?.fullName.isNotEmpty == true
            ? p!.fullName
            : (me.name ?? '');
        final text = Theme.of(context).textTheme;
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              FadeSlideIn(
                child: Panel(
                  child: Row(
                    children: [
                      Initials(name, photoUrl: p?.photoUrl, size: 64),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Your profile' : name,
                              style: text.titleLarge,
                            ),
                            Text(
                              me.mobile,
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                            if (p?.memberId != null)
                              Text(
                                'ID ${p!.memberId}',
                                style: text.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (p?.orgUnitLabel != null)
                              Text(p!.orgUnitLabel!, style: text.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 1,
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ABVP membership',
                              style: text.titleMedium,
                            ),
                          ),
                          app == null
                              ? const StatusPill('Not applied')
                              : StatusPill.forStatus(p?.status ?? app.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        app == null
                            ? 'Members get a member ID and pass, member events and Vibhag spaces. Your district office reviews your application.'
                            : app.status == 'submitted'
                            ? 'With ${app.reviewingOffice ?? 'your district office'} for review.'
                            : (app.decisionNote ?? ''),
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      if (app == null ||
                          app.status == 'more_info_required') ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => session.editApplication(true),
                          child: Text(
                            app == null
                                ? 'Apply for membership'
                                : 'Fix and send again',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 2,
                child: Panel(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Edit details, area and photo'),
                        subtitle: const Text(
                          'Name, date of birth, district, Vibhags',
                        ),
                        onTap: () => session.editApplication(true),
                      ),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: Text(
                          me.hasPassword
                              ? tr('me.passwordChange')
                              : tr('me.passwordSet'),
                        ),
                        subtitle: Text(tr('me.passwordHint')),
                        onTap: () => showPasswordSheet(context, session),
                      ),
                      ListTile(
                        leading: const Icon(Icons.translate),
                        title: Text(tr('lang.title')),
                        onTap: () => showLanguagePicker(
                          context,
                          save: (c) => session.api.writeCache('lang', c),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout, color: AppColors.bad),
                        title: const Text(
                          'Sign out',
                          style: TextStyle(color: AppColors.bad),
                        ),
                        onTap: session.signOut,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
