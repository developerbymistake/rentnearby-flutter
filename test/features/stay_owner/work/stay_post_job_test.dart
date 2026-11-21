import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/jobs/controllers/post_job_controller.dart';
import 'package:bakhli/features/jobs/screens/post_job_screen.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../journeys/fake_api.dart';
import '../../../support/owner_render.dart';
import '../../../support/owner_sizes.dart';
import '../../../support/real_phone.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Plan extends PlanController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

final _lookups = {
  'departments': [
    {'id': 'd0', 'name': 'Kitchen'},
  ],
  'roles': [
    {'id': 'r0', 'name': 'Cook', 'jobDepartmentId': 'd0'},
  ],
  'jobTypes': [
    {'id': 't0', 'name': 'Full time'},
  ],
  'shiftTypes': [
    {'id': 's0', 'name': 'Day Shift'},
  ],
  'salaryTypes': [
    {'id': 'm0', 'name': 'Monthly'},
  ],
};

FakeTripAdapter _setUp() {
  Get.reset();
  Get.put<TabConfigController>(_Tabs());
  Get.put<AuthController>(_Auth()).user.value = UserModel.fromJson({'id': 'u1', 'phoneNumber': '+919897012345', 'createdAt': '2026-01-01T00:00:00Z'});
  Get.put<PlanController>(_Plan());
  return installFakeApi([
    FakeRoute.value('GET', '/stay-jobs/lookups', _lookups),
    FakeRoute.value('GET', '/stay-jobs/me', {'items': [], 'activeCount': 0, 'maxActive': 1, 'stayStatus': 'Approved', 'canPost': true}),
  ]);
}

Future<void> _load(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _toPay(WidgetTester t) async {
  await _load(t);
  final c = Get.find<PostJobController>();
  c.salaryTypeId.value = 'm0';
  c.minSalaryCtrl.text = '14000';
  c.maxSalaryCtrl.text = '14000';
  c.minExperienceYears.value = 2;
  c.foodAndStay.value = true;
  c.step.value = 1;
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(loadRealFonts);
  tearDown(Get.reset);

  testWidgets('o_st_69_a step 2 shows header line, Next, food and stay toggle and the bounds hint', (t) async {
    _setUp();
    await pumpPhone(t, const PostJobScreen(), size: const Size(392, 1400));
    await _toPay(t);
    expect(find.text('Post a job'), findsOneWidget);
    expect(find.text('Step 2 of 3 · Pay and experience'), findsOneWidget);
    expect(find.text('Food and stay given'), findsOneWidget);
    expect(find.text('Shown on the job card'), findsOneWidget);
    expect(find.text('Salary ₹100 to ₹99,00,000. Experience 0 to 20 years.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('o_st_69_a toggle flips foodAndStay', (t) async {
    _setUp();
    await pumpPhone(t, const PostJobScreen(), size: const Size(392, 1400));
    await _toPay(t);
    final c = Get.find<PostJobController>();
    c.foodAndStay.value = false;
    await t.pump();
    await t.tap(find.byKey(const ValueKey('job_food_and_stay')));
    await t.pump();
    expect(c.foodAndStay.value, isTrue);
  });

  testOwnerSizes('o_st_69_a post job step 2', () => const PostJobScreen(), setUpEach: _setUp, arrange: _toPay);

  testWidgets('render o_st_69_a', (t) async {
    _setUp();
    await renderOwnerFrame(t, 'o_st_69', const PostJobScreen(), part: 'A', arrange: _toPay);
  });
}
