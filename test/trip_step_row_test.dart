import 'package:bakhli/features/trip/trip_strings_wizard.dart';
import 'package:bakhli/features/trip/utils/trip_wizard_rules.dart';
import 'package:bakhli/features/trip/widgets/trip_step_dot.dart';
import 'package:bakhli/features/trip/widgets/trip_step_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TripStepInfo _info(TripStepState state, {bool needsYou = false, String? note}) => TripStepInfo(
      key: const TripStepKey.stay(1, 2),
      day: 2,
      legIndex: 1,
      state: state,
      title: 'Day 2 · Stay',
      line: 'Line for ${state.name}',
      needsYou: needsYou,
      note: note,
    );

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MediaQuery(data: const MediaQueryData(disableAnimations: true), child: child))),
    );

void main() {
  testWidgets('every state draws its own badge, line and trailing', (tester) async {
    for (final state in TripStepState.values) {
      final info = _info(state);
      await _pump(tester, TripStepRow(info: info, number: 7, title: TripStringsWizard.stay));
      expect(find.text(TripStringsWizard.stay), findsOneWidget);
      expect(find.text('Line for ${state.name}'), findsOneWidget);
      final icon = TripStepMark.of(state).icon;
      if (icon == null) {
        expect(find.text('7'), findsOneWidget, reason: 'todo shows the step number');
      } else {
        expect(find.byIcon(icon), findsOneWidget, reason: state.name);
      }
      final trailing = TripStepRow.trailingOf(info, isNext: false);
      if (trailing.isNotEmpty) expect(find.text(trailing), findsOneWidget, reason: state.name);
    }
  });

  testWidgets('one label per state on the trailing', (tester) async {
    expect(TripStepRow.trailingOf(_info(TripStepState.todo), isNext: true), TripStringsWizard.start);
    expect(TripStepRow.trailingOf(_info(TripStepState.todo), isNext: false), isEmpty);
    expect(TripStepRow.trailingOf(_info(TripStepState.waiting), isNext: false), TripStringsWizard.seeReplies);
    expect(TripStepRow.trailingOf(_info(TripStepState.waiting, needsYou: true), isNext: false), TripStringsWizard.yourTurn);
    expect(TripStepRow.trailingOf(_info(TripStepState.attention), isNext: false), TripStringsWizard.fix);
    for (final s in [TripStepState.done, TripStepState.own, TripStepState.skipped]) {
      expect(TripStepRow.trailingOf(_info(s), isNext: false), TripStringsWizard.edit);
    }
  });

  testWidgets('the next step shows Start and the row is tappable', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      TripStepRow(info: _info(TripStepState.todo), number: 3, title: 'Stay', isNext: true, onTap: () => taps++),
    );
    expect(find.text(TripStringsWizard.start), findsOneWidget);
    await tester.tap(find.text('Stay'));
    expect(taps, 1);
  });

  testWidgets('a note shows under the line', (tester) async {
    await _pump(tester, TripStepRow(info: _info(TripStepState.done, note: 'Advance due'), number: 1, title: 'Stay'));
    expect(find.text('Advance due'), findsOneWidget);
  });

  test('waiting, attention and todo are never drawn as done', () {
    final done = TripStepMark.of(TripStepState.done);
    for (final s in [TripStepState.todo, TripStepState.waiting, TripStepState.attention]) {
      expect(TripStepMark.of(s).color == done.color, isFalse, reason: s.name);
    }
  });
}
