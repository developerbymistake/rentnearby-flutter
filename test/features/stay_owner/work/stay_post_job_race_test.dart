import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/jobs/controllers/post_job_controller.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../journeys/fake_api.dart';

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Plan extends PlanController {
  int invalidated = 0;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> invalidate() async {
    invalidated++;
  }
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

_Plan _setUp(List<FakeRoute> extra) {
  Get.reset();
  Get.put<AuthController>(_Auth()).user.value = UserModel.fromJson({'id': 'u1', 'phoneNumber': '+919897012345', 'createdAt': '2026-01-01T00:00:00Z'});
  final plan = Get.put<PlanController>(_Plan()) as _Plan;
  installFakeApi([
    FakeRoute.value('GET', '/stay-jobs/lookups', _lookups),
    FakeRoute.value('GET', '/stay-jobs/me', {'items': [], 'activeCount': 0, 'maxActive': 1, 'stayStatus': 'Approved', 'canPost': true}),
    FakeRoute.value('GET', '/stay-jobs/me/{id}', {
      'id': 'j1', 'title': 'Cook', 'description': 'Cook for the stay kitchen.', 'jobDepartmentId': 'd0', 'jobRoleId': 'r0',
      'jobTypeId': 't0', 'jobShiftTypeId': 's0', 'jobSalaryTypeId': 'm0', 'minimumExperienceYears': 1, 'minSalary': 15000,
      'maxSalary': 20000, 'contactPhone': '9897012345', 'whatsAppNumber': '9897012345', 'foodAndStay': false, 'status': 'Active',
    }),
    ...extra,
  ]);
  return plan;
}

void _fill(PostJobController c) {
  c.titleCtrl.text = 'Cook';
  c.descCtrl.text = 'Cook for the stay kitchen.';
  c.departmentId.value = 'd0';
  c.roleId.value = 'r0';
  c.salaryTypeId.value = 'm0';
  c.minSalaryCtrl.text = '15000';
  c.maxSalaryCtrl.text = '20000';
  c.minExperienceYears.value = 1;
  c.jobTypeId.value = 't0';
  c.shiftTypeId.value = 's0';
}

void main() {
  tearDown(Get.reset);

  testWidgets('L15 a racing StayJobLimit keeps the refusal limit and canUpgrade for the Plus sheet', (t) async {
    _setUp([
      FakeRoute.value('POST', '/stay-jobs/me', {'key': 'JobsPosts', 'limit': 1, 'used': 1, 'canUpgrade': true, 'active': 1},
          code: 409, errorType: 'StayJobLimit'),
    ]);
    final c = (await t.runAsync(() async => Get.put(PostJobController())))!;
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    expect(c.canUpgrade.value, isFalse);
    _fill(c);
    final ok = await t.runAsync(c.submit);
    expect(ok, isFalse);
    expect(c.limitReached.value, isTrue);
    expect(c.canUpgrade.value, isTrue);
    expect(c.limitFree, 1);
    expect(c.blockMessage.value, isNotNull);
  });

  testWidgets('L15 a job that went inactive while editing refreshes the plan and does not set a block', (t) async {
    final plan = _setUp([
      FakeRoute.value('PUT', '/stay-jobs/me/{id}', null, code: 409, errorType: 'PlanRowInactive'),
    ]);
    final c = (await t.runAsync(() async => Get.put(PostJobController(editId: 'j1'))))!;
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    final ok = await t.runAsync(c.submit);
    expect(ok, isFalse);
    expect(plan.invalidated, 1);
    expect(c.blockMessage.value, isNull);
    expect(c.limitReached.value, isFalse);
  });
}
