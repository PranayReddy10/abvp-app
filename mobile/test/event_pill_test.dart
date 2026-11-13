import 'package:abvp_connect/screens/events_screen.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> event({
  Map<String, dynamic>? reg,
  bool eligible = true,
  bool open = true,
  int? seats = 10,
  String status = 'published',
}) => {
  'status': status,
  'eligible': eligible,
  'registration_open': open,
  'seats_left': seats,
  'registration_closes_at': '2026-11-20T10:00:00Z',
  'my_registration': reg,
};

void main() {
  test('event card says what the member can do', () {
    expect(eventPill(event()).label, startsWith('Open · closes'));
    expect(eventPill(event(seats: 0)).label, 'Full · join waitlist');
    expect(eventPill(event(eligible: false)).label, 'Not eligible');
    expect(eventPill(event(open: false)).label, 'Registration closed');
    expect(
      eventPill(event(reg: {'status': 'registered', 'kind': 'member'})).label,
      'Registered',
    );
    expect(
      eventPill(event(reg: {'status': 'registered', 'kind': 'guest'})).label,
      'Invited',
    );
    expect(
      eventPill(event(reg: {'status': 'waitlisted'})).label,
      'On waitlist',
    );
    expect(
      eventPill(
        event(
          reg: {
            'status': 'registered',
            'checked_in_at': '2026-11-04T03:00:00Z',
          },
        ),
      ).label,
      'Checked in',
    );
    expect(
      eventPill(event(status: 'cancelled', reg: {'status': 'registered'}))
          .label,
      'Cancelled',
    );
  });
}
