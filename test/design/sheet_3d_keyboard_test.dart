import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/plan/plan_limit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/owner_sizes.dart';
import '../support/real_phone.dart';

// FX-07: sheets with art stay inside the screen when the keyboard opens or the window is short.
const _gate = GateSpec(
  id: 'g10',
  title: 'You have 4 active entries',
  body: 'Free keeps 4 bookings you add yourself. Plus keeps 50.',
  taxi: false,
  rows: [GateRow(label: 'Free', value: '4 bookings you add'), GateRow(label: 'Plus', value: '50 bookings you add', highlight: true)],
  tip: 'A slot frees up when a booking date passes, or delete one you do not need.',
);

Widget _form() => Sheet3D(
      tone: ListingTone.forest,
      art: ListingArt.locked,
      title: 'Send offer',
      subtitle: 'Your price for 2 nights, 2 adults',
      size: SheetSize.form,
      footer: PrimaryButton(key: const ValueKey('primary'), label: 'Send offer', onPressed: () {}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 3; i++) Padding(padding: DS.sym(v: 8), child: Text('Line $i of the offer')),
          const TextField(key: ValueKey('field'), decoration: InputDecoration(hintText: 'Price per night')),
          for (var i = 0; i < 3; i++) Padding(padding: DS.sym(v: 8), child: Text('Note $i')),
        ],
      ),
    );

Widget _opener(Widget Function() sheet) => Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: TextButton(onPressed: () => Sheet3D.show<void>(ctx, builder: (_) => sheet()), child: const Text('open')),
        ),
      ),
    );

Future<void> _open(WidgetTester t) async {
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _reachable(WidgetTester t, Finder f, Size size) async {
  expect(f, findsOneWidget);
  await t.ensureVisible(f);
  await t.pump();
  final kb = t.view.viewInsets.bottom / t.view.devicePixelRatio;
  final r = t.getRect(f);
  expect(r.top, greaterThanOrEqualTo(0));
  expect(r.bottom, lessThanOrEqualTo(size.height - kb + 0.5), reason: 'above the keyboard');
}

void main() {
  test('compact rule: a short window drops art, a tall one keeps it', () {
    expect(Sheet3D.artRoom, greaterThan(0));
    expect(Sheet3D.minBody, greaterThan(0));
  });

  testOwnerMatrix(
    'form sheet with art',
    () => _opener(_form),
    keyboard: true,
    arrange: _open,
    check: (t, size, scale, kb) async {
      await _reachable(t, find.byKey(const ValueKey('primary')), size);
      if (kb) await _reachable(t, find.byKey(const ValueKey('field')), size);
    },
  );

  testOwnerMatrix(
    'plan limit sheet',
    () => _opener(() => const PlanLimitSheet(spec: _gate)),
    keyboard: true,
    arrange: _open,
    check: (t, size, scale, kb) async {
      await _reachable(t, find.text('See Plus'), size);
    },
  );

  testWidgets('a tall phone keeps the art and the subtitle; 320x568 with the keyboard drops both', (t) async {
    await pumpPhone(t, _opener(_form), size: const Size(411, 891));
    await _open(t);
    expect(find.byType(Art3D), findsWidgets);
    expect(find.text('Your price for 2 nights, 2 adults'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await pumpPhone(t, _opener(_form), size: const Size(320, 568));
    await _open(t);
    openOwnerKeyboard(t, const Size(320, 568));
    await t.pump();
    expect(find.text('Your price for 2 nights, 2 adults'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
