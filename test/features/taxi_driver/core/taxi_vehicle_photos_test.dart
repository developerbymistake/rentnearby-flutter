import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/models/taxi_vehicle_type_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_vehicle_screen.dart';
import 'package:bakhli/features/taxi/taxi_option_sets.dart';
import 'package:bakhli/features/taxi/taxi_vehicle_types_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'taxi_setup_fixtures.dart';

class _Types extends TaxiVehicleTypesController {
  @override
  // ignore: must_call_super
  void onInit() {
    types.value = const [TaxiVehicleTypeModel(id: 'v3', name: 'Maruti Ertiga', category: 'MUV', defaultSeats: 7, sortOrder: 1)];
  }

  @override
  Future<void> load() async {}
}

const _plate = 'https://res.cloudinary.com/x/plate.jpg';
const _display = 'https://res.cloudinary.com/x/display.jpg';

TaxiOwnerModel _draftWithProof() => setupTaxi(percent: 40, step1: true, identity: true, plateUrl: _plate);
TaxiOwnerModel _verified({String? plate = _plate, String? display = _display}) =>
    setupTaxi(status: TaxiStatus.approved, percent: 100, step1: true, identity: true, plateUrl: plate, displayUrl: display, everApproved: true, platePhotoLocked: true);

void _setUp(TaxiOwnerModel? model) {
  setUpTaxiSetup(model);
  Get.put<TaxiVehicleTypesController>(_Types());
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _open(WidgetTester t, TaxiOwnerModel? model) async {
  _setUp(model);
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, const TaxiVehicleScreen(), size: const Size(411, 2400));
  await _settle(t);
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 11));
}

final _mark = RegExp(r'\s*\*\s*$');

Finder _text(String s) => find.byWidgetPredicate((w) {
      if (w is! Text) return false;
      final plain = w.data ?? w.textSpan?.toPlainText(includePlaceholders: false) ?? '';
      return plain.replaceAll(_mark, '').trim() == s;
    });
Finder _removeIn(String sectionTitle) => find.descendant(of: _section(sectionTitle), matching: find.byTooltip('Remove photo'));
Finder _section(String title) => find.ancestor(of: _text(title), matching: find.byType(FormSectionCard)).first;
Finder _inSection(String title, String text) => find.descendant(of: _section(title), matching: _text(text));

void main() {
  setUpAll(() => initTestStorage('taxi_vehicle_photos'));
  tearDown(tearDownTaxiSetup);

  for (final approved in [false, true]) {
    group(approved ? 'approved scale' : 'identity scale', () {
      setUp(() => approved ? DS.applyApproved() : DS.debugReset());
      tearDown(DS.debugReset);

      testWidgets('new taxi: both sections with exact texts, two Add tiles, no Verified', (t) async {
        await _open(t, null);
        for (final s in ['Number plate photo', 'Verification, only we see it', 'Taxi photo', 'Travellers see this', 'Plate must be visible', 'You can change this photo any time. No review needed.']) {
          expect(_text(s), findsOneWidget, reason: s);
        }
        expect(_inSection('Number plate photo', 'Add'), findsOneWidget);
        expect(_inSection('Taxi photo', 'Add'), findsOneWidget);
        expect(_text('Verified'), findsNothing);
        expect(t.takeException(), isNull);
        await _close(t);
      });

      testWidgets('draft with a proof url: Plate band, one remove, Add tile', (t) async {
        await _open(t, _draftWithProof());
        expect(_inSection('Number plate photo', 'Plate'), findsOneWidget);
        expect(find.byTooltip('Remove photo'), findsOneWidget);
        expect(_inSection('Number plate photo', 'Add'), findsOneWidget);
        expect(_text('Plate must be visible'), findsOneWidget);
        await _close(t);
      });

      testWidgets('ever approved: Verified band, no remove, no Add, locked note, plate number note', (t) async {
        await _open(t, _verified(display: null));
        expect(_inSection('Number plate photo', 'Verified'), findsOneWidget);
        expect(_removeIn('Number plate photo'), findsNothing);
        expect(_inSection('Number plate photo', 'Add'), findsNothing);
        expect(_inSection('Number plate photo', 'Change'), findsNothing);
        expect(_text('Verified. This photo cannot be changed.'), findsOneWidget);
        expect(_text('Plate must be visible'), findsNothing);
        expect(_text('Changing the plate number sends your taxi back to review.'), findsOneWidget);
        await _close(t);
      });

      testWidgets('display url set: Taxi band, Change tile, no remove on the remote tile', (t) async {
        await _open(t, _verified());
        expect(_inSection('Taxi photo', 'Taxi'), findsOneWidget);
        expect(_inSection('Taxi photo', 'Change'), findsOneWidget);
        expect(_inSection('Taxi photo', 'Add'), findsNothing);
        expect(_removeIn('Taxi photo'), findsNothing);
        expect(find.byTooltip('Remove photo'), findsNothing);
        expect(_text('You can change this photo any time. No review needed.'), findsOneWidget);
        await _close(t);
      });

      testWidgets('ever approved with no plate url: no proof tile, Next is not blocked by the photo check', (t) async {
        await _open(t, _verified(plate: null, display: null));
        expect(_inSection('Number plate photo', 'Verified'), findsNothing);
        expect(_text('Verified. This photo cannot be changed.'), findsOneWidget);
        await t.tap(find.text('Next'));
        await _settle(t);
        expect(_text('Number plate photo'), findsNothing);
        expect(_text('Driving licence number'), findsWidgets);
        await _close(t);
      });

      testOwnerSizes('vehicle step, verified with display photo', () => const TaxiVehicleScreen(), setUpEach: () {
        if (approved) DS.applyApproved();
        _setUp(_verified());
      }, arrange: _settle, check: (t, size, scale) async {
        final list = find.byType(Scrollable).first;
        await t.scrollUntilVisible(find.text('You can change this photo any time. No review needed.'), 300, scrollable: list);
        await t.pump();
        expect(t.takeException(), isNull);
        await _close(t);
      });
    });
  }
}
