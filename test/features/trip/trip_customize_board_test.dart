import 'dart:io';

import 'package:bakhli/features/trip/trip_strings_customize.dart';
import 'package:bakhli/features/trip/utils/trip_leg_draft.dart';
import 'package:bakhli/features/trip/widgets/customize/trip_customize_board.dart';
import 'package:bakhli/features/trip/widgets/customize/trip_customize_spot_row.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/five_sizes.dart';
import 'support/engine_rig.dart';

const Size _tall = Size(411, 1800);

class _Calls {
  int changed = 0;
  final List<int> added = [];
  final List<int> deleted = [];
}

TripLegDraft _draft(List<int> perDay, {int frozen = 0, Set<int> restDays = const {}}) =>
    TripLegDraft.from(enginePlan([perDay], restDays: restDays), 1, frozenDays: frozen, otherLegsDayCount: 0, otherLegsSpotCount: 0);

Widget _host(
  TripLegDraft draft,
  _Calls calls, {
  int dayLimit = 450,
  ScrollController? scroll,
  double header = 0,
}) =>
    Scaffold(
      body: SingleChildScrollView(
        controller: scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: header),
            TripCustomizeBoard(
              draft: draft,
              dayLimitMinutes: dayLimit,
              firstDate: DateTime(2030, 12, 18),
              onChanged: () => calls.changed++,
              onAddPlaces: calls.added.add,
              onDeleteDay: calls.deleted.add,
            ),
          ],
        ),
      ),
    );

Finder _row(String id) => find.byKey(ValueKey('customize-row-$id'));

List<List<String>> _ids(TripLegDraft d) => [for (final day in d.days) [for (final s in day.spots) s.id]];

Future<TestGesture> _lift(WidgetTester tester, String id) async {
  final g = await tester.startGesture(tester.getCenter(_row(id)));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await g.moveBy(const Offset(0, 4));
  await tester.pump();
  return g;
}

Future<void> _dragOnto(WidgetTester tester, String id, String targetId) async {
  final g = await _lift(tester, id);
  final to = tester.getCenter(_row(targetId));
  await g.moveTo(to);
  await tester.pump();
  await g.moveTo(tester.getCenter(_row(targetId)));
  await tester.pump();
  await g.up();
  await tester.pumpAndSettle();
}

