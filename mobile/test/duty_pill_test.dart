import 'package:abvp_connect/screens/duties_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duty labels speak to the right person', () {
    expect(dutyPill('assigned').label, 'Please accept');
    expect(dutyPill('assigned', forLead: true).label, 'Not accepted yet');
    expect(dutyPill('declined').label, "You can't do this");
    expect(dutyPill('declined', forLead: true).label, "Can't do it");
    expect(dutyPill('in_progress').label, 'On duty');
    expect(dutyPill('done').label, 'Done');
  });
}
