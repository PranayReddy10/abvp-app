import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/format.dart';

/// Stay, food, pickup and location sharing for one event, on the event page.
class LogisticsCard extends StatefulWidget {
  const LogisticsCard({
    super.key,
    required this.session,
    required this.eventId,
    required this.eventTitle,
  });
  final Session session;
  final int eventId;
  final String eventTitle;

  @override
  State<LogisticsCard> createState() => _LogisticsCardState();
}

class _LogisticsCardState extends State<LogisticsCard> {
  Map<String, dynamic>? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.session.api.get(
        '/events/${widget.eventId}/my-logistics',
      ) as Map<String, dynamic>;
      if (!widget.session.location.active) {
        widget.session.location.resume(
          d['location_session'] as Map<String, dynamic>?,
        );
      }
      if (mounted) setState(() => _d = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorBanner(_error!);
    final d = _d;
    if (d == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final stay = d['stay'] as Map<String, dynamic>?;
    final vehicle = d['vehicle'] as Map<String, dynamic>?;
    final travel = d['travel'] as Map<String, dynamic>?;
    final meals = (d['meals'] as List).cast<Map<String, dynamic>>();

    Widget line(
      IconData icon,
      String title,
      String? sub, {
      Widget? trailing,
      VoidCallback? onTap,
    }) => ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      leading: Icon(icon, color: AppColors.saffron),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: sub == null ? null : Text(sub),
      trailing: trailing,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Stay, food and travel', style: text.titleMedium),
        const SizedBox(height: 6),
        Card(
          child: Column(
            children: [
              line(
                Icons.train_outlined,
                travel == null
                    ? 'Tell us how you are coming'
                    : 'Travel: ${_mode(travel['mode'] as String)}${travel['reference'] != null ? ' · ${travel['reference']}' : ''}',
                travel == null
                    ? 'So the team can arrange pickup and a room'
                    : [
                        if (travel['arriving_at'] != null)
                          'Arriving ${dayTime(travel['arriving_at'] as String)}',
                        travel['arrival_point'],
                        if (travel['needs_pickup'] == true) 'pickup requested',
                        if (travel['needs_stay'] == true) 'stay requested',
                      ].whereType<String>().join(' · '),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(
                  TravelForm(
                    session: widget.session,
                    eventId: widget.eventId,
                    existing: travel,
                  ),
                ),
              ),
              if (vehicle != null)
                line(
                  Icons.directions_bus_outlined,
                  '${vehicle['name']}${vehicle['picked_up'] == true ? ' · picked up' : ''}',
                  [
                    vehicle['pickup_point'],
                    if (vehicle['departs_at'] != null)
                      'leaves ${dayTime(vehicle['departs_at'] as String)}',
                    if (vehicle['driver_name'] != null)
                      'driver ${vehicle['driver_name']}',
                  ].whereType<String>().join(' · '),
                  trailing: vehicle['driver_phone'] == null
                      ? null
                      : IconButton.filledTonal(
                          icon: const Icon(Icons.call),
                          onPressed: () => launchUrl(
                            Uri.parse('tel:${vehicle['driver_phone']}'),
                          ),
                        ),
                )
              else if (travel?['needs_pickup'] == true)
                line(
                  Icons.directions_bus_outlined,
                  'Pickup requested',
                  'You will be told which vehicle and where to wait.',
                ),
              if (stay != null)
                line(
                  Icons.bed_outlined,
                  '${stay['place']} · room ${stay['room']}',
                  [
                    stay['address'],
                    stay['checked_in'] == true ? 'checked in' : null,
                  ].whereType<String>().join(' · '),
                  trailing: stay['map_url'] == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.map_outlined),
                          onPressed: () => launchUrl(
                            Uri.parse(stay['map_url'] as String),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                )
              else if (travel?['needs_stay'] == true)
                line(
                  Icons.bed_outlined,
                  'Stay requested',
                  'Your room will appear here once it is given.',
                ),
              for (final m in meals)
                line(
                  m['served_at'] != null
                      ? Icons.check_circle
                      : Icons.restaurant_outlined,
                  m['name'] as String,
                  '${dayTime(m['starts_at'] as String)}${m['location'] != null ? ' · ${m['location']}' : ''}${m['served_at'] != null ? ' · served' : ''}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ListenableBuilder(
          listenable: widget.session.location,
          builder: (context, _) {
            final loc = widget.session.location;
            if (loc.active) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.saffronSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.saffronInk),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sharing your location with ${loc.sharedWith == 'team_lead' ? 'your team lead' : 'event coordinators'} until ${DateFormat('h:mm a').format(loc.expiresAt!)}.'
                        '${loc.error != null ? '\n${loc.error}' : ''}',
                        style: const TextStyle(
                          color: AppColors.saffronInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(onPressed: loc.stop, child: const Text('Stop')),
                  ],
                ),
              );
            }
            return OutlinedButton.icon(
              onPressed: () => _open(
                ShareLocationScreen(
                  session: widget.session,
                  eventId: widget.eventId,
                  eventTitle: widget.eventTitle,
                ),
              ),
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Share my location for a while'),
            );
          },
        ),
      ],
    );
  }

  static String _mode(String m) =>
      const {
        'train': 'Train',
        'bus': 'Bus',
        'flight': 'Flight',
        'own': 'Own vehicle',
        'other': 'Other',
      }[m] ??
      m;
}

