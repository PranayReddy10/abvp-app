import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/loader.dart';
import 'schedule_call_screen.dart';

/// Find office bearers and members. Phone numbers never appear here.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, required this.session});
  final Session session;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _q = TextEditingController();
  bool _bearers = true;
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Directory')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => setState(() => _key = UniqueKey()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Name, college or Member ID'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            FilterChip(label: const Text('Office bearers'), selected: _bearers, selectedColor: AppColors.saffronSoft,
                onSelected: (v) => setState(() {
                      _bearers = v;
                      _key = UniqueKey();
                    })),
          ]),
        ),
        Expanded(
          child: Loader<List<dynamic>>(
            key: _key,
            load: () async => await widget.session.api.get('/directory?q=${Uri.encodeQueryComponent(_q.text)}&office_bearers=${_bearers ? 1 : 0}') as List,
            builder: (context, rows, _) => rows.isEmpty
                ? ListView(children: const [EmptyNote('No one matches. Try another name or turn off "Office bearers".')])
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      final r = rows[i] as Map<String, dynamic>;
                      final roles = (r['roles'] as List).cast<String>();
                      return ListTile(
                        leading: Initials(r['full_name'] as String, photoUrl: r['photo_url'] as String?),
                        title: Text(r['full_name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([if (roles.isNotEmpty) roles.join(', '), r['place']].whereType<String>().join(' · ')),
                        trailing: IconButton.filledTonal(
                          tooltip: 'Schedule a call',
                          icon: const Icon(Icons.videocam_outlined),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduleCallScreen(session: widget.session, memberId: r['member_id'] as String, name: r['full_name'] as String))),
                        ),
                        onTap: () => _profile(context, r['member_id'] as String),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }

  Future<void> _profile(BuildContext context, String memberId) async {
    Map<String, dynamic> p;
    try {
      p = await widget.session.api.get('/members/$memberId') as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!context.mounted) return;
    final resp = (p['responsibilities'] as List).cast<Map<String, dynamic>>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Initials(p['full_name'] as String, size: 56, photoUrl: p['photo_url'] as String?),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['full_name'] as String, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(p['org_unit'] as String? ?? '', style: Theme.of(ctx).textTheme.bodySmall),
              ])),
            ]),
            const SizedBox(height: 12),
            if (p['bio'] != null) Text(p['bio'] as String),
            if (resp.isNotEmpty) Fact('Dayitva', resp.map((r) => '${r['title']}${r['org_unit'] != null ? ', ${r['org_unit']['name']}' : ''}').join('\n')),
            Fact('Vibhags', (p['vibhags'] as List).join(', ')),
            if (p['institution'] != null) Fact('College', p['institution'] as String),
            if (p['mobile'] != null) Fact('Mobile', p['mobile'] as String),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Schedule a call'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduleCallScreen(session: widget.session, memberId: memberId, name: p['full_name'] as String)));
              },
            ),
            if (p['mobile'] == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Phone number hidden by their privacy settings.', style: Theme.of(ctx).textTheme.bodySmall),
              ),
          ]),
        ),
      ),
    );
  }
}
