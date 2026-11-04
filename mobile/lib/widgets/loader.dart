import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'common.dart';

/// Loads data, shows a spinner, an error with Retry, or the content. Pull to refresh.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() reload,
  )
  builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = _data == null);
    try {
      final d = await widget.load();
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ErrorBanner(_error ?? 'Could not load.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _reload, child: const Text('Try again')),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: widget.builder(context, _data as T, _reload),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}
