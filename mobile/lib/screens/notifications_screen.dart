import 'package:flutter/material.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/format.dart';
import '../widgets/loader.dart';
import 'circulars_screen.dart';
import 'meeting_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, required this.session});
  final Session session;

  static IconData _icon(String type) => switch (type) {
        'meeting_invite' || 'meeting_reminder' => Icons.groups_outlined,
        'call_request' || 'call_reply' => Icons.videocam_outlined,
        'meeting_cancelled' => Icons.event_busy_outlined,
        'action_item' => Icons.task_alt,
        'circular_reminder' => Icons.campaign_outlined,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Loader<List<dynamic>>(
        load: () async {
          final rows = await session.api.get('/notifications') as List;
          await session.api.post('/notifications/read-all');
          return rows;
        },
        builder: (context, rows, _) => rows.isEmpty
            ? ListView(children: const [EmptyNote('Nothing yet. Meeting invitations, call requests and reminders show up here.')])
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                itemBuilder: (context, i) {
                  final n = rows[i] as Map<String, dynamic>;
                  final data = Map<String, dynamic>.from(n['data'] as Map? ?? {});
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: n['is_read'] == true ? AppColors.ground : AppColors.saffronSoft,
                      child: Icon(_icon(n['type'] as String), color: AppColors.saffronInk, size: 20),
                    ),
                    title: Text(n['title'] as String, style: TextStyle(fontWeight: n['is_read'] == true ? FontWeight.w500 : FontWeight.w800)),
                    subtitle: Text([n['body'], ago(n['at'] as String)].whereType<String>().join(' · ')),
                    onTap: () {
                      if (data['meeting_id'] != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => MeetingScreen(session: session, id: data['meeting_id'] as int)));
                      } else if (data['circular_id'] != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CircularScreen(session: session, id: data['circular_id'] as int)));
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}
