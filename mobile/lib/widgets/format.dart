import 'package:intl/intl.dart';

final _day = DateFormat('EEE d MMM');
final _time = DateFormat('h:mm a');

String dayTime(String iso) {
  final d = DateTime.parse(iso).toLocal();
  return '${_day.format(d)}, ${_time.format(d)}';
}

String day(String iso) =>
    DateFormat('d MMM yyyy').format(DateTime.parse(iso).toLocal());

String ago(String iso) {
  final diff = DateTime.now().difference(DateTime.parse(iso).toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return DateFormat('d MMM').format(DateTime.parse(iso).toLocal());
}

const providerNames = {
  'google_meet': 'Google Meet',
  'zoom': 'Zoom',
  'teams': 'Microsoft Teams',
  'jitsi': 'Jitsi',
  'youtube': 'YouTube Live',
  'link': 'meeting link',
};

/// Same recognition as the server, so the form can label the link as it is typed.
String? providerFor(String url) {
  final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
  if (host.isEmpty) return null;
  if (host.endsWith('meet.google.com')) return 'google_meet';
  if (host.endsWith('zoom.us') || host.endsWith('zoom.com')) return 'zoom';
  if (host.contains('teams.microsoft.com') || host.contains('teams.live.com')) {
    return 'teams';
  }
  if (host.endsWith('meet.jit.si')) return 'jitsi';
  if (host.endsWith('youtube.com') || host == 'youtu.be') return 'youtube';
  return 'link';
}