class TravelForm extends StatefulWidget {
  const TravelForm({
    super.key,
    required this.session,
    required this.eventId,
    this.existing,
  });
  final Session session;
  final int eventId;
  final Map<String, dynamic>? existing;

  @override
  State<TravelForm> createState() => _TravelFormState();
}

class _TravelFormState extends State<TravelForm> {
  late String _mode = widget.existing?['mode'] as String? ?? 'train';
  late final _ref = TextEditingController(
    text: widget.existing?['reference'] as String?,
  );
  late final _point = TextEditingController(
    text: widget.existing?['arrival_point'] as String?,
  );
  late final _notes = TextEditingController(
    text: widget.existing?['notes'] as String?,
  );
  late DateTime? _arriving = widget.existing?['arriving_at'] == null
      ? null
      : DateTime.parse(widget.existing!['arriving_at'] as String).toLocal();
  late bool _pickup = widget.existing?['needs_pickup'] == true;
  late bool _stay = widget.existing?['needs_stay'] == true;
  bool _busy = false;
  String? _error;

  Future<void> _pickTime() async {
    final base = _arriving ?? DateTime.now().add(const Duration(days: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 2)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (t == null) return;
    setState(
      () => _arriving = DateTime(d.year, d.month, d.day, t.hour, t.minute),
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.api.put('/events/${widget.eventId}/travel', {
        'mode': _mode,
        'reference': _ref.text.trim().isEmpty ? null : _ref.text.trim(),
        'arriving_at': _arriving?.toUtc().toIso8601String(),
        'arrival_point': _point.text.trim().isEmpty ? null : _point.text.trim(),
        'needs_pickup': _pickup,
        'needs_stay': _stay,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Travel details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in const {
                'train': 'Train',
                'bus': 'Bus',
                'flight': 'Flight',
                'own': 'Own vehicle',
                'other': 'Other',
              }.entries)
                ChoiceChip(
                  label: Text(m.value),
                  selected: _mode == m.key,
                  selectedColor: AppColors.saffronSoft,
                  onSelected: (_) => setState(() => _mode = m.key),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_mode != 'own')
            TextField(
              controller: _ref,
              decoration: InputDecoration(
                labelText: _mode == 'train'
                    ? 'Train number and name'
                    : _mode == 'flight'
                    ? 'Flight number'
                    : 'Bus or service',
                hintText: _mode == 'train' ? '12723 Telangana Express' : null,
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              _arriving == null
                  ? 'When do you arrive?'
                  : 'Arriving ${DateFormat('EEE d MMM, h:mm a').format(_arriving!)}',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _point,
            decoration: const InputDecoration(
              labelText: 'Arriving at',
              hintText: 'Warangal railway station',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pickup,
            onChanged: (v) => setState(() => _pickup = v),
            title: const Text('I need a pickup to the venue'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _stay,
            onChanged: (v) => setState(() => _stay = v),
            title: const Text('I need a place to stay'),
          ),
          TextField(
            controller: _notes,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Anything the team should know (optional)',
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
          const SizedBox(height: 8),
          Text(
            'Only the event\'s logistics team sees this.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Consent first: who sees it, for how long, and that it can be stopped any time.
class ShareLocationScreen extends StatefulWidget {
  const ShareLocationScreen({
    super.key,
    required this.session,
    required this.eventId,
    required this.eventTitle,
  });
  final Session session;
  final int eventId;
  final String eventTitle;

  @override
  State<ShareLocationScreen> createState() => _ShareLocationScreenState();
}

class _ShareLocationScreenState extends State<ShareLocationScreen> {
  int _minutes = 60;
  String _with = 'coordinators';
  final _why = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _start() async {
    if (_why.text.trim().isEmpty) {
      return setState(
        () => _error = 'Say why, so the person seeing it knows what to do.',
      );
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.session.location.start(
      eventId: widget.eventId,
      minutes: _minutes,
      sharedWith: _with,
      purpose: _why.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Share my location')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            'Use this when someone needs to find you: you are late, lost, or bringing something. Your location is never shared unless you turn this on.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 18),
          Text('Who can see it', style: text.titleMedium),
          RadioGroup<String>(
            groupValue: _with,
            onChanged: (v) => setState(() => _with = v!),
            child: const Column(
              children: [
                RadioListTile(
                  contentPadding: EdgeInsets.zero,
                  value: 'coordinators',
                  title: Text('Event coordinators'),
                ),
                RadioListTile(
                  contentPadding: EdgeInsets.zero,
                  value: 'team_lead',
                  title: Text('My team lead only'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('For how long', style: text.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 30, label: Text('30 min')),
              ButtonSegment(value: 60, label: Text('1 hour')),
              ButtonSegment(value: 120, label: Text('2 hours')),
              ButtonSegment(value: 240, label: Text('4 hours')),
            ],
            selected: {_minutes},
            onSelectionChanged: (s) => setState(() => _minutes = s.first),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _why,
            maxLength: 160,
            decoration: const InputDecoration(
              labelText: 'Why',
              hintText: 'Coming late by bus, near Kazipet',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.ground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: const Text(
              '• Sent about once a minute, only while this app is open.\n'
              '• Stops by itself at the end of the time you choose.\n'
              '• You can stop it any time from the event page.\n'
              '• Deleted from the server a day after sharing ends.',
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: const Icon(Icons.location_on),
            label: Text(_busy ? 'Starting…' : 'Start sharing'),
          ),
        ],
      ),
    );
  }
}
