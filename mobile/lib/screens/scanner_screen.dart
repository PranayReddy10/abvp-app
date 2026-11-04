import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';
import '../widgets/loader.dart';

/// Gate check-in for event staff. Picks the event, then scans.
class CheckInEventsScreen extends StatelessWidget {
  const CheckInEventsScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gate check-in')),
      body: Loader<List<dynamic>>(
        load: () async => await session.api.get('/me/check-in-events') as List,
        builder: (context, rows, _) => rows.isEmpty
            ? ListView(
                children: const [
                  EmptyNote(
                    'You are not on the gate team for any event right now.',
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: rows
                    .cast<Map<String, dynamic>>()
                    .map(
                      (e) => Card(
                        child: ListTile(
                          title: Text(
                            e['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${dayTime(e['starts_at'] as String)} · ${e['venue']}',
                          ),
                          trailing: e['is_today'] == true
                              ? const StatusPill(
                                  'Today',
                                  color: AppColors.saffronInk,
                                  background: AppColors.saffronSoft,
                                )
                              : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ScannerScreen(session: session, event: e),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}

enum _Tone { ok, already, offline, bad }

class _Result {
  _Result(this.tone, this.title, this.sub, {this.photo});
  final _Tone tone;
  final String title;
  final String sub;
  final String? photo;
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.session, required this.event});
  final Session session;
  final Map<String, dynamic> event;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _gate = TextEditingController();
  final _manual = TextEditingController();
  final _search = TextEditingController();
  Map<String, Map<String, dynamic>> _roster = {};
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _found = [];
  _Result? _result;
  String? _lastCode;
  DateTime _lastAt = DateTime(2000);
  bool _sending = false;
  int _tab = 0;
  List<Map<String, dynamic>> _meals = [];
  int? _meal; // null = entry gate; otherwise the meal being served

  ApiClient get api => widget.session.api;
  int get _id => widget.event['id'] as int;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    _gate.text = await api.readCache('gate') ?? '';
    final q = await api.readCache('queue.$_id');
    final r = await api.readCache('roster.$_id');
    setState(() {
      if (q != null) {
        _queue = (jsonDecode(q) as List).cast<Map<String, dynamic>>();
      }
      if (r != null) {
        _roster = (jsonDecode(r) as Map).map(
          (k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
        );
      }
    });
    _refreshRoster();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    try {
      final rows = (await api.get('/events/$_id/meal-sessions') as List)
          .cast<Map<String, dynamic>>();
      if (mounted) setState(() => _meals = rows);
    } on ApiException {
      // No meals, or offline: entry scanning still works.
    }
  }

  Future<void> _serve(String code) async {
    try {
      final r = await api.post('/events/$_id/meal-sessions/$_meal/serve', {
        'token': code,
        'counter': _gate.text.trim(),
      }) as Map<String, dynamic>;
      setState(
        () => _result = r['already'] == true
            ? _Result(
                _Tone.bad,
                'Already served: ${r['name']}',
                '${r['meal']} at ${dayTime(r['served_at'] as String)}${r['counter'] != null ? ' · ${r['counter']}' : ''}',
              )
            : _Result(
                _Tone.ok,
                'Serve ${r['name']}',
                '${r['meal']} · ${r['kind'] == 'guest' ? 'Guest' : 'Member'}',
              ),
      );
    } on ApiException catch (e) {
      setState(
        () => _result = _Result(
          _Tone.bad,
          e.code == 'NETWORK' ? 'No signal' : 'Do not serve',
          e.code == 'NETWORK'
              ? 'Meal scans need a connection, so the same plate is not given twice. Try again in a moment.'
              : e.message,
        ),
      );
    }
  }

  /// Keep the confirmed list on the phone for when the signal drops.
  Future<void> _refreshRoster() async {
    try {
      final rows = (await api.get('/events/$_id/roster') as List)
          .cast<Map<String, dynamic>>();
      final map = {for (final r in rows) r['pass_id'] as String: r};
      await api.writeCache('roster.$_id', jsonEncode(map));
      if (mounted) setState(() => _roster = map);
    } on ApiException {
      // Offline: keep the saved roster.
    }
  }

  Future<void> _handle(String code) async {
    code = code.trim();
    if (code.isEmpty) return;
    if (code == _lastCode && DateTime.now().difference(_lastAt).inSeconds < 4) {
      return;
    }
    _lastCode = code;
    _lastAt = DateTime.now();
    await api.writeCache('gate', _gate.text.trim());
    if (_meal != null) return _serve(code);

    try {
      final r = await api.post('/events/$_id/check-in', {
        'token': code,
        'gate': _gate.text.trim(),
      }) as Map<String, dynamic>;
      _show(r);
    } on ApiException catch (e) {
      if (e.code == 'NETWORK') {
        _offline(code);
      } else {
        setState(
          () => _result = _Result(
            _Tone.bad,
            e.code == 'PASS_INVALID' ? 'Not a valid pass' : 'Do not let in yet',
            e.message,
          ),
        );
      }
    }
  }

  void _show(Map<String, dynamic> r) {
    final who =
        '${r['kind'] == 'guest' ? 'Guest' : 'Member'}${r['place'] != null ? ' · ${r['place']}' : ''}';
    setState(
      () => _result = r['already'] == true
          ? _Result(
              _Tone.already,
              'Already checked in: ${r['name']}',
              '${dayTime(r['checked_in_at'] as String)}${r['gate'] != null ? ' at ${r['gate']}' : ''} · $who',
              photo: r['photo_url'] as String?,
            )
          : _Result(
              _Tone.ok,
              'Welcome, ${r['name']}',
              who,
              photo: r['photo_url'] as String?,
            ),
    );
  }

  Future<void> _offline(String code) async {
    final parts = code.split('.');
    final person = parts.length == 3 && parts[0] == 'EP1'
        ? _roster[parts[1]]
        : null;
    if (person == null) {
      setState(
        () => _result = _Result(
          _Tone.bad,
          'Not on the saved list',
          'No signal, and this pass is not on the list saved on this phone. Send them to the coordinator.',
        ),
      );
      return;
    }
    _queue.add({
      'token': code,
      'gate': _gate.text.trim(),
      'scanned_at': DateTime.now().toUtc().toIso8601String(),
    });
    await api.writeCache('queue.$_id', jsonEncode(_queue));
    setState(
      () => _result = _Result(
        _Tone.offline,
        'Let in: ${person['name']}',
        'No signal. Saved on this phone; it will be confirmed when you send saved scans.',
      ),
    );
  }

  Future<void> _sendQueue() async {
    setState(() => _sending = true);
    try {
      final res = (await api.post('/events/$_id/check-in/batch', {
        'items': _queue,
      }) as List).cast<Map<String, dynamic>>();
      final problems = res.where((r) => r['ok'] != true).length;
      _queue = [];
      await api.writeCache('queue.$_id', '[]');
      setState(
        () => _result = _Result(
          problems == 0 ? _Tone.ok : _Tone.already,
          'Sent ${res.length} saved scans',
          problems == 0
              ? 'All confirmed.'
              : '$problems could not be confirmed. Check with the coordinator.',
        ),
      );
    } on ApiException catch (e) {
      setState(() => _result = _Result(_Tone.bad, 'Still offline', e.message));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _find() async {
    try {
      final rows = await api.get(
        '/events/$_id/check-in/search?q=${Uri.encodeQueryComponent(_search.text)}',
      ) as List;
      setState(() => _found = rows.cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      setState(() => _result = _Result(_Tone.bad, 'Search failed', e.message));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = {
      _Tone.ok: (AppColors.okSoft, AppColors.ok, Icons.check_circle),
      _Tone.already: (AppColors.warnSoft, AppColors.warn, Icons.history),
      _Tone.offline: (AppColors.warnSoft, AppColors.warn, Icons.cloud_off),
      _Tone.bad: (AppColors.badSoft, AppColors.bad, Icons.block),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.event['title'] as String,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (_meals.isNotEmpty) ...[
            DropdownButtonFormField<int?>(
              initialValue: _meal,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Scanning for',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Entry gate'),
                ),
                for (final m in _meals)
                  DropdownMenuItem<int?>(
                    value: m['id'] as int,
                    child: Text(
                      '${m['name']}${m['is_now'] == true ? ' (now)' : ''} · ${m['served']} served',
                    ),
                  ),
              ],
              onChanged: (v) => setState(() {
                _meal = v;
                _result = null;
              }),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _gate,
                  decoration: InputDecoration(
                    labelText: _meal == null ? 'Your gate' : 'Your counter',
                    hintText: _meal == null ? 'Gate 3' : 'Counter 2',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_roster.length} on list',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_queue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                onPressed: _sending ? null : _sendQueue,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _sending
                      ? 'Sending…'
                      : 'Send ${_queue.length} saved scan${_queue.length == 1 ? '' : 's'}',
                ),
              ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (c, an) => FadeTransition(
              opacity: an,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(an),
                child: c,
              ),
            ),
            child: _result == null
                ? const SizedBox.shrink()
                : KeyedSubtree(
                    key: ObjectKey(_result),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: colors[_result!.tone]!.$1,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          if (_result!.photo != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundImage: NetworkImage(_result!.photo!),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Icon(
                                colors[_result!.tone]!.$3,
                                color: colors[_result!.tone]!.$2,
                                size: 36,
                              ),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _result!.title,
                                  style: TextStyle(
                                    color: colors[_result!.tone]!.$2,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _result!.sub,
                                  style: const TextStyle(color: AppColors.ink),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.qr_code_scanner),
                label: Text('Scan'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.search),
                label: Text('Find by name'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 12),
          if (_tab == 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 1,
                child: MobileScanner(
                  onDetect: (capture) {
                    final v = capture.barcodes.firstOrNull?.rawValue;
                    if (v != null) _handle(v);
                  },
                  errorBuilder: (context, error) => Container(
                    color: AppColors.ink,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(20),
                    child: const Text(
                      'Camera is not available. Allow camera access in settings, or type the pass code below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manual,
                    decoration: const InputDecoration(
                      hintText: 'Or type the pass code',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _handle(_manual.text),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('Check'),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => _find(),
                    decoration: const InputDecoration(
                      hintText: 'Name, mobile or Member ID',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _find,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('Find'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._found.map(
              (r) => Card(
                child: ListTile(
                  title: Text(
                    r['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      r['kind'] == 'guest' ? 'Guest' : r['member_id'],
                      r['place'],
                      if (r['status'] != 'registered')
                        'Not confirmed (${r['status']})',
                    ].whereType<String>().join(' · '),
                  ),
                  trailing: r['already'] == true
                      ? const StatusPill(
                          'Arrived',
                          color: AppColors.ok,
                          background: AppColors.okSoft,
                        )
                      : r['status'] == 'registered'
                      ? FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () async {
                            try {
                              final res = await api.post(
                                '/events/$_id/registrations/${r['registration_id']}/check-in',
                                {'gate': _gate.text.trim()},
                              ) as Map<String, dynamic>;
                              _show(res);
                              await _find();
                            } on ApiException catch (e) {
                              setState(
                                () => _result = _Result(
                                  _Tone.bad,
                                  'Could not check in',
                                  e.message,
                                ),
                              );
                            }
                          },
                          child: const Text('Arrived'),
                        )
                      : null,
                ),
              ),
            ),
            if (_found.isEmpty)
              const EmptyNote(
                'Search for someone whose phone is lost or not working. People not on the list go to the coordinator.',
              ),
          ],
        ],
      ),
    );
  }
}
