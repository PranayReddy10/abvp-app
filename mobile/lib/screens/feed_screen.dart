import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/kit.dart';
import '../widgets/loader.dart';
import '../widgets/motion.dart';
import 'schedule_call_screen.dart';

typedef Post = Map<String, dynamic>;

/// Community feed: short posts with photos from members, like a town square for the Parishad.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.session, this.tag});
  final Session session;
  final String? tag;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _tab = 'for_you';
  final List<Post> _posts = [];
  List<Map<String, dynamic>> _trending = [];
  int? _nextBefore;
  bool _loading = true;
  bool _more = false;
  String? _error;

  ApiClient get api => widget.session.api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _query({int? before}) => [
    'tab=$_tab',
    if (widget.tag != null) 'tag=${Uri.encodeQueryComponent(widget.tag!)}',
    if (before != null) 'before=$before',
  ].join('&');

  Future<void> _load() async {
    setState(() {
      _loading = _posts.isEmpty;
      _error = null;
    });
    try {
      final res = await api.getWithMeta('/feed?${_query()}');
      final trending = widget.tag == null
          ? await api.get('/feed/trending') as List
          : const [];
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll((res['data'] as List).cast<Post>());
        _nextBefore = res['meta']?['next_before'] as int?;
        _trending = trending.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_more || _nextBefore == null) return;
    setState(() => _more = true);
    try {
      final res = await api.getWithMeta('/feed?${_query(before: _nextBefore)}');
      setState(() {
        _posts.addAll((res['data'] as List).cast<Post>());
        _nextBefore = res['meta']?['next_before'] as int?;
      });
    } on ApiException catch (_) {
      // Keep what is on screen; the next scroll tries again.
    } finally {
      if (mounted) setState(() => _more = false);
    }
  }

  Future<void> _compose() async {
    final created = await Navigator.push<Post>(
      context,
      MaterialPageRoute(
        builder: (_) => ComposeScreen(
          session: widget.session,
          initialText: widget.tag != null ? '#${widget.tag} ' : null,
        ),
      ),
    );
    if (created != null) setState(() => _posts.insert(0, created));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.session.me!.profile!;
    final isTagPage = widget.tag != null;

    final header = <Widget>[
      Row(
        children: [
          if (isTagPage) ...[
            CircleIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTagPage ? 'Hashtag' : 'Community',
                  style: const TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                Text(
                  isTagPage ? '#${widget.tag}' : 'What’s happening',
                  style: const TextStyle(
                    fontFamily: 'Anek',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'New post',
            accent: true,
            onTap: _compose,
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (!isTagPage) ...[
        Panel(
          onTap: _compose,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Initials(p.fullName, photoUrl: p.photoUrl, size: 44),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Share work from your unit…',
                  style: TextStyle(color: AppColors.muted, fontSize: 15.5),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.ground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_outlined,
                  color: AppColors.ink,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              PillChip(
                label: 'For you',
                icon: Icons.auto_awesome_outlined,
                selected: _tab == 'for_you',
                onTap: () {
                  setState(() => _tab = 'for_you');
                  _posts.clear();
                  _load();
                },
              ),
              const SizedBox(width: 8),
              PillChip(
                label: 'Following',
                icon: Icons.people_alt_outlined,
                selected: _tab == 'following',
                onTap: () {
                  setState(() => _tab = 'following');
                  _posts.clear();
                  _load();
                },
              ),
              for (final t in _trending.take(6)) ...[
                const SizedBox(width: 8),
                PillChip(
                  label: '#${t['tag']}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FeedScreen(
                        session: widget.session,
                        tag: t['tag'] as String,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    ];

    Widget body;
    if (_loading) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [...header, const SkeletonList(rows: 3)],
      );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) _loadMore();
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: header.length + (_posts.isEmpty ? 1 : _posts.length) + 1,
          itemBuilder: (context, i) {
            if (i < header.length) return header[i];
            final j = i - header.length;
            if (_posts.isEmpty && j == 0) {
              return _error != null
                  ? ErrorBanner(_error!)
                  : EmptyNote(
                      _tab == 'following'
                          ? 'Follow members from their profile to see their posts here.'
                          : 'No posts yet. Share what your unit did today – a photo and a few lines is enough.',
                    );
            }
            if (j >= _posts.length) {
              return _more
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FadeSlideIn(
                index: j < 6 ? j : 0,
                child: PostCard(
                  key: ValueKey(_posts[j]['id']),
                  session: widget.session,
                  post: _posts[j],
                  onRemoved: () => setState(() => _posts.removeAt(j)),
                  onReposted: (p) => setState(() => _posts.insert(0, p)),
                ),
              ),
            );
          },
        ),
      );
    }

    final content = RefreshIndicator(onRefresh: _load, child: body);
    return isTagPage
        ? Scaffold(body: SafeArea(child: content))
        : SafeArea(child: content);
  }
}

/// One post, with its repost or quote, photos and actions.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.session,
    required this.post,
    this.onRemoved,
    this.onReposted,
    this.open = true,
  });
  final Session session;
  final Post post;
  final VoidCallback? onRemoved;
  final ValueChanged<Post>? onReposted;
  final bool open;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late Post p = widget.post;

  ApiClient get api => widget.session.api;

  /// A plain repost shows the original with a "reposted" line; a quote shows both.
  bool get _plainRepost =>
      p['repost_of'] != null &&
      (p['body'] == null || (p['body'] as String).isEmpty) &&
      (p['photo_urls'] as List).isEmpty;
  Post get _main => _plainRepost ? p['repost_of'] as Post : p;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _like() async {
    final m = _main;
    final was = m['liked'] == true;
    setState(() {
      m['liked'] = !was;
      m['likes'] = (m['likes'] as int) + (was ? -1 : 1);
    });
    try {
      final r =
          await api.post('/posts/${m['id']}/like') as Map<String, dynamic>;
      setState(() {
        m['liked'] = r['liked'];
        m['likes'] = r['likes_count'];
      });
    } on ApiException catch (e) {
      setState(() {
        m['liked'] = was;
        m['likes'] = (m['likes'] as int) + (was ? 1 : -1);
      });
      _snack(e.message);
    }
  }

  Future<void> _repost() async {
    final m = _main;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('Repost'),
              subtitle: const Text('Share it with your followers as it is'),
              onTap: () => Navigator.pop(ctx, 'repost'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('Quote'),
              subtitle: const Text('Add your own words on top'),
              onTap: () => Navigator.pop(ctx, 'quote'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'quote') {
      final created = await Navigator.push<Post>(
        context,
        MaterialPageRoute(
          builder: (_) => ComposeScreen(session: widget.session, quote: m),
        ),
      );
      if (created != null) {
        setState(() => m['reposts'] = (m['reposts'] as int) + 1);
        widget.onReposted?.call(created);
      }
      return;
    }
    try {
      final created = await api.post('/posts', {
        'repost_of_id': m['id'],
        'audience': 'members',
      }) as Post;
      setState(() {
        m['reposted'] = true;
        m['reposts'] = (m['reposts'] as int) + 1;
      });
      widget.onReposted?.call(created);
      _snack('Reposted');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _menu() async {
    final mine = p['is_mine'] == true;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                'View ${(_main['author']['name'] as String).split(' ').first}’s profile',
              ),
              onTap: () => Navigator.pop(ctx, 'profile'),
            ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.bad),
                title: const Text(
                  'Delete post',
                  style: TextStyle(color: AppColors.bad),
                ),
                onTap: () => Navigator.pop(ctx, 'delete'),
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report post'),
                subtitle: const Text('Your name is not shown to the author'),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'profile') {
      openMember(
        context,
        widget.session,
        _main['author']['member_id'] as String,
      );
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete this post?'),
          content: const Text(
            'Replies and likes go with it. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await api.delete('/posts/${p['id']}');
        widget.onRemoved?.call();
        _snack('Post deleted');
      } on ApiException catch (e) {
        _snack(e.message);
      }
    } else if (action == 'report') {
      if (!mounted) return;
      await reportPost(context, widget.session, _main['id'] as int);
    }
  }

  void _open() async {
    if (!widget.open) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PostScreen(session: widget.session, id: _main['id'] as int),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = _main;
    final quote = !_plainRepost && p['repost_of'] != null
        ? p['repost_of'] as Post
        : null;

    return Panel(
      onTap: widget.open ? _open : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_plainRepost)
            Padding(
              padding: const EdgeInsets.only(left: 30, bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.repeat, size: 15, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    '${p['is_mine'] == true ? 'You' : p['author']['name']} reposted',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => openMember(
                  context,
                  widget.session,
                  m['author']['member_id'] as String,
                ),
                child: Initials(
                  m['author']['name'] as String,
                  photoUrl: m['author']['photo_url'] as String?,
                  size: 44,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NameWithBadge(
                      m['author']['name'] as String,
                      verified: m['author']['verified'] == true,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: AppColors.ink,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            [
                              m['author']['place'],
                              ago(m['at'] as String),
                            ].whereType<String>().join(' · '),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (m['audience'] != 'members') ...[
                          const SizedBox(width: 6),
                          Icon(
                            m['audience'] == 'area'
                                ? Icons.place_outlined
                                : Icons.grid_view_rounded,
                            size: 13,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              m['audience_label'] as String,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz, color: AppColors.muted),
                onPressed: _menu,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((m['body'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  PostText(m['body'] as String, session: widget.session),
                ],
                if ((m['photo_urls'] as List).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  PhotoGrid((m['photo_urls'] as List).cast<String>()),
                ],
                if (quote != null) ...[
                  const SizedBox(height: 10),
                  _Quoted(post: quote, session: widget.session),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _Act(
                icon: Icons.chat_bubble_outline,
                count: m['comments'] as int,
                tooltip: 'Reply',
                onTap: _open,
              ),
              _Act(
                icon: Icons.repeat,
                count: m['reposts'] as int,
                active: m['reposted'] == true,
                color: AppColors.ok,
                tooltip: 'Repost',
                onTap: _repost,
              ),
              _Act(
                icon: m['liked'] == true
                    ? Icons.favorite
                    : Icons.favorite_border,
                count: m['likes'] as int,
                active: m['liked'] == true,
                color: AppColors.bad,
                tooltip: m['liked'] == true ? 'Unlike' : 'Like',
                onTap: _like,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.color = AppColors.ink,
  });
  final IconData icon;
  final int count;
  final bool active;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = active ? color : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: Tween(begin: 0.6, end: 1.0).animate(
                      CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                    ),
                    child: child,
                  ),
                  child: Icon(
                    icon,
                    key: ValueKey('$icon$active'),
                    size: 20,
                    color: c,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  count == 0 ? '' : '$count',
                  style: TextStyle(
                    color: c,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Quoted extends StatelessWidget {
  const _Quoted({required this.post, required this.session});
  final Post post;
  final Session session;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostScreen(session: session, id: post['id'] as int),
      ),
    ),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.ground,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Initials(
                post['author']['name'] as String,
                photoUrl: post['author']['photo_url'] as String?,
                size: 24,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: NameWithBadge(
                  post['author']['name'] as String,
                  verified: post['author']['verified'] == true,
                  badgeSize: 14,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                ' · ${ago(post['at'] as String)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ],
          ),
          if ((post['body'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              post['body'] as String,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if ((post['photo_urls'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            PhotoGrid((post['photo_urls'] as List).cast<String>(), height: 140),
          ],
        ],
      ),
    ),
  );
}

/// Body text with #hashtags in saffron; tapping one opens that tag.
class PostText extends StatefulWidget {
  const PostText(
    this.text, {
    super.key,
    required this.session,
    this.size = 15.5,
  });
  final String text;
  final Session session;
  final double size;

  @override
  State<PostText> createState() => _PostTextState();
}

class _PostTextState extends State<PostText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    final re = RegExp(r'#[\p{L}\p{M}\p{N}_]{2,40}', unicode: true);
    var last = 0;
    for (final m in re.allMatches(widget.text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      }
      final tag = m.group(0)!.substring(1).toLowerCase();
      final r = TapGestureRecognizer()
        ..onTap = () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FeedScreen(session: widget.session, tag: tag),
          ),
        );
      _recognizers.add(r);
      spans.add(
        TextSpan(
          text: m.group(0),
          style: const TextStyle(
            color: AppColors.saffronInk,
            fontWeight: FontWeight.w600,
          ),
          recognizer: r,
        ),
      );
      last = m.end;
    }
    if (last < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(last)));
    }
    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(
        fontSize: widget.size,
        height: 1.45,
        color: AppColors.ink,
      ),
    );
  }
}

/// One to four photos in rounded tiles; tap for full screen.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid(this.urls, {super.key, this.height = 220});
  final List<String> urls;
  final double height;

  Widget _tile(BuildContext context, int i) => SizedBox.expand(
    child: GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, _, _) => _PhotoViewer(urls: urls, index: i),
        ),
      ),
      child: Image.network(
        urls[i],
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: AppColors.line,
          child: const Icon(
            Icons.broken_image_outlined,
            color: AppColors.muted,
          ),
        ),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : Container(color: AppColors.ground),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const gap = 4.0;
    final n = urls.length;
    Widget grid;
    if (n == 1) {
      grid = SizedBox(
        height: height,
        width: double.infinity,
        child: _tile(context, 0),
      );
    } else if (n == 2) {
      grid = SizedBox(
        height: height * 0.8,
        child: Row(
          children: [
            Expanded(child: _tile(context, 0)),
            const SizedBox(width: gap),
            Expanded(child: _tile(context, 1)),
          ],
        ),
      );
    } else {
      grid = SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(child: _tile(context, 0)),
            const SizedBox(width: gap),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _tile(context, 1)),
                  const SizedBox(height: gap),
                  Expanded(
                    child: n == 3
                        ? _tile(context, 2)
                        : Row(
                            children: [
                              Expanded(child: _tile(context, 2)),
                              const SizedBox(width: gap),
                              Expanded(child: _tile(context, 3)),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(20), child: grid);
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.urls, required this.index});
  final List<String> urls;
  final int index;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black.withValues(alpha: 0.94),
    body: Stack(
      children: [
        PageView.builder(
          controller: PageController(initialPage: index),
          itemCount: urls.length,
          itemBuilder: (_, i) =>
              InteractiveViewer(child: Center(child: Image.network(urls[i]))),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: CircleIconButton(
              icon: Icons.close,
              tooltip: 'Close',
              dark: true,
              onTap: () => Navigator.pop(context),
            ),
          ),
        ),
      ],
    ),
  );
}

