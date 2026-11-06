import 'package:bakhli/features/trip/screens/trip_step_screen.dart';
import 'package:bakhli/features/trip/trip_strings_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, TripStepFooter footer) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(bottomNavigationBar: footer),
        ),
      ),
    );

void main() {
  testWidgets('first step hides Prev and names the next step', (tester) async {
    var next = 0;
    await _pump(
      tester,
      TripStepFooter(showPrev: false, nextTitle: 'Getting there', onPrev: () {}, onNext: () => next++, onDone: () {}),
    );
    expect(find.text(TripStringsWizard.prev), findsNothing);
    expect(find.text(TripStringsWizard.nextTo('Getting there')), findsOneWidget);
    await tester.tap(find.text(TripStringsWizard.nextTo('Getting there')));
    expect(next, 1);
  });

  testWidgets('middle step shows Prev and Next', (tester) async {
    var prev = 0;
    await _pump(
      tester,
      TripStepFooter(showPrev: true, nextTitle: 'Day 1 · Places', onPrev: () => prev++, onNext: () {}, onDone: () {}),
    );
    await tester.tap(find.text(TripStringsWizard.prev));
    expect(prev, 1);
    expect(find.text(TripStringsWizard.nextTo('Day 1 · Places')), findsOneWidget);
  });

  testWidgets('last step reads Done and goes back to the list', (tester) async {
    var done = 0;
    var next = 0;
    await _pump(
      tester,
      TripStepFooter(showPrev: true, nextTitle: null, onPrev: () {}, onNext: () => next++, onDone: () => done++),
    );
    expect(find.text(TripStringsWizard.doneBackToList), findsOneWidget);
    await tester.tap(find.text(TripStringsWizard.doneBackToList));
    expect(done, 1);
    expect(next, 0);
  });
}
