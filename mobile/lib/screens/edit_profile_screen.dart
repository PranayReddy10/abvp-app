import 'dart:io';

import '../l10n.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/area_picker.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

/// Everything about me in one place: photo, name, gender, date of birth, email, area, college,
/// occupation and a short bio.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.session});
  final Session session;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _institution;
  late final TextEditingController _course;
  late final TextEditingController _occupation;
  late final TextEditingController _bio;
  String? _gender;
  DateTime? _dob;
  int? _unitId;
  String? _stateName;
  File? _photo;
  bool _busy = false;
  String? _error;

  Map<String, dynamic> get _json => widget.session.me!.json;
  Map<String, dynamic>? get _profile =>
      _json['profile'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _unit =>
      _profile?['org_unit'] as Map<String, dynamic>?;

  @override
  void initState() {
    super.initState();
    final p = _profile;
    _name = TextEditingController(
      text: (p?['full_name'] as String?) ?? (_json['name'] as String?) ?? '',
    );
    _email = TextEditingController(text: _json['email'] as String? ?? '');
    _institution = TextEditingController(
      text:
          (p?['institution'] as String?) ??
          (_json['institution'] as String?) ??
          '',
    );
    _course = TextEditingController(text: p?['course'] as String? ?? '');
    _occupation = TextEditingController(
      text: _json['occupation'] as String? ?? '',
    );
    _bio = TextEditingController(text: p?['bio'] as String? ?? '');
    _gender = (p?['gender'] as String?) ?? (_json['gender'] as String?);
    final d = p?['date_of_birth'] as String?;
    _dob = d == null ? null : DateTime.tryParse(d);
    _unitId = _unit?['id'] as int?;
  }

  Future<void> _pick(ImageSource source) async {
    Navigator.pop(context);
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (x != null) setState(() => _photo = File(x.path));
  }

  void _photoSheet() => showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(t('Take a photo')),
            onTap: () => _pick(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(t('Choose from gallery')),
            onTap: () => _pick(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(now.year - 60),
      lastDate: DateTime(now.year - 14),
    );
    if (d != null) setState(() => _dob = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = widget.session.api;
    try {
      await api.patch('/me/profile', {
        'full_name': _name.text.trim(),
        'gender': _gender,
        'date_of_birth': _dob == null
            ? null
            : '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}',
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'institution': _institution.text.trim().isEmpty
            ? null
            : _institution.text.trim(),
        'course': _course.text.trim().isEmpty ? null : _course.text.trim(),
        'occupation': _occupation.text.trim().isEmpty
            ? null
            : _occupation.text.trim(),
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        if (_unitId != null && _unitId != _unit?['id']) 'org_unit_id': _unitId,
        'prant': ?_stateName,
      });
      if (_photo != null) await api.upload('/me/photo', 'photo', _photo!);
      await widget.session.refresh();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('Profile saved'))));
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _profile?['photo_url'] as String?;
    final approved = _profile?['membership_status'] == 'approved';
    return Scaffold(
      appBar: AppBar(title: Text(t('Edit profile'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            FadeSlideIn(
              child: Center(
                child: GestureDetector(
                  onTap: _photoSheet,
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.saffron, AppColors.saffronDeep],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor: Colors.white,
                          backgroundImage: _photo != null
                              ? FileImage(_photo!)
                              : (photoUrl != null
                                        ? NetworkImage(photoUrl)
                                        : null)
                                    as ImageProvider?,
                          child: _photo == null && photoUrl == null
                              ? Text(
                                  _name.text.isEmpty
                                      ? '?'
                                      : _name.text.trim()[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.saffron,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _photoSheet,
                child: Text(
                  _photo != null || photoUrl != null
                      ? t('Change photo')
                      : t('Add photo'),
                ),
              ),
            ),
            if (_error != null) ...[
              ErrorBanner(_error!),
              const SizedBox(height: 12),
            ],
            _Group(t('About you')),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: t('Full name'),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? t('Enter your name') : null,
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
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDob,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: t('Date of birth'),
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                child: Text(
                  _dob == null
                      ? t('Choose')
                      : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                ),
              ),
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
            _Group(t('Area')),
            if (approved && _unit != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  t(
                    t(
                      'You are an approved member of {x}. To move to another area, your district office changes it.',
                    ),
                    {
                      'x': (_unit!['label'] as String?)?.isNotEmpty == true
                          ? _unit!['label']
                          : _unit!['name'],
                    },
                  ),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            AreaPicker(
              api: widget.session.api,
              requireDistrict: true,
              initialStateId: _unit?['state_id'] as int?,
              initialDistrictId: _unit?['district_id'] as int?,
              onChanged: (id, state) {
                _unitId = id;
                _stateName = state;
              },
            ),
            _Group(t('Study and work')),
            TextFormField(
              controller: _institution,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: t('College / institution'),
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _course,
              decoration: InputDecoration(
                labelText: t('Course'),
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _occupation,
              decoration: InputDecoration(
                labelText: t('Occupation'),
                prefixIcon: Icon(Icons.work_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _bio,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: t('Short bio'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? t('Saving…') : t('Save profile')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 22, 0, 12),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w800,
        color: AppColors.muted,
      ),
    ),
  );
}
