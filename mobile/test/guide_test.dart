import 'package:abvp_connect/screens/guide/guide_hub.dart';
import 'package:abvp_connect/screens/guide/guide_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('countdown says how far away the conference is, or that it is live', () {
    final now = DateTime.now();
    final (soon, liveSoon) = guideWhen({
      'starts_at': now.add(const Duration(days: 10)).toIso8601String(),
      'ends_at': now.add(const Duration(days: 13)).toIso8601String(),
    });
    expect(soon, contains('in 10 days'));
    expect(liveSoon, isFalse);

    final (live, isLive) = guideWhen({
      'starts_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      'ends_at': now.add(const Duration(days: 2)).toIso8601String(),
    });
    expect(live, 'Day 2 · Live now');
    expect(isLive, isTrue);
  });

  testWidgets('a food stall shows where it is, how to spot it and its lead', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GuideCard(
              onTap: () {},
              item: {
                'kind': 'food',
                'title': 'Telangana Ruchulu',
                'subtitle': 'Pulihora, sakinalu',
                'location': 'Hall B, Stall 3',
                'landmark': 'Green flag with a Bathukamma',
                'color': '#2E8B57',
                'timings': '11 AM – 10 PM',
                'tags': ['Veg', 'Telangana'],
                'photo_urls': <String>[],
                'distance_km': null,
                'contacts': [
                  {'name': 'Ravi Rao', 'role': 'Stall lead', 'phone': '9000000001', 'is_lead': true},
                ],
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Telangana Ruchulu'), findsOneWidget);
    expect(find.text('Hall B, Stall 3'), findsOneWidget);
    expect(find.text('Look for: Green flag with a Bathukamma'), findsOneWidget);
    expect(find.text('Ravi Rao'), findsOneWidget);
    expect(find.byTooltip('Call 9000000001'), findsOneWidget);
  });
}