List<String> _haptics = [];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') _haptics.add(call.arguments as String? ?? '');
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('cross_day_drop_lands_at_insertion_index', (tester) async {
    final d = _draft([3, 3, 6]);
    final calls = _Calls();
    await pumpAtSize(tester, _host(d, calls), _tall);

    final g = await _lift(tester, 'L1d1s1');
    expect(find.text(TripStringsCustomize.placeMovedAway), findsOneWidget);
    expect(_haptics, isNotEmpty);
    final before = _haptics.length;
    await g.moveTo(tester.getCenter(_row('L1d2s1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('customize-insert-line')), findsOneWidget);
    await g.up();
    await tester.pumpAndSettle();

    expect(_ids(d)[0], ['L1d1s0', 'L1d1s2']);
    expect(_ids(d)[1], ['L1d2s0', 'L1d1s1', 'L1d2s1', 'L1d2s2']);
    expect(calls.changed, 1);
    expect(_haptics.length, greaterThan(before));
    expect(find.text(TripStringsCustomize.placesChip(4)), findsOneWidget);
    expect(find.text(TripStringsCustomize.placeMovedAway), findsNothing);
  });

  testWidgets('hover_shows_dragged_place_inside_drop_zone_and_hides_floating_copy', (tester) async {
    final d = _draft([3, 3, 6]);
    await pumpAtSize(tester, _host(d, _Calls()), _tall);
    final g = await _lift(tester, 'L1d1s1');
    Finder floating() => find.byWidgetPredicate((w) => w is Visibility && !w.visible);
    expect(floating(), findsNothing);
    await g.moveTo(tester.getCenter(_row('L1d2s1')));
    await tester.pump();
    final zone = find.byKey(const ValueKey('customize-drop-zone'));
    expect(zone, findsOneWidget);
    expect(find.descendant(of: zone, matching: find.byType(TripCustomizeSpotRow)), findsOneWidget);
    expect(floating(), findsOneWidget);
    await g.moveTo(const Offset(2, 2));
    await tester.pump();
    expect(zone, findsNothing);
    expect(floating(), findsNothing);
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('drop on a card body below the rows appends to that day', (tester) async {
    final d = _draft([2, 2]);
    final calls = _Calls();
    await pumpAtSize(tester, _host(d, calls), _tall);
    final g = await _lift(tester, 'L1d1s0');
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('customize-add-1'))) + const Offset(0, -2));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(_ids(d)[1], ['L1d2s0', 'L1d2s1', 'L1d1s0']);
    expect(calls.changed, 1);
  });

  testWidgets('full_day_refuses', (tester) async {
    final d = _draft([3, 3, 6]);
    final calls = _Calls();
    await pumpAtSize(tester, _host(d, calls), _tall);
    final before = _ids(d);
    final sig = TripLegDraft.signatureOf(d.days);

    final g = await _lift(tester, 'L1d1s0');
    final hapticsAfterLift = _haptics.length;
    expect(find.text(TripStringsCustomize.dayFullDrop), findsOneWidget);
    expect(_row('L1d3s2'), findsNothing);
    await g.moveTo(tester.getCenter(find.byKey(const ValueKey('customize-day-2'))));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(_row('L1d3s2'), findsOneWidget);

    expect(_ids(d), before);
    expect(TripLegDraft.signatureOf(d.days), sig);
    expect(d.changed, isFalse);
    expect(calls.changed, 0);
    expect(_haptics.length, hapticsAfterLift);
    expect(find.text(TripStringsCustomize.dayFullDrop), findsNothing);
  });

  testWidgets('reorder inside a day', (tester) async {
    final d = _draft([3, 3]);
    final calls = _Calls();
    await pumpAtSize(tester, _host(d, calls), _tall);
    await _dragOnto(tester, 'L1d1s2', 'L1d1s0');
    expect(_ids(d)[0], ['L1d1s2', 'L1d1s0', 'L1d1s1']);
    await _dragOnto(tester, 'L1d1s2', 'L1d1s1');
    expect(_ids(d)[0], ['L1d1s0', 'L1d1s2', 'L1d1s1']);
    expect(calls.changed, 2);
  });

  testWidgets('reorder inside a full day', (tester) async {
    final d = _draft([6, 1]);
    final calls = _Calls();
    await pumpAtSize(tester, _host(d, calls), _tall);
    await _dragOnto(tester, 'L1d1s5', 'L1d1s0');
    expect(_ids(d)[0], ['L1d1s5', 'L1d1s0', 'L1d1s1', 'L1d1s2', 'L1d1s3', 'L1d1s4']);
    expect(calls.changed, 1);
  });

  testWidgets('dropping a row on itself changes nothing', (tester) async {
    final d = _draft([3]);
    final calls = _Calls();
    await pumpAtSize(tester, _host(d, calls), _tall);
    final g = await _lift(tester, 'L1d1s1');
    await g.moveTo(tester.getCenter(find.text(TripStringsCustomize.placeMovedAway)));
    await tester.pump();
    expect(find.byKey(const ValueKey('customize-insert-line')), findsNothing);
    await g.up();
    await tester.pumpAndSettle();
    expect(_ids(d)[0], ['L1d1s0', 'L1d1s1', 'L1d1s2']);
    expect(calls.changed, 0);
  });

  testWidgets('auto-scroll near the bottom edge at 320x568', (tester) async {
    final d = _draft([6, 6, 6, 3]);
    final calls = _Calls();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpAtSize(tester, _host(d, calls, scroll: scroll, header: 120), const Size(320, 568));
    expect(scroll.offset, 0);
    final g = await _lift(tester, 'L1d1s0');
    await g.moveTo(const Offset(160, 556));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(scroll.offset, greaterThan(100));
    await g.moveTo(const Offset(160, 300));
    await tester.pump(const Duration(milliseconds: 100));
    await g.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty_day_state_and_buttons', (tester) async {
    final d = _draft([2, 0]);
    final calls = _Calls();
    await pumpAtSize(tester, _host(d, calls), _tall);
    expect(find.text(TripStringsCustomize.noPlacesYet), findsOneWidget);
    expect(find.text(TripStringsCustomize.addOrDelete), findsOneWidget);
    expect(find.text(TripStringsCustomize.placesChip(0)), findsOneWidget);
    expect(find.text(TripStringsCustomize.span(0)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('customize-empty-add-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('customize-empty-delete-1')));
    await tester.pump();
    expect(calls.added, [1]);
    expect(calls.deleted, [1]);

    await tester.tap(find.byKey(const ValueKey('customize-add-0')));
    await tester.pump();
    expect(calls.added, [1, 0]);

    await tester.tap(find.byKey(const ValueKey('customize-day-menu-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, TripStringsCustomize.deleteDay));
    await tester.pumpAndSettle();
    expect(calls.deleted, [1, 0]);
  });

  testWidgets('a place can be dropped into an empty day', (tester) async {
    final d = _draft([2, 0]);
    final calls = _Calls();
    await pumpAtSize(tester, _host(d, calls), _tall);
    final g = await _lift(tester, 'L1d1s0');
    await g.moveTo(tester.getCenter(find.text(TripStringsCustomize.noPlacesYet)));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(_ids(d), [['L1d1s1'], ['L1d1s0']]);
    expect(find.text(TripStringsCustomize.noPlacesYet), findsNothing);
  });

  testWidgets('rest day shows its own title and stays editable', (tester) async {
    final d = _draft([2, 0], restDays: {2});
    await pumpAtSize(tester, _host(d, _Calls()), _tall);
    expect(find.text(TripStringsCustomize.restDay), findsOneWidget);
    expect(find.byKey(const ValueKey('customize-empty-add-1')), findsOneWidget);
  });

  testWidgets('chips at 3 and 6, no busy chip (mock has none)', (tester) async {
    final d = _draft([3, 6, 5]);
    await pumpAtSize(tester, _host(d, _Calls(), dayLimit: 290), _tall);
    expect(find.text(TripStringsCustomize.placesChip(3)), findsOneWidget);
    expect(find.text(TripStringsCustomize.placesChip(6)), findsNothing);
    expect(find.text(TripStringsCustomize.full), findsOneWidget);
    expect(find.text(TripStringsCustomize.placesChip(5)), findsOneWidget);
    expect(find.text(TripStringsCustomize.busyDay), findsNothing);
    expect(find.text(TripStringsCustomize.span(d.estimateMinutes(0))), findsOneWidget);
    expect(find.byKey(const ValueKey('customize-add-1')), findsNothing);
    expect(find.byKey(const ValueKey('customize-add-0')), findsOneWidget);
    expect(find.text(TripStringsCustomize.dayTitle(1, DateTime(2030, 12, 18))), findsOneWidget);
    expect(find.text(TripStringsCustomize.dayTitle(3, DateTime(2030, 12, 20))), findsOneWidget);

    await pumpAtSize(tester, _host(d, _Calls(), dayLimit: 450), _tall);
    expect(find.text(TripStringsCustomize.busyDay), findsNothing);
  });

  test('labels follow the mock', () {
    expect(TripStringsCustomize.placesChip(3), '3/6 places');
    expect(TripStringsCustomize.span(580), '9 h 40 m');
    expect(TripStringsCustomize.span(120), '2 h');
    expect(TripStringsCustomize.span(45), '45 m');
    expect(TripStringsCustomize.span(0), '0 h');
    expect(TripStringsCustomize.spotLine('lake', 90), 'Lake · 1 h 30 m');
  });

  testWidgets('frozen day cannot be dragged or dropped on', (tester) async {
    final d = _draft([3, 2], frozen: 1);
    final calls = _Calls();
    await pumpAtSize(tester, _host(d, calls), _tall);
    final card0 = find.byKey(const ValueKey('customize-card-0'));
    final card1 = find.byKey(const ValueKey('customize-card-1'));
    expect(find.descendant(of: card0, matching: find.byType(TripGripDots)), findsNothing);
    expect(find.descendant(of: card0, matching: find.byType(LongPressDraggable<Object>)), findsNothing);
    expect(find.byKey(const ValueKey('customize-day-menu-0')), findsNothing);
    expect(find.byKey(const ValueKey('customize-add-0')), findsNothing);
    expect(find.descendant(of: card1, matching: find.byType(TripGripDots)), findsNWidgets(2));

    final g = await tester.startGesture(tester.getCenter(_row('L1d1s0')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await g.moveTo(tester.getCenter(_row('L1d2s0')));
    await tester.pump();
    expect(find.text(TripStringsCustomize.placeMovedAway), findsNothing);
    await g.up();
    await tester.pumpAndSettle();

    await _dragOnto(tester, 'L1d2s1', 'L1d1s1');
    expect(_ids(d), [['L1d1s0', 'L1d1s1', 'L1d1s2'], ['L1d2s0', 'L1d2s1']]);
    expect(calls.changed, 0);

    await tester.tap(find.text('L1d1s0'));
    await tester.pump();
    expect(find.text(TripStringsCustomize.removeFromTrip), findsNothing);
  });

  testWidgets('remove_sheet_confirms_and_removes', (tester) async {
    final d = _draft([2, 1]);
    final calls = _Calls();
    await pumpAtSize(tester, _host(d, calls), _tall);

    await tester.tap(find.text('L1d2s0'));
    await tester.pump();
    expect(find.byKey(const ValueKey('customize-remove-L1d2s0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('customize-remove-L1d2s0')));
    await tester.pumpAndSettle();
    expect(find.text(TripStringsCustomize.removeTitle('L1d2s0')), findsOneWidget);
    await tester.tap(find.text(TripStringsCustomize.keepIt));
    await tester.pumpAndSettle();
    expect(_ids(d)[1], ['L1d2s0']);
    expect(calls.changed, 0);

    await tester.tap(find.byKey(const ValueKey('customize-remove-L1d2s0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customize-remove-confirm')));
    await tester.pumpAndSettle();
    expect(_ids(d)[1], isEmpty);
    expect(calls.changed, 1);
    expect(find.text(TripStringsCustomize.noPlacesYet), findsOneWidget);
    expect(find.byKey(const ValueKey('customize-remove-L1d2s0')), findsNothing);
  });

  test('board never reads TripPlanController', () {
    final dir = Directory('lib/features/trip/widgets/customize');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    expect(files.length, greaterThanOrEqualTo(4));
    for (final f in files) {
      final text = f.readAsStringSync();
      expect(text.contains('TripPlanController'), isFalse, reason: f.path);
      expect(text.contains('trip_plan_controller'), isFalse, reason: f.path);
      expect(text.contains('package:get/'), isFalse, reason: f.path);
    }
  });

  testFiveSizes(
    'board_five_sizes',
    () => _host(_draft([6, 6, 0, 3, 5], frozen: 1), _Calls(), dayLimit: 300),
    check: (tester, size) async {
      expect(find.text(TripStringsCustomize.full), findsWidgets);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('L1d5s4'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('customize-remove-L1d5s4')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('customize-remove-confirm')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(TripStringsCustomize.keepIt));
      await tester.pumpAndSettle();
    },
  );

  testFiveSizes(
    'board_five_sizes_large_text',
    () => _host(_draft([6, 0, 4]), _Calls(), dayLimit: 300),
    textScale: 1.3,
  );
}
