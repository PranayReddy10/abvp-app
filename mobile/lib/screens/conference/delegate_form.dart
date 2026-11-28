import 'package:flutter/material.dart';

import '../../l10n.dart';

import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../state/session.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../analytics.dart';
import '../../widgets/motion.dart';

typedef Json = Map<String, dynamic>;

/// The delegate form. Opens the first time a person taps Delegate; filled from their account and
/// profile, and every field can be changed. Everything is required except email.
class DelegateFormScreen extends StatefulWidget {
  const DelegateFormScreen({
    super.key,
    required this.session,
    required this.eventId,
    required this.data,
  });
  final Session session;
  final int eventId;

  /// The GET /events/{id}/delegate payload.
  final Json data;

  @override
  State<DelegateFormScreen> createState() => _DelegateFormScreenState();
}

class _DelegateFormScreenState extends State<DelegateFormScreen>
    with TrackScreen {
  @override
  String get screenName => 'Delegate form';

  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _surname = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _responsibility = TextEditingController();
  final _arrivalPlace = TextEditingController();
  String? _gender;
  String? _prant;
  String? _mode;
  DateTime? _arrive;
  DateTime? _depart;
  bool _busy = false;
  String? _error;

  Json get _reg => (widget.data['registration'] as Json?) ?? {};
  Json get _opts => (widget.data['options'] as Json?) ?? {};
  List<String> get _prants => ((_opts['prants'] as List?) ?? []).cast<String>();
  List<String> get _points =>
      ((_opts['arrival_points'] as List?) ?? []).cast<String>();
  List<Json> get _modes => ((_opts['modes'] as List?) ?? []).cast<Json>();

  @override
  void initState() {
    super.initState();
    final p = (widget.data['prefill'] as Json?) ?? {};
    final d = (_reg['details'] as Json?) ?? {};
    final t = (_reg['travel'] as Json?) ?? {};
    String? pick(String k) => (d[k] ?? p[k]) as String?;
    _first.text = pick('first_name') ?? '';
    _surname.text = pick('surname') ?? '';
    _mobile.text = (pick('mobile') ?? '').replaceFirst('+91', '');
    _email.text = pick('email') ?? '';
    _responsibility.text = pick('responsibility') ?? '';
    _gender = pick('gender');
    final prant = pick('prant');
    _prant = prant != null && _prants.contains(prant) ? prant : null;
    _mode = t['mode'] as String?;
    _arrivalPlace.text = t['arrival_point'] as String? ?? '';
    _arrive = _parse(t['arriving_at'] as String?);
    _depart = _parse(t['departing_at'] as String?);
  }

  DateTime? _parse(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso)?.toLocal();

  Future<void> _pickWhen(bool arrival) async {
    final ev = (widget.data['event'] as Json?) ?? {};
    final start = _parse(ev['starts_at'] as String?) ?? DateTime.now();
    final base =
        (arrival ? _arrive : _depart) ??
        (arrival
            ? start.subtract(const Duration(days: 1))
            : start.add(const Duration(days: 3)));
    final day = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: start.subtract(const Duration(days: 10)),
      lastDate: start.add(const Duration(days: 15)),
      helpText: arrival ? t('Arrival date') : t('Departure date'),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: arrival ? t('Arrival time') : t('Departure time'),
    );
    if (time == null) return;
    final v = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    setState(() => arrival ? _arrive = v : _depart = v);
  }

  Future<void> _submit() async {
    final ok = _form.currentState!.validate();
    if (_arrive == null || _depart == null) {
      setState(
        () => _error = t('Choose your arrival and departure date and time.'),
      );
      return;
    }
    if (!ok) return;
    if (!_depart!.isAfter(_arrive!)) {
      setState(() => _error = t('Departure must be after arrival.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.api.put('/events/${widget.eventId}/delegate', {
        'first_name': _first.text.trim(),
        'surname': _surname.text.trim(),
        'mobile': _mobile.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'gender': _gender,
        'prant': _prant,
        'responsibility': _responsibility.text.trim(),
        'arriving_at': _arrive!.toUtc().toIso8601String(),
        'arrival_point': _arrivalPlace.text.trim(),
        'departing_at': _depart!.toUtc().toIso8601String(),
        'mode': _mode,
      });
      Analytics.event('delegate_register', {
        'edit': widget.data['registration'] != null ? 1 : 0,
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? t('Required') : null;

  @override
  Widget build(BuildContext context) {
    final ev = (widget.data['event'] as Json?) ?? {};
    final editing = widget.data['registration'] != null;
    final fmt = DateFormat('EEE d MMM, h:mm a');
    Widget when(String label, DateTime? v, bool arrival) => InkWell(
      onTap: () => _pickWhen(arrival),
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            arrival ? Icons.flight_land_rounded : Icons.flight_takeoff_rounded,
          ),
        ),
        child: Text(
          v == null ? t('Choose date and time') : fmt.format(v),
          style: TextStyle(color: v == null ? AppColors.muted : AppColors.ink),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing ? t('My delegate form') : t('Delegate registration'),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            FadeSlideIn(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3E8BF0), Color(0xFF13235B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.badge_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ev['title'] as String? ?? t('Conference'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            t(
                              'We filled in what we know. Check everything; all fields except email are needed.',
                            ),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              ErrorBanner(_error!),
            ],
            _Step(1, t('Who you are')),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _first,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: t('First name')),
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _surname,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: t('Surname')),
                    validator: _required,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: t('Mobile number'),
                prefixText: '+91  ',
                prefixIcon: Icon(Icons.phone_iphone),
              ),
              validator: (v) =>
                  RegExp(r'^[0-9]{10}$').hasMatch((v ?? '').replaceAll(' ', ''))
                  ? null
                  : t('Enter a 10-digit mobile number'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: t('Email (optional)'),
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: InputDecoration(
                labelText: t('Gender'),
                prefixIcon: Icon(Icons.wc_rounded),
              ),
              items: [
                DropdownMenuItem(value: 'male', child: Text(t('Male'))),
                DropdownMenuItem(value: 'female', child: Text(t('Female'))),
                DropdownMenuItem(value: 'other', child: Text(t('Other'))),
              ],
              validator: (v) => v == null ? t('Required') : null,
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _prant,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t('Prant'),
                prefixIcon: Icon(Icons.map_outlined),
              ),
              items: [
                for (final p in _prants)
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              validator: (v) => v == null ? t('Required') : null,
              onChanged: (v) => setState(() => _prant = v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _responsibility,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: t('Responsibility'),
                hintText: t('e.g. Zilla Sanghatan Mantri'),
                prefixIcon: Icon(Icons.workspace_premium_outlined),
              ),
              validator: _required,
            ),
            _Step(2, t('Arrival and departure')),
            when(t('Arrival date and time'), _arrive, true),
            const SizedBox(height: 14),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _arrivalPlace.text),
              optionsBuilder: (v) => _points.where(
                (p) => p.toLowerCase().contains(v.text.toLowerCase()),
              ),
              onSelected: (v) => _arrivalPlace.text = v,
              fieldViewBuilder: (context, c, focus, submit) => TextFormField(
                controller: c,
                focusNode: focus,
                onChanged: (v) => _arrivalPlace.text = v,
                decoration: InputDecoration(
                  labelText: t('Arrival place'),
                  hintText: t('Station, airport or bus stand'),
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: _required,
              ),
            ),
            const SizedBox(height: 14),
            when(t('Departure date and time'), _depart, false),
            _Step(3, t('How you are coming')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _modes)
                  ChoiceChip(
                    label: Text(m['label'] as String),
                    avatar: Icon(_modeIcon(m['key'] as String), size: 18),
                    selected: _mode == m['key'],
                    onSelected: (_) =>
                        setState(() => _mode = m['key'] as String),
                  ),
              ],
            ),
            if (_mode == null)
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  t('Choose one'),
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy || _mode == null ? null : _submit,
              child: Text(
                _busy
                    ? t('Saving…')
                    : editing
                    ? t('Save changes')
                    : t('Register as delegate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _modeIcon(String k) => switch (k) {
  'train' => Icons.train_rounded,
  'bus' => Icons.directions_bus_rounded,
  'flight' => Icons.flight_rounded,
  'own' => Icons.directions_car_rounded,
  _ => Icons.more_horiz_rounded,
};

class _Step extends StatelessWidget {
  const _Step(this.n, this.title);
  final int n;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
    child: Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: AppColors.saffron,
          child: Text(
            '$n',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
