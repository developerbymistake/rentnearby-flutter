import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/shared/buddy_look.dart';
import 'package:bakhli/features/buddy/shared/widgets/segment_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Color _badgeColor(WidgetTester t, String count) {
  final box = t.widget<Container>(find.ancestor(of: find.text(count), matching: find.byType(Container)).first);
  return (box.decoration! as BoxDecoration).color!;
}

Widget _tabs({required int selected}) => MaterialApp(
      home: Scaffold(
        body: SegmentTabs(
          labels: const ['Find', 'My buddies', 'Requests'],
          selected: selected,
          tone: ListingTone.teal,
          counts: const {1: 2, 2: 5},
          solidBadges: const {1},
          onTap: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('a solid badge is pink in both states; other badges turn white on their selected tab', (t) async {
    await t.pumpWidget(_tabs(selected: 1));
    expect(_badgeColor(t, '2'), BuddyLook.countBadge, reason: 'solid badge on the selected tab');
    expect(_badgeColor(t, '5'), BuddyLook.countBadge, reason: 'plain badge on an unselected tab');
    await t.pumpWidget(_tabs(selected: 2));
    expect(_badgeColor(t, '5'), DesignColors.surface, reason: 'plain badge keeps the old white look on its selected tab');
    expect(_badgeColor(t, '2'), BuddyLook.countBadge, reason: 'solid badge on an unselected tab');
  });
}
