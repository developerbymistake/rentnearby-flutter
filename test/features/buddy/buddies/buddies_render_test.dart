import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/buddy/buddies/controllers/buddy_summary_controller.dart';
import 'package:bakhli/features/buddy/buddies/models/buddy_models.dart';
import 'package:bakhli/features/buddy/buddies/screens/blocked_people_screen.dart';
import 'package:bakhli/features/buddy/buddies/widgets/block_dialog.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_snack.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'buddies_fakes.dart';

late FakeBuddiesApi api;

Future<void> step(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapText(WidgetTester t, String s) async {
  await t.tap(find.text(s).last);
  await step(t);
}

Future<void> render(WidgetTester t, String id, Widget w, {Future<void> Function(WidgetTester)? arrange}) async {
  final file = await renderFrame(t, id, w, arrange: arrange);
  expect(t.takeException(), isNull);
  expect(file.existsSync(), isTrue);
  await t.pump(const Duration(seconds: 6));
  BuddySnack.hide();
  await t.pump(const Duration(seconds: 1));
}

Widget blockHost(BuddyPerson p) => Scaffold(
      body: Builder(
        builder: (c) => Center(
          child: TextButton(onPressed: () => BlockDialog.show(c, person: p, contextName: BuddyContext.buddy, api: api), child: const Text('open')),
        ),
      ),
    );

void summary(BuddySummary s) {
  Get.put(BuddySummaryController(api: api..summaryResult = BuddyOk(s)), permanent: true);
}

void main() {
  useBuddyRenderScale();

  setUp(() {
    Get.reset();
    api = FakeBuddiesApi();
    putMe();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  testWidgets('1.4', (t) async {
    api.blocksResult = BuddyOk(BlockedList(items: [BlockedPerson(userId: vikasId, name: 'Vikas', username: 'Bakhli#83720518', initial: 'V', blockedAt: DateTime(2026, 11, 12, 10))], count: 1));
    await render(t, '1.4', BlockedPeopleScreen(api: api));
  });

  testWidgets('2.11', (t) async {
    await render(t, '2.11', blockHost(vikas), arrange: (t) async {
      await tapText(t, 'open');
      await tapText(t, 'Also report');
    });
  });

  testWidgets('2.11a', (t) async {
    api.blockContextResult = const BuddyOk(BlockContext(tripsInCommon: [TripInCommon(tripId: 't', title: 'Uttarakhand Hills Trip', myRole: 'Owner')]));
    await render(t, '2.11a', blockHost(vikas), arrange: (t) => tapText(t, 'open'));
  });

  testWidgets('2.11b', (t) async {
    final a = Get.find<AuthController>();
    a.profileName.value = 'Aman';
    a.user.value = UserModel(id: amanId, phoneNumber: '9', isPhoneVerified: true, name: 'Aman', username: 'Bakhli#61408275', createdAt: DateTime(2026), roleConfirmed: true);
    api.blockContextResult = const BuddyOk(BlockContext(tripsInCommon: [TripInCommon(tripId: 't', title: 'Uttarakhand Hills Trip', myRole: 'Viewer')]));
    await render(t, '2.11b', blockHost(rahul), arrange: (t) => tapText(t, 'open'));
  });

  testWidgets('1.2 Profile Buddies row', (t) async {
    final p = Get.put(PlanController());
    p.myPlan.value = MyPlanModel(paymentEnabled: false);
    final a = Get.find<AuthController>();
    a.profileName.value = 'Rahul Mehra';
    a.profilePhone.value = '9876543210';
    a.profilePhoneVerified.value = true;
    summary(const BuddySummary(receivedPending: 1, buddies: 2));
    await render(t, '1.2', const ProfileScreen());
  });
}
