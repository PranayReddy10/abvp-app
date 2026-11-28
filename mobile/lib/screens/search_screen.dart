import 'dart:async';

import 'package:flutter/material.dart';

import '../analytics.dart';
import '../api/api_client.dart';
import '../l10n.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'conference/conference.dart' show showPersonSheet;
import 'feed_screen.dart' show MemberProfileScreen;
import 'guide/guide_sections.dart';
import 'guide/guide_widgets.dart';

typedef Json = Map<String, dynamic>;

/// One search for the app: guide places (after the delegate form), volunteers, members,
/// events and community posts – the same results as the website.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.session});
  final Session session;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TrackScreen {
  @override
  String get screenName => 'Search';

  final _q = TextEditingController();
  Timer? _debounce;
  Json? _data;
  bool _busy = false;
  String? _error;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _run(v));
  }

  Future<void> _run(String v) async {
    final q = v.trim();
    if (q.length < 2) {
      setState(() {
        _data = null;
        _error = null;
      });
      return;
    }
    final mine = ++_seq;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await widget.session.api.get(
        '/search?q=${Uri.encodeQueryComponent(q)}',
      ) as Json;
      if (!mounted || mine != _seq) return;
      setState(() => _data = d);
      Analytics.search(q);
    } on ApiException catch (e) {
      if (mounted && mine == _seq) setState(() => _error = e.message);
    } finally {
      if (mounted && mine == _seq) setState(() => _busy = false);
    }
  }

  List<Json> _list(String k) => ((_data?[k] as List?) ?? []).cast<Json>();

  @override
  Widget build(BuildContext context) {
    final guide = _list('guide'),
        people = _list('people'),
        members = _list('members');
    final events = _list('events'), posts = _list('posts');
    final total =
        guide.length +
        people.length +
        members.length +
        events.length +
        posts.length;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _q,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _changed,
          onSubmitted: _run,
          decoration: InputDecoration(
            hintText: t('Search places, people, posts…'),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_q.text.isNotEmpty)
            IconButton(
              tooltip: t('Clear'),
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _q.clear();
                _run('');
              },
            ),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          if (_error != null) ErrorBanner(_error!),
          if (_data == null && _error == null)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 56,
                    color: AppColors.saffron,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t(
                      'Find guide places, volunteers, members, events and posts.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          if (_data != null && total == 0)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                t(
                  'Nothing found. Try another word – a name, place or department.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          if (guide.isNotEmpty) ...[
            _Head(t('Conference guide')),
            for (final g in guide)
              _Row(
                icon: kindOf(g['kind'] as String).icon,
                gradient: kindOf(g['kind'] as String).gradient,
                title: g['title'] as String,
                sub: [
                  t(g['kind_label'] as String),
                  g['region'],
                  g['subtitle'],
                ].whereType<String>().where((x) => x.isNotEmpty).join(' · '),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GuideSectionScreen(
                      session: widget.session,
                      event: {'id': g['event_id']},
                      kind: g['kind'] as String,
                      title: t(g['kind_label'] as String),
                      hindi: '',
                    ),
                  ),
                ),
              ),
          ],
          if (people.isNotEmpty) ...[
            _Head(t('Volunteers')),
            for (final p in people)
              _Row(
                icon: Icons.volunteer_activism_rounded,
                title: p['name'] as String,
                verified: p['verified'] == true,
                sub: [
                  p['role'],
                  p['team'],
                  p['ghat'],
                ].whereType<String>().where((x) => x.isNotEmpty).join(' · '),
                onTap: () => showPersonSheet(
                  context,
                  {
                    ...p,
                    'role_label': p['role'],
                    'has_mobile': p['mobile'] != null,
                  },
                  team: p['team'] as String?,
                  session: widget.session,
                ),
              ),
          ],
          if (members.isNotEmpty) ...[
            _Head(t('Members')),
            for (final m in members)
              _Row(
                icon: Icons.person_rounded,
                title: m['name'] as String,
                verified: m['verified'] == true,
                sub: [
                  m['member_id'],
                  m['place'],
                ].whereType<String>().join(' · '),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemberProfileScreen(
                      session: widget.session,
                      memberId: m['member_id'] as String,
                    ),
                  ),
                ),
              ),
          ],
          if (events.isNotEmpty) ...[
            _Head(t('Events')),
            for (final e in events)
              _Row(
                icon: Icons.event_rounded,
                title: e['title'] as String,
                sub: e['venue'] as String? ?? '',
              ),
          ],
          if (posts.isNotEmpty) ...[
            _Head(t('Community posts')),
            for (final p in posts)
              _Row(
                icon: Icons.forum_rounded,
                title: p['author'] as String? ?? '',
                verified: p['verified'] == true,
                sub: p['body'] as String? ?? '',
                lines: 3,
              ),
          ],
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.sub,
    this.gradient,
    this.verified = false,
    this.onTap,
    this.lines = 1,
  });
  final IconData icon;
  final String title;
  final String sub;
  final Gradient? gradient;
  final bool verified;
  final VoidCallback? onTap;
  final int lines;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient:
                      gradient ??
                      const LinearGradient(
                        colors: [AppColors.saffron, AppColors.saffronDeep],
                      ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF1D9BF0),
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: lines,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    ),
  );
}
