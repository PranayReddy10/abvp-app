import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Membership application: personal details, area, Vibhags and photo.
class ApplyScreen extends StatefulWidget {
  const ApplyScreen({super.key, required this.session});
  final Session session;

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _institution = TextEditingController();
  final _course = TextEditingController();
  final _year = TextEditingController();
  DateTime? _dob;
  String? _gender;

  List<OrgUnit> _states = [], _districts = [], _units = [];
  OrgUnit? _state, _district, _unit;
  List<Vibhag> _vibhags = [];
  final Set<int> _chosenVibhags = {};

  File? _photo;
  String? _existingPhoto;
  bool _confirm = false;
  bool _busy = false;
  String? _error;

  ApiClient get api => widget.session.api;

  @override
  void initState() {
    super.initState();
    final p = widget.session.me?.profile;
    if (p != null) {
      _name.text = p.fullName;
      _institution.text = p.institution ?? '';
      _course.text = p.course ?? '';
      _year.text = p.studyYear ?? '';
      _dob = p.dateOfBirth != null ? DateTime.parse(p.dateOfBirth!) : null;
      _gender = p.gender;
      _existingPhoto = p.photoUrl;
      _chosenVibhags.addAll(p.vibhags.map((v) => v.id));
    } else {
      _name.text = widget.session.me?.name ?? '';
    }
    _loadLookups();
  }

  Future<List<OrgUnit>> _unitsUnder(int? parentId) async {
    final data = await api.get(
      parentId == null ? '/org/units' : '/org/units?parent_id=$parentId',
    ) as List;
    return data
        .map((j) => OrgUnit.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> _loadLookups() async {
    try {
      final states = await _unitsUnder(null);
      final vibhags = (await api.get('/vibhags') as List)
          .map((j) => Vibhag.fromJson(j as Map<String, dynamic>))
          .toList();
      setState(() {
        _states = states;
        _vibhags = vibhags;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _pickState(OrgUnit? s) async {
    setState(() {
      _state = s;
      _district = null;
      _unit = null;
      _districts = [];
      _units = [];
    });
    if (s != null) {
      final d = await _unitsUnder(s.id);
      setState(() => _districts = d);
    }
  }

  Future<void> _pickDistrict(OrgUnit? d) async {
    setState(() {
      _district = d;
      _unit = null;
      _units = [];
    });
    if (d != null) {
      final u = await _unitsUnder(d.id);
      setState(() => _units = u);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    // Resize on the phone so uploads stay small on slow networks and shared hosting.
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (x != null) setState(() => _photo = File(x.path));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_dob == null) {
      return setState(() => _error = 'Choose your date of birth.');
    }
    final areaId =
        (_unit ?? _district)?.id ?? widget.session.me?.profile?.orgUnitId;
    if (areaId == null) {
      return setState(() => _error = 'Choose your state, district and unit.');
    }
    if (_photo == null && _existingPhoto == null) {
      return setState(() => _error = 'Add a clear photo of your face.');
    }
    if (!_confirm) {
      return setState(() => _error = 'Confirm that your details are correct.');
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.patch('/me/profile', {
        'full_name': _name.text.trim(),
        'date_of_birth': DateFormat('yyyy-MM-dd').format(_dob!),
        'gender': _gender,
        'org_unit_id': areaId,
        'institution': _institution.text.trim(),
        'course': _course.text.trim(),
        'study_year': _year.text.trim(),
        'vibhag_ids': _chosenVibhags.toList(),
      });
      if (_photo != null) await api.upload('/me/photo', 'photo', _photo!);
      await api.post('/membership/application', {'confirm': true});
      widget.session.editApplication(false);
      await widget.session.refresh();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingArea = widget.session.me?.profile?.orgUnitLabel;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for membership'),
        actions: [
          TextButton(
            onPressed: widget.session.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text(
              'Your application goes to the office for the area you choose. Use your real details.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            _section('About you'),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                _dob == null
                    ? 'Date of birth'
                    : DateFormat('d MMM yyyy').format(_dob!),
              ),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime(now.year - 19),
                  firstDate: DateTime(now.year - 60),
                  lastDate: DateTime(now.year - 14),
                );
                if (picked != null) setState(() => _dob = picked);
              },
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'female', label: Text('Female')),
                ButtonSegment(value: 'male', label: Text('Male')),
                ButtonSegment(value: 'other', label: Text('Other')),
              ],
              selected: {?_gender},
              emptySelectionAllowed: true,
              onSelectionChanged: (s) =>
                  setState(() => _gender = s.isEmpty ? null : s.first),
            ),
            const SizedBox(height: 24),
            _section('Your area'),
            if (existingArea != null && _state == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Currently: $existingArea. Choose again only to change it.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            _dropdown('State', _states, _state, _pickState),
            const SizedBox(height: 12),
            _dropdown('District', _districts, _district, _pickDistrict),
            const SizedBox(height: 12),
            _dropdown(
              'Unit or college',
              _units,
              _unit,
              (u) async => setState(() => _unit = u),
            ),
            const SizedBox(height: 24),
            _section('Study'),
            TextFormField(
              controller: _institution,
              decoration: const InputDecoration(
                labelText: 'College or institution',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _course,
                    decoration: const InputDecoration(labelText: 'Course'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _year,
                    decoration: const InputDecoration(labelText: 'Year'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _section('Vibhags you want to join'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _vibhags
                  .map(
                    (v) => FilterChip(
                      label: Text(v.name),
                      selected: _chosenVibhags.contains(v.id),
                      selectedColor: AppColors.saffronSoft,
                      onSelected: (on) => setState(
                        () => on
                            ? _chosenVibhags.add(v.id)
                            : _chosenVibhags.remove(v.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            _section('Photo'),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 84,
                    height: 100,
                    color: AppColors.line,
                    child: _photo != null
                        ? Image.file(_photo!, fit: BoxFit.cover)
                        : _existingPhoto != null
                        ? Image.network(_existingPhoto!, fit: BoxFit.cover)
                        : const Icon(
                            Icons.person_outline,
                            size: 40,
                            color: AppColors.muted,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Take photo'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _pickPhoto(ImageSource.gallery),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Choose from gallery'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'A clear, front-facing photo. Only you and reviewing officers can see it before approval.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              value: _confirm,
              onChanged: (v) => setState(() => _confirm = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'My details are correct and the photo is of me.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Submitting…' : 'Submit application'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _dropdown(
    String label,
    List<OrgUnit> items,
    OrgUnit? value,
    Future<void> Function(OrgUnit?) onChanged,
  ) {
    return DropdownButtonFormField<OrgUnit>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
          .toList(),
      onChanged: items.isEmpty ? null : (u) => onChanged(u),
    );
  }
}
