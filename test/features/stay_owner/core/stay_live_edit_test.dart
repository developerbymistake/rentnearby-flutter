import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/stay/setup/stay_setup_controller.dart';
import 'package:bakhli/features/stay_owner/live_edit/stay_live_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

import '../../../support/owner_fakes.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';
import 'stay_fixtures.dart';
import 'stay_setup_fixtures.dart';

Map<String, dynamic> _live() => {
      ...stayJson(),
      'facilities': ['WiFi', 'Parking', 'HotWater'],
      'registrationNumber': 'UDYAM-UK-05-0001234',
      'address': 'Sargakhet, Mukteshwar',
      'stayTypeId': 't1',
    };

StaySetupController _setup({String status = 'Approved'}) =>
    setupFor(stayModel(status == 'Approved' ? _live() : {...stayJson(status: status)}), stayStatus: status);

Future<void> _pump(WidgetTester t, {Size size = phoneSize, double scale = 1}) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, StayLiveEditScreen(setup: Get.find<StaySetupController>()), size: size, textScale: scale);
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() => initTestStorage('stay_live_edit_test'));
  setUp(OwnerCache.clearAll);
  tearDown(resetOwnerTestState);

  testWidgets('o_st_16_liveStay_opensWithStripAndTags', (t) async {
    _setup();
    await _pump(t, size: const Size(360, 1200));
    for (final s in ['Basic Details', 'Your stay is live', 'Name, registration and location changes go for review. Your stay stays live meanwhile.', 'Stay Name', 'Stay Type', 'Facilities', 'Registration number', 'Location', 'Price, photos, rooms and rules change right away.', 'Save changes']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('Deodar Heights Homestay'), findsOneWidget);
    expect(find.text('UDYAM-UK-05-0001234'), findsOneWidget);
    expect(find.text('Sargakhet, Mukteshwar'), findsOneWidget);
  });

  testWidgets('o_st_16_reviewFieldsHaveGoesForReviewTag_otherFieldsNot', (t) async {
    _setup();
    await _pump(t, size: const Size(360, 1200));
    expect(find.text('Goes for review'), findsNWidgets(3));
  });

  testWidgets('o_st_16_saveAtOnceFieldsDoNotTouchPending_saveCallsBasicOnce', (t) async {
    _setup();
    await _pump(t, size: const Size(360, 1200));
    await t.tap(find.text('Save changes'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    final repo = FakeStayRepo.last!;
    expect(repo.calls, ['basic']);
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('o_st_16_notApprovedCannotOpen', (t) async {
    _setup(status: 'PendingReview');
    await t.pumpWidget(const SizedBox.shrink());
    await pumpPhone(t, Builder(builder: (c) => Scaffold(body: TextButton(onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => StayLiveEditScreen(setup: Get.find<StaySetupController>()))), child: const Text('open')))));
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Save changes'), findsNothing);
  });

  testOwnerSizes('live edit', () => StayLiveEditScreen(setup: Get.find<StaySetupController>()), setUpEach: _setup, arrange: (t) async {
    await t.pump(const Duration(milliseconds: 200));
  });
}
