import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/tone_segment_control.dart';
import 'package:bakhli/features/stay/setup/stay_rooms_form.dart';
import 'package:bakhli/features/stay/setup/stay_setup_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import 'stay_setup_fixtures.dart';

const _guestsKey = ValueKey('stay-room-guests');
const _mealsKey = ValueKey('stay-room-meals');

Future<StayRoomsFormController> _pump(WidgetTester t) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(360, 1400);
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
  });
  final c = StayRoomsFormController(onboarding: true, ctrl: StaySetupController(repo: FakeStayRepo(null)))
    ..seed(null)
    ..openForm();
  addTearDown(c.dispose);
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: Scaffold(body: SingleChildScrollView(child: StayRoomsForm(controller: c, tone: ListingTone.forest))),
  ));
  await t.pump();
  return c;
}

Finder _in(ValueKey<String> key, Finder f) => find.descendant(of: find.byKey(key), matching: f);

void main() {
  setUpAll(() => initTestStorage('stay_room_pills_test'));
  tearDown(resetOwnerTestState);

  testWidgets('guests and meals are text-only pill selectors', (t) async {
    await _pump(t);
    expect(find.byKey(_guestsKey), findsOneWidget);
    expect(find.byKey(_mealsKey), findsOneWidget);
    expect(find.byType(ToneSegmentControl), findsNWidgets(2));
    for (final s in ['1', '2', '3', '4+']) {
      expect(_in(_guestsKey, find.text(s)), findsOneWidget);
    }
    for (final s in ['Room only', 'Breakfast', 'All meals']) {
      expect(_in(_mealsKey, find.text(s)), findsOneWidget);
    }
    expect(find.byType(OptionTileGrid), findsNothing);
    expect(_in(_guestsKey, find.byType(Art3D)), findsNothing);
    expect(_in(_mealsKey, find.byType(Art3D)), findsNothing);
    expect(_in(_guestsKey, find.text('guests')), findsNothing);
  });

  testWidgets('tapping a pill selects the same values as before', (t) async {
    final c = await _pump(t);
    expect(c.guests, isNull);
    expect(c.meals, isNull);
    await t.tap(find.text('4+'));
    await t.pump();
    expect(c.guests, 4);
    await t.tap(find.text('3'));
    await t.pump();
    expect(c.guests, 3);
    await t.tap(find.text('All meals'));
    await t.pump();
    expect(c.meals, 'AllMeals');
    await t.tap(find.text('Room only'));
    await t.pump();
    expect(c.meals, 'RoomOnly');
    expect(c.dirty, isTrue);
  });

  testWidgets('pills keep their accessibility labels and selected state', (t) async {
    final handle = t.ensureSemantics();
    await _pump(t);
    await t.tap(find.text('3'));
    await t.tap(find.text('Breakfast'));
    await t.pump();
    expect(t.getSemantics(find.bySemanticsLabel('3 guests')), containsSemantics(label: '3 guests', isSelected: true, isButton: true));
    expect(t.getSemantics(find.bySemanticsLabel('4+ guests')), containsSemantics(label: '4+ guests', isSelected: false));
    expect(t.getSemantics(find.bySemanticsLabel('Breakfast')), containsSemantics(label: 'Breakfast', isSelected: true));
    expect(t.getSemantics(find.bySemanticsLabel('All meals')), containsSemantics(label: 'All meals', isSelected: false));
    handle.dispose();
  });
}
