import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/loader.dart';
import '../widgets/motion.dart';
import 'directory_screen.dart';

class VibhagsScreen extends StatelessWidget {
  const VibhagsScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibhags'),
        actions: [
          IconButton(
            tooltip: 'Directory',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DirectoryScreen(session: session),
              ),
            ),
          ),
        ],
      ),
      body: Loader<List<dynamic>>(
        load: () async => await session.api.get('/spaces') as List,
        builder: (context, rows, reload) {
          final all = rows.cast<Map<String, dynamic>>();
          final mine = all.where((v) => v['is_member'] == true).toList();
          final others = all.where((v) => v['is_member'] != true).toList();
          Widget tile(Map<String, dynamic> v) => Card(
            child: ListTile(
              title: Text(
                v['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${v['members_count']} members'),
              trailing: v['is_member'] == true
                  ? const Icon(Icons.chevron_right)
                  : const StatusPill(
                      'Join',
                      color: AppColors.saffronInk,
                      background: AppColors.saffronSoft,
                    ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        VibhagScreen(session: session, id: v['id'] as int),
                  ),
                );
                await reload();
              },
            ),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text(
                'My Vibhags',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              if (mine.isEmpty)
                const EmptyNote(
                  'You have not joined a Vibhag yet. Pick one below.',
                ),
              ...staggered(
                mine
                    .map<Widget>(
                      (v) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: tile(v),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Text(
                'All Vibhags',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              ...staggered(
                others
                    .map<Widget>(
                      (v) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: tile(v),
                      ),
                    )
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class VibhagScreen extends StatefulWidget {
  const VibhagScreen({super.key, required this.session, required this.id});
  final Session session;
  final int id;

  @override
  State<VibhagScreen> createState() => _VibhagScreenState();
}

class _VibhagScreenState extends State<VibhagScreen> {
  Key _key = UniqueKey();
  ApiClient get api => widget.session.api;

  Future<(Map<String, dynamic>, List, List)> _load() async {
    final info = await api.get('/spaces/${widget.id}') as Map<String, dynamic>;
    final posts = await api.get('/spaces/${widget.id}/posts') as List;
    final members = info['is_member'] == true
        ? await api.get('/spaces/${widget.id}/members') as List
        : <dynamic>[];
    return (info, posts, members);
  }

  Future<void> _post() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post an update'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(
            hintText: 'What happened, or what is coming up?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    try {
      await api.post('/spaces/${widget.id}/posts', {'body': ctrl.text.trim()});
      setState(() => _key = UniqueKey());
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vibhag')),
      body: Loader<(Map<String, dynamic>, List, List)>(
        key: _key,
        load: _load,
        builder: (context, data, reload) {
          final (v, posts, members) = data;
          final joined = v['is_member'] == true;
          final text = Theme.of(context).textTheme;
          final coords = (v['coordinators'] as List)
              .cast<Map<String, dynamic>>();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.saffronSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v['name'] as String, style: text.headlineSmall),
                    if (v['description'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(v['description'] as String),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '${v['members_count']} members',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (joined)
                          OutlinedButton(
                            onPressed: () async {
                              await api.delete('/spaces/${widget.id}/join');
                              setState(() => _key = UniqueKey());
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text('Leave'),
                          )
                        else
                          FilledButton(
                            onPressed: () async {
                              try {
                                await api.post('/spaces/${widget.id}/join');
                                setState(() => _key = UniqueKey());
                              } on ApiException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.message)),
                                  );
                                }
                              }
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text('Join this Vibhag'),
                          ),
                        const Spacer(),
                        if (v['can_post'] == true)
                          TextButton.icon(
                            onPressed: _post,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Post update'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (coords.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Coordinators', style: text.titleMedium),
                ...coords.map(
                  (c) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Initials(c['name'] as String? ?? '?'),
                    title: Text(c['name'] as String? ?? ''),
                    subtitle: Text(
                      '${c['title']}${c['place'] != null ? ', ${c['place']}' : ''}',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text('Updates', style: text.titleMedium),
              const SizedBox(height: 6),
              if (posts.isEmpty) const EmptyNote('No updates yet.'),
              ...posts.cast<Map<String, dynamic>>().map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['author']} · ${p['place']} · ${ago(p['at'] as String)}',
                            style: text.bodySmall,
                          ),
                          const SizedBox(height: 6),
                          Text(p['body'] as String),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (joined && members.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Members near you', style: text.titleMedium),
                ...members.cast<Map<String, dynamic>>().map(
                  (m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Initials(
                      m['full_name'] as String,
                      photoUrl: m['photo_url'] as String?,
                    ),
                    title: Text(m['full_name'] as String),
                    subtitle: Text(m['place'] as String? ?? ''),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
