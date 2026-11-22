import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_owner_card.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_screen.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_preview_card.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_hub_strings.dart';
import 'package:bakhli/features/taxi_driver/widgets/taxi_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import '../core/taxi_fixtures.dart';

const _display = 'https://res.cloudinary.com/x/display.jpg';

Map<String, dynamic> _json({String status = 'Approved', String? display}) => taxiJson(status: status)..['displayPhotoUrl'] = display;

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _openHub(WidgetTester t, Map<String, dynamic> json) async {
  final c = hubFor(json);
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, TaxiHubScreen(root: true, controller: c), size: const Size(411, 2600), toastHost: true);
  await _settle(t);
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 6));
}

Finder _photoRow() => find.ancestor(of: find.text('Taxi photo'), matching: find.byType(TaxiRowTile)).first;
Finder _taxiArt() => find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.taxi);

Future<void> _pumpCard(WidgetTester t, Widget card) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.only(top: 80, left: 12, right: 12), child: card)));
  await t.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(() => initTestStorage('taxi_hub_photo_row'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  test('vehicle hint no longer mentions photos', () {
    expect(TaxiHubStrings.vehicleHint, 'Licence or date of birth changes go for review');
  });

  for (final approved in [false, true]) {
    group(approved ? 'approved scale' : 'identity scale', () {
      setUp(() => approved ? DS.applyApproved() : DS.debugReset());
      tearDown(DS.debugReset);

      testWidgets('row reads Add when there is no photo', (t) async {
        await _openHub(t, _json());
        await t.ensureVisible(find.text('Taxi photo'));
        expect(find.text('VEHICLE AND CONTACT'), findsOneWidget);
        expect(find.text('Add a photo travellers will see'), findsOneWidget);
        expect(find.descendant(of: _photoRow(), matching: find.text('Add')), findsOneWidget);
        await _close(t);
      });

      testWidgets('row reads Change when the photo is set', (t) async {
        await _openHub(t, _json(display: _display));
        await t.ensureVisible(find.text('Taxi photo'));
        expect(find.text('Travellers see this'), findsOneWidget);
        expect(find.descendant(of: _photoRow(), matching: find.text('Change')), findsOneWidget);
        await _close(t);
      });

      testWidgets('under review the photo row still opens the picker while the vehicle row is locked', (t) async {
        await _openHub(t, _json(status: 'PendingReview'));
        await t.ensureVisible(find.text('Taxi photo'));
        await t.tap(find.text('Add a photo travellers will see'));
        await _settle(t);
        expect(find.text('Take Photo'), findsOneWidget);
        expect(find.text('Choose from Gallery'), findsOneWidget);
        await _close(t);
      });

      testWidgets('under review the Add pill itself opens the picker', (t) async {
        await _openHub(t, _json(status: 'PendingReview'));
        await t.ensureVisible(find.text('Taxi photo'));
        await t.tap(find.descendant(of: _photoRow(), matching: find.text('Add')));
        await _settle(t);
        expect(find.text('Take Photo'), findsOneWidget);
        await _close(t);
      });

      testWidgets('preview card: PhotoCircle with a url, taxi Art3D without', (t) async {
        await _pumpCard(t, TaxiPreviewCard(taxi: TaxiOwnerModel.fromJson(_json(display: _display))));
        expect(find.byType(PhotoCircle), findsOneWidget);
        await _pumpCard(t, TaxiPreviewCard(taxi: TaxiOwnerModel.fromJson(_json())));
        expect(find.byType(PhotoCircle), findsNothing);
        expect(_taxiArt(), findsOneWidget);
        expect(t.takeException(), isNull);
        await _close(t);
      });

      testWidgets('My Taxi card: PhotoCircle with a url, taxi Art3D without', (t) async {
        hubFor(null);
        await _pumpCard(t, TaxiOwnerCard(taxi: TaxiOwnerModel.fromJson(_json(display: _display))));
        expect(find.byType(PhotoCircle), findsOneWidget);
        await _pumpCard(t, TaxiOwnerCard(taxi: TaxiOwnerModel.fromJson(_json())));
        expect(find.byType(PhotoCircle), findsNothing);
        expect(_taxiArt(), findsWidgets);
        expect(t.takeException(), isNull);
        await _close(t);
      });

      for (final display in [null, _display]) {
        testOwnerSizes('hub with ${display == null ? 'no' : 'a'} taxi photo', () => TaxiHubScreen(root: true, controller: hubFor(_json(display: display))), arrange: _settle, check: (t, size, scale) async {
          await t.scrollUntilVisible(find.text('Taxi photo'), 300, scrollable: find.byType(Scrollable).first);
          await t.pump();
          expect(t.takeException(), isNull);
          await _close(t);
        });
      }
    });
  }
}
