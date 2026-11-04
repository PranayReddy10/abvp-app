import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/loader.dart';

import '../widgets/motion.dart';
import 'feed_screen.dart';
import 'schedule_call_screen.dart';

/// Find office bearers and members. Phone numbers never appear here.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key, required this.session});
  final Session session;

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final _q = TextEditingController();
  bool _bearers = true;
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Directory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => setState(() => _key = UniqueKey()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Name, college or Member ID',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Office bearers'),
                  selected: _bearers,
                  selectedColor: AppColors.saffronSoft,
                  onSelected: (v) => setState(() {
                    _bearers = v;
                    _key = UniqueKey();
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: Loader<List<dynamic>>(
              key: _key,
              load: () async => await widget.session.api.get(
                '/directory?q=${Uri.encodeQueryComponent(_q.text)}&office_bearers=${_bearers ? 1 : 0}',
              ) as List,
              builder: (context, rows, _) => rows.isEmpty
                  ? ListView(
                      children: const [
                        EmptyNote(
                          'No one matches. Try another name or turn off "Office bearers".',
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) {
                        final r = rows[i] as Map<String, dynamic>;
                        final roles = (r['roles'] as List).cast<String>();
                        return FadeSlideIn(
                          index: i,
                          child: ListTile(
                            leading: Initials(
                              r['full_name'] as String,
                              photoUrl: r['photo_url'] as String?,
                            ),
                            title: NameWithBadge(
                              r['full_name'] as String,
                              verified: r['verified'] == true,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (roles.isNotEmpty) roles.join(', '),
                                r['place'],
                              ].whereType<String>().join(' · '),
                            ),
                            trailing: IconButton.filledTonal(
                              tooltip: 'Schedule a call',
                              icon: const Icon(Icons.videocam_outlined),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ScheduleCallScreen(
                                    session: widget.session,
                                    memberId: r['member_id'] as String,
                                    name: r['full_name'] as String,
                                  ),
                                ),
                              ),
                            ),
                            onTap: () => openMember(
                              context,
                              widget.session,
                              r['member_id'] as String,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