const reportReasons = {
  'abuse': 'Abusive or hateful',
  'false_info': 'False information',
  'spam': 'Spam or advertising',
  'private_info': 'Shares someone’s private details',
  'other': 'Something else',
};

Future<void> reportPost(BuildContext context, Session session, int id) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Why are you reporting this?',
              style: TextStyle(
                fontFamily: 'Anek',
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final e in reportReasons.entries)
            ListTile(
              title: Text(e.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(ctx, e.key),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (reason == null) return;
  try {
    await session.api.post('/posts/$id/report', {'reason': reason});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks. Your district office will review it.'),
        ),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// A post with its replies, and a reply box pinned to the bottom.
class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.session, required this.id});
  final Session session;
  final int id;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _reply = TextEditingController();
  Post? _post;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await widget.session.api.get('/posts/${widget.id}') as Post;
      if (mounted) setState(() => _post = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final c = await widget.session.api.post('/posts/${widget.id}/comments', {
        'body': text,
      }) as Map<String, dynamic>;
      _reply.clear();
      setState(() {
        (_post!['replies'] as List).add(c);
        _post!['comments'] = (_post!['comments'] as int) + 1;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteReply(Map<String, dynamic> r) async {
    try {
      await widget.session.api.delete('/comments/${r['id']}');
      setState(() {
        (_post!['replies'] as List).remove(r);
        _post!['comments'] = (_post!['comments'] as int) - 1;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _post;
    final replies =
        (p?['replies'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Post',
                    style: TextStyle(
                      fontFamily: 'Anek',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: [ErrorBanner(_error!)],
                    )
                  : p == null
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: SkeletonList(rows: 2),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [
                        PostCard(
                          session: widget.session,
                          post: p,
                          open: false,
                          onRemoved: () => Navigator.pop(context),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          replies.isEmpty ? 'No replies yet' : 'Replies',
                          style: const TextStyle(
                            fontFamily: 'Anek',
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...replies.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => openMember(
                                    context,
                                    widget.session,
                                    r['author']['member_id'] as String,
                                  ),
                                  child: Initials(
                                    r['author']['name'] as String,
                                    photoUrl:
                                        r['author']['photo_url'] as String?,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      10,
                                      14,
                                      12,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(20),
                                        bottomLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                        topLeft: Radius.circular(6),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: NameWithBadge(
                                                r['author']['name'] as String,
                                                verified:
                                                    r['author']['verified'] ==
                                                    true,
                                                badgeSize: 14,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              ' · ${ago(r['at'] as String)}',
                                              style: const TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            const Spacer(),
                                            if (r['is_mine'] == true ||
                                                p['is_mine'] == true)
                                              InkWell(
                                                onTap: () => _deleteReply(r),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(2),
                                                  child: Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: AppColors.muted,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        PostText(
                                          r['body'] as String,
                                          session: widget.session,
                                          size: 14.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (p != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 10, 10),
                color: AppColors.ground,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        maxLength: 500,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText:
                              'Reply to ${(p['author']['name'] as String).split(' ').first}…',
                          counterText: '',
                          fillColor: AppColors.surface,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleIconButton(
                      icon: _sending ? Icons.hourglass_top : Icons.send_rounded,
                      tooltip: 'Send reply',
                      accent: true,
                      onTap: _sending ? null : _send,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Write a post: text, up to four photos, and who can see it.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({
    super.key,
    required this.session,
    this.quote,
    this.initialText,
  });
  final Session session;
  final Post? quote;
  final String? initialText;

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  late final _text = TextEditingController(text: widget.initialText);
  final List<XFile> _photos = [];
  String _audience = 'members';
  int? _vibhagId;
  bool _busy = false;
  String? _error;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 82,
      maxWidth: 2000,
      limit: 4 - _photos.length,
    );
    if (picked.isEmpty) return;
    setState(() => _photos.addAll(picked.take(4 - _photos.length)));
  }

  Future<void> _post() async {
    if (_text.text.trim().isEmpty && _photos.isEmpty && widget.quote == null) {
      setState(() => _error = 'Write something or add a photo.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final fields = {
        if (_text.text.trim().isNotEmpty) 'body': _text.text.trim(),
        'audience': _audience,
        if (_audience == 'vibhag' && _vibhagId != null)
          'vibhag_id': '$_vibhagId',
        if (widget.quote != null) 'repost_of_id': '${widget.quote!['id']}',
      };
      final created = await widget.session.api.uploadPicked(
        '/posts',
        fields,
        'photos[]',
        _photos,
      ) as Post;
      if (mounted) Navigator.pop(context, created);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.session.me!.profile!;
    final vibhags = p.vibhags;
    final left = 500 - _text.text.characters.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.close,
                    tooltip: 'Cancel',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.quote != null ? 'Quote post' : 'New post',
                      style: const TextStyle(
                        fontFamily: 'Anek',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _busy || left < 0 ? null : _post,
                      child: Text(_busy ? 'Posting…' : 'Post'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  if (_error != null) ...[
                    ErrorBanner(_error!),
                    const SizedBox(height: 12),
                  ],
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Initials(
                              p.fullName,
                              photoUrl: p.photoUrl,
                              size: 44,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _text,
                                autofocus: true,
                                minLines: 4,
                                maxLines: 12,
                                onChanged: (_) => setState(() {}),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                style: const TextStyle(
                                  fontSize: 17,
                                  height: 1.45,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'What did your unit do today? Add #hashtags so others find it.',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: EdgeInsets.only(top: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_photos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 96,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _photos.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) => Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: FutureBuilder(
                                      future: _photos[i].readAsBytes(),
                                      builder: (_, s) => s.hasData
                                          ? Image.memory(
                                              s.data!,
                                              width: 96,
                                              height: 96,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 96,
                                              height: 96,
                                              color: AppColors.ground,
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _photos.removeAt(i)),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (widget.quote != null) ...[
                          const SizedBox(height: 12),
                          _Quoted(post: widget.quote!, session: widget.session),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _photos.length >= 4 ? null : _pick,
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
                              label: Text(
                                _photos.isEmpty
                                    ? 'Add photos'
                                    : '${_photos.length}/4 photos',
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$left',
                              style: TextStyle(
                                color: left < 0
                                    ? AppColors.bad
                                    : left < 40
                                    ? AppColors.warn
                                    : AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Who can see this',
                    style: TextStyle(
                      fontFamily: 'Anek',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PillChip(
                        label: 'All members',
                        icon: Icons.public,
                        selected: _audience == 'members',
                        onTap: () => setState(() => _audience = 'members'),
                      ),
                      PillChip(
                        label: 'My district',
                        icon: Icons.place_outlined,
                        selected: _audience == 'area',
                        onTap: () => setState(() => _audience = 'area'),
                      ),
                      for (final v in vibhags)
                        PillChip(
                          label: v.name,
                          icon: Icons.grid_view_rounded,
                          selected: _audience == 'vibhag' && _vibhagId == v.id,
                          onTap: () => setState(() {
                            _audience = 'vibhag';
                            _vibhagId = v.id;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Posts are for members only. Don’t share phone numbers or private details; posts reported by several members are hidden until reviewed.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openMember(BuildContext context, Session session, String memberId) =>
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MemberProfileScreen(session: session, memberId: memberId),
      ),
    );

/// A member's public profile: who they are, their posts, follow, call.
class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({
    super.key,
    required this.session,
    required this.memberId,
  });
  final Session session;
  final String memberId;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  bool? _following;
  int? _followers;
  bool _busy = false;

  Future<(Map<String, dynamic>, List<Post>)> _load() async {
    final api = widget.session.api;
    final r = await Future.wait([
      api.get('/members/${widget.memberId}'),
      api.get('/members/${widget.memberId}/posts'),
    ]);
    return (r[0] as Map<String, dynamic>, (r[1] as List).cast<Post>());
  }

  Future<void> _follow() async {
    setState(() => _busy = true);
    try {
      final r = await widget.session.api.post(
        '/members/${widget.memberId}/follow',
      ) as Map<String, dynamic>;
      setState(() {
        _following = r['following'] as bool;
        _followers = r['followers'] as int;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final self = widget.session.me?.profile?.memberId == widget.memberId;
    return Scaffold(
      body: Loader<(Map<String, dynamic>, List<Post>)>(
        load: _load,
        builder: (context, data, reload) {
          final (p, posts) = data;
          final social = Map<String, dynamic>.from(p['social'] as Map? ?? {});
          final following = _following ?? social['is_following'] == true;
          final followers = _followers ?? (social['followers'] as int? ?? 0);
          final resp = (p['responsibilities'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          final top = MediaQuery.paddingOf(context).top;

          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Cover band with the avatar overlapping it.
                SizedBox(
                  height: 190 + top,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 150 + top,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.saffron,
                              AppColors.saffronDeep,
                              AppColors.ink,
                            ],
                            stops: [0, 0.4, 1],
                          ),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(32),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        top: top + 12,
                        child: CircleIconButton(
                          icon: Icons.arrow_back,
                          tooltip: 'Back',
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.ground,
                            shape: BoxShape.circle,
                          ),
                          child: Initials(
                            p['full_name'] as String,
                            photoUrl: p['photo_url'] as String?,
                            size: 88,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NameWithBadge(
                        p['full_name'] as String,
                        verified: p['verified'] == true,
                        badgeSize: 22,
                        style: const TextStyle(
                          fontFamily: 'Anek',
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          p['member_id'],
                          p['org_unit'],
                        ].whereType<String>().join(' · '),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      if (p['works_with_you'] == true)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: StatusPill(
                            'Works with you at an event',
                            color: AppColors.info,
                            background: AppColors.infoSoft,
                          ),
                        ),
                      if (p['bio'] != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          p['bio'] as String,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _Stat('${social['posts'] ?? posts.length}', 'Posts'),
                          _Stat('$followers', 'Followers'),
                          _Stat('${social['following'] ?? 0}', 'Following'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (!self)
                        Row(
                          children: [
                            Expanded(
                              child: following
                                  ? OutlinedButton(
                                      onPressed: _busy ? null : _follow,
                                      child: const Text('Following'),
                                    )
                                  : FilledButton(
                                      onPressed: _busy ? null : _follow,
                                      child: const Text('Follow'),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            CircleIconButton(
                              icon: Icons.videocam_outlined,
                              tooltip: 'Schedule a call',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ScheduleCallScreen(
                                    session: widget.session,
                                    memberId: widget.memberId,
                                    name: p['full_name'] as String,
                                  ),
                                ),
                              ),
                            ),
                            if (p['mobile'] != null) ...[
                              const SizedBox(width: 10),
                              CircleIconButton(
                                icon: Icons.call,
                                tooltip: 'Call ${p['mobile']}',
                                dark: true,
                                onTap: () =>
                                    launchUrl(Uri.parse('tel:${p['mobile']}')),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 16),
                      Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (resp.isNotEmpty)
                              Fact(
                                'Dayitva',
                                resp
                                    .map(
                                      (r) =>
                                          '${r['title']}${r['org_unit'] != null ? ', ${r['org_unit']['name']}' : ''}',
                                    )
                                    .join('\n'),
                              ),
                            if ((p['vibhags'] as List? ?? []).isNotEmpty)
                              Fact(
                                'Vibhags',
                                (p['vibhags'] as List).join(', '),
                              ),
                            if (p['institution'] != null)
                              Fact('College', p['institution'] as String),
                            if (p['mobile'] != null)
                              Fact('Mobile', p['mobile'] as String)
                            else if (!self)
                              const Fact(
                                'Mobile',
                                'Hidden by their privacy settings',
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        posts.isEmpty ? 'No posts yet' : 'Posts',
                        style: const TextStyle(
                          fontFamily: 'Anek',
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                for (var i = 0; i < posts.length; i++)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: PostCard(
                      key: ValueKey(posts[i]['id']),
                      session: widget.session,
                      post: posts[i],
                      onRemoved: reload,
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Anek',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ],
      ),
    ),
  );
}
