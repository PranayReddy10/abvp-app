import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../l10n.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/format.dart';
import '../../widgets/kit.dart';
import '../../widgets/loader.dart';
import '../../widgets/motion.dart';
import 'guide_widgets.dart';

/// Support for one event: start a chat, raise a ticket, or open an earlier conversation.
class SupportScreen extends StatefulWidget {
  const SupportScreen({
    super.key,
    required this.session,
    required this.eventId,
    required this.eventTitle,
  });
  final Session session;
  final int eventId;
  final String eventTitle;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  Key _key = UniqueKey();

  Future<void> _go(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final k = kindOf('support');
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Loader<List<dynamic>>(
        key: _key,
        load: () async => (await widget.session.api.get('/me/help') as List)
            .where((h) => (h as Json)['event']['id'] == widget.eventId)
            .toList(),
        builder: (context, rows, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 170 + top,
                decoration: BoxDecoration(
                  gradient: k.gradient,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(34),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    const Positioned.fill(child: FloatingOrbs()),
                    Positioned(
                      left: 16,
                      top: top + 10,
                      child: CircleIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back',
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    Positioned(
                      right: 20,
                      bottom: 22,
                      child: Hero(
                        tag: 'guide-support',
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(k.icon, color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 22,
                      right: 110,
                      bottom: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.eventTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            tr('kind.support'),
                            style: const TextStyle(
                              fontFamily: 'Anek',
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: staggered([
                    _Action(
                      icon: Icons.chat_bubble_rounded,
                      title: tr('support.chat'),
                      subtitle: tr('support.chatSub'),
                      gradient: k.gradient,
                      onTap: () => _go(
                        ChatScreen(
                          session: widget.session,
                          eventId: widget.eventId,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Action(
                      icon: Icons.confirmation_number_rounded,
                      title: tr('support.ticket'),
                      subtitle: tr('support.ticketSub'),
                      onTap: () => _go(
                        TicketScreen(
                          session: widget.session,
                          eventId: widget.eventId,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SectionTitle(tr('support.mine')),
                    const SizedBox(height: 8),
                    if (rows.isEmpty) EmptyNote(tr('support.none')),
                    for (final h in rows.cast<Json>())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ConversationTile(
                          help: h,
                          onTap: () => _go(
                            ChatScreen(
                              session: widget.session,
                              eventId: widget.eventId,
                              helpId: h['id'] as int,
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.gradient,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final dark = gradient != null;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: gradient,
          color: dark ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: dark ? Colors.white24 : AppColors.saffronSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color: dark ? Colors.white : AppColors.saffronInk,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: dark ? Colors.white : AppColors.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: dark ? Colors.white70 : AppColors.muted,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: dark ? Colors.white : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String s) => tr('support.status.$s');

Color _statusColor(String s) => switch (s) {
  'resolved' || 'closed' => AppColors.ok,
  'in_progress' => AppColors.info,
  _ => AppColors.warn,
};

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.help, required this.onTap});
  final Json help;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final replies = (help['replies'] as List).cast<Json>();
    final last = replies.isEmpty
        ? help['message'] as String
        : replies.last['body'] as String;
    final fromTeam = replies.isNotEmpty && replies.last['from_team'] == true;
    final status = help['status'] as String;
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.ground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              help['category'] == 'chat'
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.confirmation_number_outlined,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('cat.${help['category']}'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      ago(help['at'] as String),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${fromTeam ? '${tr('support.desk')}: ' : ''}$last',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fromTeam ? AppColors.ink : AppColors.muted,
                    fontWeight: fromTeam ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6),
                StatusPill(
                  _statusLabel(status),
                  color: _statusColor(status),
                  background: _statusColor(status).withValues(alpha: 0.12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chat with the help desk. The first message starts the conversation; replies arrive by
/// checking every few seconds (no sockets needed on shared hosting).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.session,
    required this.eventId,
    this.helpId,
  });
  final Session session;
  final int eventId;
  final int? helpId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late int? _id = widget.helpId;
  Json? _help;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  ApiClient get api => widget.session.api;

  @override
  void initState() {
    super.initState();
    if (_id != null) _refresh();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_id == null) return;
    try {
      final h = await api.get('/help/$_id') as Json;
      if (!mounted) return;
      final grew =
          (h['replies'] as List).length !=
          ((_help?['replies'] as List?)?.length ?? -1);
      setState(() => _help = h);
      if (grew) _toBottom();
    } on ApiException catch (_) {
      // Keep what is on screen; the next check tries again.
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final Json h;
      if (_id == null) {
        h = await api.post('/events/${widget.eventId}/help', {
          'category': 'chat',
          'message': body,
        }) as Json;
        _id = h['id'] as int;
      } else {
        h = await api.post('/help/$_id/reply', {'body': body}) as Json;
      }
      _text.clear();
      setState(() => _help = h);
      _toBottom();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = _help;
    final bubbles = <(String body, bool mine, String? by, String at)>[
      if (h != null) (h['message'] as String, true, null, h['at'] as String),
      if (h != null)
        for (final r in (h['replies'] as List).cast<Json>())
          (
            r['body'] as String,
            r['mine'] == true,
            r['from_team'] == true ? r['by'] as String? : null,
            r['at'] as String,
          ),
    ];
    final k = kindOf('support');
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: CircleIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onTap: () => Navigator.pop(context),
            ),
          ),
        ),
        leadingWidth: 68,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: k.gradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('support.desk'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  if (h != null)
                    Text(
                      _statusLabel(h['status'] as String),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _statusColor(h['status'] as String),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: bubbles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopIn(
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  gradient: k.gradient,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.forum_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tr('support.chat'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Anek',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr('support.startHint'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: bubbles.length + 1,
                      itemBuilder: (_, i) {
                        if (i == bubbles.length) {
                          final waiting = bubbles.every((b) => b.$2);
                          return waiting
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Center(
                                    child: Text(
                                      tr('support.waiting'),
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }
                        final (body, mine, by, at) = bubbles[i];
                        return _Bubble(body: body, mine: mine, by: by, at: at);
                      },
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ErrorBanner(_error!),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: tr('support.typeMsg'),
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
                    icon: _sending
                        ? Icons.hourglass_top_rounded
                        : Icons.send_rounded,
                    tooltip: tr('support.send'),
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

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.body,
    required this.mine,
    required this.by,
    required this.at,
  });
  final String body;
  final bool mine;
  final String? by;
  final String at;

  @override
  Widget build(BuildContext context) {
    final t = TimeOfDay.fromDateTime(DateTime.parse(at).toLocal())
        .format(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(mine ? 20 * (1 - v) : -20 * (1 - v), 0),
          child: child,
        ),
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            gradient: mine
                ? const LinearGradient(
                    colors: [AppColors.saffron, AppColors.saffronDeep],
                  )
                : null,
            color: mine ? null : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 20 : 6),
              bottomRight: Radius.circular(mine ? 6 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (by != null)
                Text(
                  by!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: AppColors.saffronInk,
                  ),
                ),
              Text(
                body,
                style: TextStyle(
                  color: mine ? Colors.white : AppColors.ink,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  t,
                  style: TextStyle(
                    color: mine ? Colors.white70 : AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A ticket with a category and where you are; it opens as a chat afterwards.
class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, required this.session, required this.eventId});
  final Session session;
  final int eventId;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  static const _cats = [
    'medical',
    'stay',
    'food',
    'transport',
    'venue',
    'registration',
    'lost',
    'other',
  ];
  String _cat = 'stay';
  final _msg = TextEditingController();
  final _where = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_msg.text.trim().length < 5) {
      setState(() => _error = tr('support.what'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final h = await widget.session.api.post(
        '/events/${widget.eventId}/help',
        {
          'category': _cat,
          'message': _msg.text.trim(),
          if (_where.text.trim().isNotEmpty) 'location': _where.text.trim(),
        },
      ) as Json;
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            session: widget.session,
            eventId: widget.eventId,
            helpId: h['id'] as int,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('support.ticket')),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: CircleIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onTap: () => Navigator.pop(context),
            ),
          ),
        ),
        leadingWidth: 68,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _cats)
                PillChip(
                  label: tr('cat.$c'),
                  icon: c == 'medical' ? Icons.local_hospital_rounded : null,
                  selected: _cat == c,
                  onTap: () => setState(() => _cat = c),
                ),
            ],
          ),
          if (_cat == 'medical') ...[
            const SizedBox(height: 12),
            Panel(
              color: const Color(0xFFFFF1F1),
              child: Row(
                children: [
                  const Icon(Icons.emergency_rounded, color: Color(0xFFC81E1E)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('support.medical'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.call_rounded,
                    tooltip: '108',
                    accent: true,
                    onTap: () => callNumber('108'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _msg,
            minLines: 4,
            maxLines: 8,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: tr('support.what'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _where,
            maxLength: 160,
            decoration: InputDecoration(
              labelText: tr('support.where'),
              prefixIcon: const Icon(Icons.place_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: const Icon(Icons.send_rounded),
            label: Text(tr('support.submit')),
          ),
        ],
      ),
    );
  }
}
