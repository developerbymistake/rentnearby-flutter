import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_screen.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import '../core/taxi_fixtures.dart';

// FT-14 (layout fix is FX-07 in the shared Sheet3D): taxi hub sheets with the keyboard open at small heights.

const _sizes = [Size(320, 568), Size(360, 640), Size(800, 360)];
const _scales = [1.0, 1.3];

// Remove when FX-07 (Sheet3D compact mode with the keyboard open) lands; until then 4.6 to 63 px overflow is expected.
const _waitsForFx07 = 'FT-14 waits for FX-07 in lib/design/extra/sheet_3d.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _keyboard(WidgetTester t, Size size) async {
  t.view.viewInsets = FakeViewPadding(bottom: size.height * 0.42 * t.view.devicePixelRatio);
  addTearDown(t.view.resetViewInsets);
  await _settle(t);
}

void _aboveKeyboard(WidgetTester t, Finder f, Size size) {
  expect(f, findsWidgets);
  final r = t.getRect(f.last);
  expect(r.bottom, lessThanOrEqualTo(size.height * 0.58 + 0.5), reason: 'covered by the keyboard: $r');
}

void main() {
  setUpAll(() => initTestStorage('taxi_hub_sheets_keyboard'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  for (final size in _sizes) {
    for (final scale in _scales) {
      final label = '${size.width.toInt()}x${size.height.toInt()} @$scale';

      testWidgets('Edit fare sheet $label', (t) async {
        final c = hubFor(taxiJson());
        await pumpPhone(t, TaxiHubScreen(root: true, controller: c), size: size, textScale: scale, devicePixelRatio: 2);
        await _settle(t);
        await t.ensureVisible(find.text('Edit fare').first);
        await t.tap(find.text('Edit fare').first);
        await _settle(t);
        await t.showKeyboard(find.byType(EditableText).first);
        await _keyboard(t, size);
        expect(t.takeException(), isNull);
        _aboveKeyboard(t, find.byType(EditableText).first, size);
        _aboveKeyboard(t, find.text('Save'), size);
      }, skip: _waitsForFx07.isNotEmpty);

      testWidgets('Local rate sheet $label', (t) async {
        final c = hubFor(taxiJson());
        await pumpPhone(t, TaxiHubScreen(root: true, controller: c), size: size, textScale: scale, devicePixelRatio: 2);
        await _settle(t);
        await t.ensureVisible(find.text('LOCAL SIGHTSEEING'));
        await t.pump();
        final edits = find.text('Edit');
        await t.ensureVisible(edits.first);
        await t.tap(edits.first);
        await _settle(t);
        await t.showKeyboard(find.byType(EditableText).first);
        await _keyboard(t, size);
        expect(t.takeException(), isNull);
        _aboveKeyboard(t, find.byType(EditableText).first, size);
        _aboveKeyboard(t, find.text('Save'), size);
      }, skip: _waitsForFx07.isNotEmpty);

      testWidgets('Edit route sheet $label', (t) async {
        final c = hubFor(taxiJson(routes: 2), plan: OwnerPlans.plus);
        await pumpPhone(t, TaxiHubScreen(root: true, controller: c), size: size, textScale: scale, devicePixelRatio: 2);
        await _settle(t);
        await t.ensureVisible(find.byIcon(Icons.more_vert_rounded).first);
        await t.tap(find.byIcon(Icons.more_vert_rounded).first);
        await _settle(t);
        await t.tap(find.text('Edit route'));
        await _settle(t);
        final fields = find.byType(EditableText);
        await t.showKeyboard(fields.last);
        await _keyboard(t, size);
        expect(t.takeException(), isNull);
        _aboveKeyboard(t, fields.last, size);
        _aboveKeyboard(t, find.text('Save route'), size);
      }, skip: _waitsForFx07.isNotEmpty);

      testWidgets('Review sheet $label', (t) async {
        await pumpPhone(
          t,
          Scaffold(body: Builder(builder: (ctx) => Center(child: TextButton(onPressed: () => TaxiReviewSheet.ask(ctx), child: const Text('open'))))),
          size: size,
          textScale: scale,
          devicePixelRatio: 2,
        );
        await t.tap(find.text('open'));
        await _settle(t);
        expect(t.takeException(), isNull);
        final send = find.text('Send for review');
        expect(send, findsWidgets);
        expect(t.getRect(send.last).bottom, lessThanOrEqualTo(size.height));
      }, skip: _waitsForFx07.isNotEmpty);
    }
  }
}
