import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'scanner_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.session});
  final Session session;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _fields = {
    'mobile': 'Mobile number',
    'email': 'Email',
    'institution': 'College and course',
    'date_of_birth': 'Date of birth',
  };
  static const _levels = {
    'nobody': 'Only me',
    'office_bearers': 'Office bearers',
    'my_unit': 'My unit',
    'members': 'All members',
  };

  String? _message;

  Future<void> _setPrivacy(String field, String level) async {
    try {
      await widget.session.api.put('/me/privacy', {field: level});
      await widget.session.refresh();
      setState(() => _message = null);
    } on ApiException catch (e) {
      setState(() => _message = e.message);
    }
  }

  Future<void> _editAbout() async {
    final p = widget.session.me!.profile!;
    final bio = TextEditingController(text: p.bio ?? '');
    final skills = TextEditingController(text: p.skills.join(', '));
    final langs = TextEditingController(text: p.languages.join(', '));

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('About you', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: bio,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Short bio'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: skills,
              decoration: const InputDecoration(
                labelText: 'Skills',
                hintText: 'Public speaking, Poster design',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: langs,
              decoration: const InputDecoration(
                labelText: 'Languages',
                hintText: 'Telugu, Hindi, English',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    List<String> split(String s) =>
        s.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    try {
      await widget.session.api.patch('/me/profile', {
        'bio': bio.text.trim(),
        'skills': split(skills.text),
        'languages': split(langs.text),
      });
      await widget.session.refresh();
    } on ApiException catch (e) {
      setState(() => _message = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.session.me!;
    final p = me.profile!;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              Initials(p.fullName, size: 64, photoUrl: p.photoUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.fullName,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      p.memberId ?? '',
                      style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 6),
                    StatusPill.forStatus(p.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_message != null) ...[
            ErrorBanner(_message!),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Fact('Mobile', me.mobile),
                  Fact('Area', p.orgUnitLabel ?? ''),
                  Fact(
                    'College',
                    [p.institution, p.course, p.studyYear]
                        .whereType<String>()
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                  ),
                  Fact('Vibhags', p.vibhags.map((v) => v.name).join(', ')),
                  Fact('Bio', p.bio ?? ''),
                  Fact('Skills', p.skills.join(', ')),
                  Fact('Languages', p.languages.join(', ')),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: _editAbout,
                    child: const Text('Edit bio, skills and languages'),
                  ),
                ],
              ),
            ),
          ),
          if (me.canCheckIn) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.saffron,
                ),
                title: const Text(
                  'Gate check-in',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Scan passes for events you are on the team for',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CheckInEventsScreen(session: widget.session),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Who can see my details', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Your name, photo, area and Vibhags are visible to members. Choose who sees the rest.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: _fields.entries
                  .map(
                    (f) => ListTile(
                      title: Text(f.value),
                      trailing: DropdownButton<String>(
                        value: p.privacy[f.key] ?? 'nobody',
                        underline: const SizedBox.shrink(),
                        items: _levels.entries
                            .map(
                              (l) => DropdownMenuItem(
                                value: l.key,
                                child: Text(l.value),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            v == null ? null : _setPrivacy(f.key, v),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: widget.session.signOut,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.bad),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
