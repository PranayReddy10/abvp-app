import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/kit.dart';

/// Event passes first (today's on top), then the member pass. Everything is saved
/// on the phone so the gate works without signal.
class PassScreen extends StatefulWidget {
  const PassScreen({super.key, required this.session});
  final Session session;

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic>? _member;
  bool _offline = false;
  String? _error;
  bool _loaded = false;

  ApiClient get api => widget.session.api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = (await api.get('/me/passes') as List)
          .cast<Map<String, dynamic>>();
      Map<String, dynamic>? member;
      if (widget.session.me?.isMember == true) {
        member = await api.get('/me/qr') as Map<String, dynamic>;
      }
      await api.writeCache(
        'passes',
        jsonEncode({'events': events, 'member': member}),
      );
      _apply(events, member, offline: false);
    } on ApiException catch (e) {
      final cached = await api.readCache('passes');
      if (cached != null) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        var member = data['member'] as Map<String, dynamic>?;
        // Member codes rotate daily; an old one would be refused at the gate.
        if (member != null &&
            DateTime.parse(member['valid_until'] as String)
                .isBefore(DateTime.now())) {
          member = null;
        }
        return _apply(
          (data['events'] as List).cast<Map<String, dynamic>>(),
          member,
          offline: true,
        );
      }
      if (mounted) {
        setState(() {
          _error = e.message;
          _loaded = true;
        });
      }
    }
  }

  void _apply(
    List<Map<String, dynamic>> events,
    Map<String, dynamic>? member, {
    required bool offline,
  }) {
    if (!mounted) return;
    setState(() {
      _events = events;
      _member = member;
      _offline = offline;
      _error = null;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.session.me?.profile;
    final now = DateTime.now();
    bool isToday(Map<String, dynamic> e) {
      final s = DateTime.parse(e['event']['starts_at'] as String).toLocal();
      final end = DateTime.parse(e['event']['ends_at'] as String).toLocal();
      return now.isAfter(DateTime(s.year, s.month, s.day)) && now.isBefore(end);
    }

    final today = _events
        .where((e) => isToday(e) && e['token'] != null)
        .toList();
    final later = _events.where((e) => !today.contains(e)).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'My pass',
                    style: TextStyle(
                      fontFamily: 'Anek',
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (_loaded && _error == null)
                  StatusPill(
                    _offline ? 'Saved on phone' : 'Up to date',
                    color: AppColors.ok,
                    background: AppColors.okSoft,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_loaded)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_error != null) ErrorBanner(_error!),
            ...today.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: EventPassCard(pass: e, highlight: true),
              ),
            ),
            if (_member != null && p != null) ...[
              if (today.isNotEmpty)
                Text(
                  'Member pass',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              if (today.isNotEmpty) const SizedBox(height: 8),
              _QrCard(
                token: _member!['token'] as String,
                line1: p.memberId ?? '',
                line2: p.fullName,
                caption: 'Member · changes every day',
              ),
            ],
            if (later.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Coming up', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...later.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EventPassCard(pass: e),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Show the code at the entry desk. Turn your screen brightness up.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class EventPassCard extends StatelessWidget {
  const EventPassCard({super.key, required this.pass, this.highlight = false});
  final Map<String, dynamic> pass;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final event = pass['event'] as Map<String, dynamic>;
    final status = pass['status'] as String;
    final arrived = pass['checked_in_at'] != null;
    final guest = pass['kind'] == 'guest';

    if (pass['token'] == null) {
      return Card(
        child: ListTile(
          title: Text(
            event['title'] as String,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${dayTime(event['starts_at'] as String)}\n${status == 'waitlisted' ? 'On the waitlist – no pass yet' : 'Waiting for approval – no pass yet'}',
          ),
          isThreeLine: true,
        ),
      );
    }

    final start = DateTime.parse(event['starts_at'] as String).toLocal();
    const topHeight = 168.0;
    const label = TextStyle(
      color: AppColors.muted,
      fontSize: 11.5,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
    );
    const value = TextStyle(
      color: AppColors.ink,
      fontSize: 15.5,
      fontWeight: FontWeight.w800,
    );
    Widget info(
      String l,
      String v, {
      CrossAxisAlignment a = CrossAxisAlignment.start,
    }) => Column(
      crossAxisAlignment: a,
      children: [
        Text(l, style: label),
        const SizedBox(height: 2),
        Text(v, style: value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (highlight ? AppColors.saffron : AppColors.ink).withValues(
              alpha: 0.14,
            ),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: -10,
          ),
        ],
      ),
      child: ClipPath(
        clipper: TicketClipper(topHeight),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: topHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  highlight ? 'TODAY' : 'EVENT PASS',
                                  style: const TextStyle(
                                    color: AppColors.saffronInk,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  event['title'] as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Anek',
                                    color: AppColors.ink,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusPill(
                            guest ? 'Guest' : 'Member',
                            color: guest
                                ? const Color(0xFF2E55C9)
                                : AppColors.saffronInk,
                            background: guest
                                ? const Color(0xFFE6ECFB)
                                : AppColors.saffronSoft,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: info(
                              'Date',
                              '${start.day} ${monthShort(start)}',
                            ),
                          ),
                          Expanded(
                            child: info(
                              'Time',
                              TimeOfDay.fromDateTime(start).format(context),
                              a: CrossAxisAlignment.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: info(
                              'Venue',
                              (event['venue'] as String).split(',').first,
                              a: CrossAxisAlignment.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: DashedLine(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  children: [
                    QrImageView(
                      data: pass['token'] as String,
                      size: highlight ? 220 : 160,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.ink,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.ink,
                      ),
                    ),
                    if (arrived) ...[
                      const SizedBox(height: 10),
                      StatusPill(
                        'Checked in ${dayTime(pass['checked_in_at'] as String)}',
                        color: AppColors.ok,
                        background: AppColors.okSoft,
                      ),
                    ],
                    if (highlight && event['instructions'] != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        event['instructions'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                color: highlight ? AppColors.saffron : AppColors.ink,
                child: Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        pass['name'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      status == 'registered'
                          ? 'CONFIRMED'
                          : status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.token,
    required this.line1,
    required this.line2,
    required this.caption,
  });
  final String token, line1, line2, caption;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      children: [
        QrImageView(
          data: token,
          size: 200,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: AppColors.ink,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          line1,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        Text(line2, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          caption,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}
