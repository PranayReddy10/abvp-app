import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../state/session.dart';
import '../widgets/common.dart';

/// Report a programme in under a minute: what, when, how many, photos.
class ReportActivityScreen extends StatefulWidget {
  const ReportActivityScreen({super.key, required this.session});
  final Session session;

  @override
  State<ReportActivityScreen> createState() => _ReportActivityScreenState();
}

class _ReportActivityScreenState extends State<ReportActivityScreen> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _students = TextEditingController();
  final _colleges = TextEditingController();
  final _desc = TextEditingController();
  DateTime _held = DateTime.now();
  String? _type;
  int? _vibhag;
  List<Map<String, dynamic>> _types = [];
  final List<File> _photos = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.session.api.get('/activity-reports/types').then((t) {
      if (mounted) {
        setState(() => _types = (t as List).cast<Map<String, dynamic>>());
      }
    });
  }

  Future<void> _addPhotos() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
      limit: 6 - _photos.length,
    );
    setState(
      () => _photos.addAll(
        picked.take(6 - _photos.length).map((x) => File(x.path)),
      ),
    );
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _type == null || _students.text.isEmpty) {
      setState(
        () => _error = 'Add the programme name, type and number of students.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.api.uploadForm(
        '/activity-reports',
        {
          'title': _title.text.trim(),
          'programme_type': _type!,
          'held_on': DateFormat('yyyy-MM-dd').format(_held),
          'participants': _students.text,
          if (_colleges.text.isNotEmpty) 'institutions': _colleges.text,
          if (_place.text.trim().isNotEmpty) 'place': _place.text.trim(),
          if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
          if (_vibhag != null) 'vibhag_id': '$_vibhag',
        },
        'photos[]',
        _photos,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vibhags = widget.session.me?.profile?.vibhags ?? <Vibhag>[];
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(title: const Text('Report activity')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Programme',
              hintText: 'Lake clean-up drive',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Type'),
            items: _types
                .map(
                  (t) => DropdownMenuItem(
                    value: t['key'] as String,
                    child: Text(t['label'] as String),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('d MMM yyyy').format(_held)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _held,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _held = d);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _vibhag,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Vibhag'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...vibhags.map(
                      (v) => DropdownMenuItem<int?>(
                        value: v.id,
                        child: Text(v.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _vibhag = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _place,
            decoration: const InputDecoration(labelText: 'Place'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _students,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(labelText: 'Students'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _colleges,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(labelText: 'Colleges'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 3,
            maxLength: 3000,
            decoration: const InputDecoration(
              labelText: 'What happened (optional)',
            ),
          ),
          Text(
            'Photos (up to 6)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._photos.map(
                (f) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    f,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (_photos.length < 6)
                InkWell(
                  onTap: _addPhotos,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Submitting…' : 'Submit report'),
          ),
          const SizedBox(height: 8),
          Text(
            'Visible to your district, state and Vibhag coordinators.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
