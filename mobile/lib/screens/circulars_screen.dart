import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/loader.dart';

class CircularsScreen extends StatefulWidget {
  const CircularsScreen({super.key, required this.session});
  final Session session;

  @override
  State<CircularsScreen> createState() => _CircularsScreenState();
}

class _CircularsScreenState extends State<CircularsScreen> {
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Circulars')),
      body: Loader<List<dynamic>>(
        key: _key,
        load: () async => await widget.session.api.get('/circulars') as List,
        builder: (context, rows, _) => rows.isEmpty
            ? ListView(children: const [EmptyNote('No circulars yet. Official circulars from your unit, district, state and national office appear here.')])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = rows[i] as Map<String, dynamic>;
                  final unread = c['is_read'] != true;
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                      leading: unread ? const Icon(Icons.circle, size: 10, color: AppColors.saffron) : const SizedBox(width: 10),
                      minLeadingWidth: 10,
                      title: Text(c['title'] as String, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                      subtitle: Text('${c['from']}${c['vibhag'] != null ? ' · ${c['vibhag']}' : ''} · ${day(c['published_at'] as String)}${c['has_attachment'] == true ? ' · PDF' : ''}'),
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => CircularScreen(session: widget.session, id: c['id'] as int)));
                        setState(() => _key = UniqueKey());
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class CircularScreen extends StatelessWidget {
  const CircularScreen({super.key, required this.session, required this.id});
  final Session session;
  final int id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Circular')),
      body: Loader<Map<String, dynamic>>(
        load: () async => await session.api.get('/circulars/$id') as Map<String, dynamic>,
        builder: (context, c, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
          Text('${c['from']}${c['vibhag'] != null ? ' · ${c['vibhag']}' : ''}'.toUpperCase(),
              style: const TextStyle(color: AppColors.saffronInk, fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 12)),
          const SizedBox(height: 6),
          Text(c['title'] as String, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('${day(c['published_at'] as String)}${c['issued_by'] != null ? ' · ${c['issued_by']}' : ''}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
          SelectableText(c['body'] as String, style: const TextStyle(fontSize: 16, height: 1.5)),
          if (c['attachment_url'] != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(c['attachment_url'] as String), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Open attachment'),
            ),
          ],
        ]),
      ),
    );
  }
}
