import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_render.dart';
import '../../../support/real_phone.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool isActive(String tabKey) {
    version.value;
    return true;
  }
}

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void _setUp({ShellKind kind = ShellKind.stayOwner, bool payment = true, String role = 'STAY_OWNER'}) {
  Get.reset();
  Get.put<TabConfigController>(_Tabs());
  final a = Get.put<AuthController>(_Auth());
  a.roleKey.value = role;
  a.canListStays.value = role == 'STAY_OWNER';
  a.shellKind.value = kind;
  a.profileName.value = 'Meena Bisht';
  a.profilePhone.value = '9897012345';
  Get.put(PlanController()).myPlan.value = MyPlanModel(paymentEnabled: payment);
}

List<String> _activity(WidgetTester t) {
  const labels = ['Plan a trip', 'My Trips', 'Jobs', 'My Journeys', 'My Reports'];
  final found = <MapEntry<String, double>>[];
  for (final l in labels) {
    final f = find.text(l);
    if (f.evaluate().isNotEmpty) found.add(MapEntry(l, t.getTopLeft(f.first).dy));
  }
  found.sort((a, b) => a.value.compareTo(b.value));
  return [for (final e in found) e.key];
}

void main() {
  setUpAll(loadRealFonts);
  tearDown(Get.reset);

  testWidgets('o_st_23 stay owner ACTIVITY: only My Reports, no traveller rows, no Jobs feed row', (t) async {
    _setUp();
    await pumpPhone(t, const ProfileScreen(), size: const Size(392, 2400));
    await settlePhone(t);
    expect(_activity(t), ['My Reports']);
    expect(find.text('Travel as a guest'), findsNothing);
  });

  testWidgets('o_st_23 seeker shell keeps the Jobs feed row and has no Plan a trip row', (t) async {
    _setUp(kind: ShellKind.seeker, role: 'SEEKER');
    await pumpPhone(t, const ProfileScreen(), size: const Size(392, 2400));
    await settlePhone(t);
    expect(_activity(t), isNot(contains('Plan a trip')));
    expect(_activity(t), contains('Jobs'));
  });

  testWidgets('render o_st_23', (t) async {
    _setUp();
    await renderOwnerFrame(t, 'o_st_23', const ProfileScreen());
  });
}
