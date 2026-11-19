import 'package:bakhli/features/trip/screens/trip_name_screen.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';

Widget _screen({String state = 'Uttarakhand', String city = 'Nainital'}) => TripNameScreen(stateName: state, cityName: city);

TripNameContinue _continue(WidgetTester t) => t.widget<TripNameContinue>(find.byType(TripNameContinue));

void main() {
  testWidgets('suggestion_shown_and_continue_enabled', (tester) async {
    await pumpPhone(tester, _screen());
    expect(find.text('Uttarakhand Hills Trip'), findsOneWidget);
    expect(find.text('22/60'), findsOneWidget);
    expect(find.text('Trip name'), findsWidgets);
    expect(_continue(tester).onPressed, isNotNull);
    expect(find.text('Add a name to continue'), findsNothing);
  });

  testWidgets('continue_bar_sits_right_under_the_counter_like_the_mock', (tester) async {
    await pumpPhone(tester, _screen());
    final counter = tester.getRect(find.text('22/60'));
    final pill = tester.getRect(find.byType(TripNameContinue));
    expect(pill.top, greaterThan(counter.bottom));
    expect(pill.top - counter.bottom, lessThan(80));
    expect(tester.getSize(find.byType(Scaffold)).height - pill.bottom, greaterThan(200));
  });

  testWidgets('empty_blocks_continue_with_error_text', (tester) async {
    await pumpPhone(tester, _screen());
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump();
    expect(find.text('Add a name to continue'), findsOneWidget);
    expect(find.text('0/60'), findsOneWidget);
    expect(_continue(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextFormField), '    ');
    await tester.pump();
    expect(find.text('Add a name to continue'), findsOneWidget);
    expect(_continue(tester).onPressed, isNull);
  });

  testWidgets('sixty_first_character_refused', (tester) async {
    await pumpPhone(tester, _screen());
    await tester.enterText(find.byType(TextFormField), 'a' * 61);
    await tester.pump();
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.controller.text.length, 60);
    expect(find.text('60/60'), findsOneWidget);
    expect(_continue(tester).onPressed, isNotNull);
  });

  testWidgets('counter_text', (tester) async {
    await pumpPhone(tester, _screen(state: '', city: 'Goa'));
    expect(find.text('8/60'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Goa 2027');
    await tester.pump();
    expect(find.text('8/60'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Goa');
    await tester.pump();
    expect(find.text('3/60'), findsOneWidget);
  });

  testWidgets('emoji_is_refused', (tester) async {
    await pumpPhone(tester, _screen());
    await tester.enterText(find.byType(TextFormField), 'Goa \u{1F600}');
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'Goa ');
  });

  testWidgets('continue_returns_the_cleaned_name', (tester) async {
    String? result;
    await pumpPhone(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await Get.to<String>(() => _screen()),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TripNameScreen), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '  My   big  trip ');
    await tester.pump();
    await tester.tap(find.byType(TripNameContinue));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(result, 'My big trip');
  });

  testFiveSizes('name_screen_filled', _screen);
  testFiveSizes('name_screen_empty', _screen, check: (tester, size) async {
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testFiveSizes('name_screen_full_length', _screen, check: (tester, size) async {
    await tester.enterText(find.byType(TextFormField), 'W' * 60);
    await tester.pump();
  });

  testWidgets('keyboard_open_keeps_continue_visible_at_320x568', (tester) async {
    await pumpAtSize(tester, _screen(), const Size(320, 568));
    await tester.enterText(find.byType(TextFormField), 'Trip');
    tester.view.viewInsets = FakeViewPadding(bottom: 260 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.takeException(), isNull);
    final r = tester.getRect(find.byType(TripNameContinue));
    final visibleBottom = 568.0 - 260;
    expect(r.bottom, lessThanOrEqualTo(visibleBottom));
    expect(r.top, greaterThanOrEqualTo(0));
    final f = tester.getRect(find.byType(TextFormField));
    expect(f.top, greaterThanOrEqualTo(tester.getRect(find.byType(TripFlowHeader)).bottom));
    expect(f.bottom, lessThanOrEqualTo(r.top));
  });
}
