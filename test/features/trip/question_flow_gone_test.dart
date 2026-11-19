import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/option_card_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _deleted = [
  'lib/features/trip/widgets/guide',
  'lib/features/trip/controllers/trip_plan_guide.dart',
  'lib/features/trip/utils/trip_guide_rules.dart',
  'lib/features/trip/models/trip_guide_args.dart',
  'lib/features/trip/trip_strings_guide.dart',
  'lib/features/trip/widgets/trip_easy_card.dart',
  'lib/features/trip/widgets/trip_easy_row.dart',
  'lib/features/trip/widgets/trip_easy_mini_bar.dart',
  'lib/features/trip/widgets/trip_going_home_row.dart',
  'lib/features/trip/trip_strings_going_home.dart',
  'lib/features/trip/widgets/trip_back_to_plan_bar.dart',
  'lib/features/trip/widgets/trip_shortlist_toggle.dart',
];

const _symbols = [
  'TripGuideView',
  'guideState',
  'GuideArgs',
  'helpMeFind',
  'TripEasyCard',
  'TripEasyMiniBar',
  'planStep',
  'TripPlanMenu.easy',
  'guideJumpTo',
  'guideRefresh',
  'openRepliesForRow',
  'carWaysFor',
  'debugGuide',
  "Let's get you there",
];

void main() {
  test('the question flow files are deleted', () {
    expect([for (final p in _deleted) if (File(p).existsSync() || Directory(p).existsSync()) p], isEmpty);
  });

  test('no file under lib names the question flow', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final src = f.readAsStringSync();
      for (final s in _symbols) {
        if (src.contains(s)) hits.add('${f.path}: $s');
      }
    }
    expect(hits, isEmpty);
  });

  testWidgets('the three option cards stay as a design widget', (t) async {
    String? picked;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, set) => OptionCardGroup<String>(
              selected: picked,
              onPick: (v) => set(() => picked = v),
              options: [
                OptionChoice(value: 'a', label: 'Help me', art: ListingArt.compass, tone: ListingTone.cB),
                OptionChoice(value: 'b', label: 'Myself', art: ListingArt.backpack, tone: ListingTone.cA),
                OptionChoice(value: 'c', label: 'Skip', art: ListingArt.airplane, tone: ListingTone.cC),
              ],
            ),
          ),
        ),
      ),
    ));
    expect(find.byType(OptionCard), findsNWidgets(3));
    await t.tap(find.text('Myself'));
    await t.pump();
    expect(picked, 'b');
    final states = [for (final c in t.widgetList<OptionCard>(find.byType(OptionCard))) c.state];
    expect(states, [OptionState.off, OptionState.on, OptionState.off]);
    expect(t.takeException(), isNull);
  });
}
