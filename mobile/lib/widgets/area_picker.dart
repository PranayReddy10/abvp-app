import 'package:flutter/material.dart';

import '../l10n.dart';
import '../api/api_client.dart';

typedef _Unit = Map<String, dynamic>;

/// State → district, from the Areas the admin panel manages (/org/units).
/// Reports the chosen unit (the district, or the state when it has no districts) and the state name.
class AreaPicker extends StatefulWidget {
  const AreaPicker({
    super.key,
    required this.api,
    required this.onChanged,
    this.initialStateId,
    this.initialDistrictId,
    this.requireDistrict = false,
  });
  final ApiClient api;
  final void Function(int? unitId, String? stateName) onChanged;
  final int? initialStateId;
  final int? initialDistrictId;
  final bool requireDistrict;

  @override
  State<AreaPicker> createState() => _AreaPickerState();
}

class _AreaPickerState extends State<AreaPicker> {
  List<_Unit> _states = [];
  List<_Unit> _districts = [];
  int? _state;
  int? _district;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<_Unit>> _under(int? parent) async {
    final data = await widget.api.get(
      parent == null ? '/org/units' : '/org/units?parent_id=$parent',
    ) as List;
    return data.cast<_Unit>();
  }

  Future<void> _load() async {
    try {
      final s = await _under(null);
      if (!mounted) return;
      setState(() {
        _states = s;
        _loading = false;
      });
      if (widget.initialStateId != null &&
          s.any((x) => x['id'] == widget.initialStateId)) {
        await _pickState(widget.initialStateId, initial: true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  String? get _stateName =>
      _states.where((x) => x['id'] == _state).firstOrNull?['name'] as String?;

  void _report() => widget.onChanged(
    _district ?? (_districts.isEmpty ? _state : null),
    _stateName,
  );

  Future<void> _pickState(int? id, {bool initial = false}) async {
    setState(() {
      _state = id;
      _district = null;
      _districts = [];
    });
    _report();
    if (id == null) return;
    final d = await _under(id);
    if (!mounted) return;
    setState(() {
      _districts = d;
      if (initial && d.any((x) => x['id'] == widget.initialDistrictId)) {
        _district = widget.initialDistrictId;
      }
    });
    _report();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.red));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('state-$_loading'),
          initialValue: _state,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _loading ? t('Loading states…') : t('State / Prant'),
            prefixIcon: const Icon(Icons.map_outlined),
          ),
          items: [
            for (final s in _states)
              DropdownMenuItem(
                value: s['id'] as int,
                child: Text(s['name'] as String),
              ),
          ],
          validator: (v) => v == null ? t('Choose your state') : null,
          onChanged: (v) => _pickState(v),
        ),
        if (_districts.isNotEmpty) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            key: ValueKey('district-$_state'),
            initialValue: _district,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: t('District'),
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            items: [
              for (final d in _districts)
                DropdownMenuItem(
                  value: d['id'] as int,
                  child: Text(d['name'] as String),
                ),
            ],
            validator: (v) => v == null && widget.requireDistrict
                ? t('Choose your district')
                : null,
            onChanged: (v) {
              setState(() => _district = v);
              _report();
            },
          ),
        ],
      ],
    );
  }
}
