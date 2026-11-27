import 'package:flutter/material.dart';

import '../l10n.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/password_sheet.dart';
import 'conference/conference.dart';
import 'edit_profile_screen.dart';
import 'events_screen.dart';
import 'feed_screen.dart';
import 'guide/guide_hub.dart';

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
      ConferenceHome(
        session: widget.session,
        onOpenCommunity: () => setState(() => _tab = 1),
      ),
      FeedScreen(session: widget.session),
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
          (Icons.person_rounded, tr('nav.me')),
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
                              t('ABVP membership'),
                              style: text.titleMedium,
                            ),
                          ),
                          app == null
                              ? StatusPill(t('Not applied'))
                              : StatusPill.forStatus(p?.status ?? app.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        app == null
                            ? t(
                                'Members get member-only events and Vibhag spaces.',
                              )
                            : app.status == 'submitted'
                            ? t('With {x} for review.', {
                                'x':
                                    app.reviewingOffice ??
                                    t('your district office'),
                              })
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
                                ? t('Apply for membership')
                                : t('Fix and send again'),
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
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(t('Edit profile')),
                          subtitle: Text(
                            t('Photo, name, gender, email, area, college'),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditProfileScreen(session: session),
                            ),
                          ),
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
                          leading: const Icon(Icons.event_outlined),
                          title: Text(tr('nav.events')),
                          subtitle: Text(
                            t('Other programmes and your registrations'),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AllEventsScreen(session: session),
                            ),
                          ),
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
                          leading: const Icon(
                            Icons.logout,
                            color: AppColors.bad,
                          ),
                          title: Text(
                            t('Sign out'),
                            style: TextStyle(color: AppColors.bad),
                          ),
                          onTap: session.signOut,
                        ),
                      ],
                    ),
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
