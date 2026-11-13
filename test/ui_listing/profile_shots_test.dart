import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/real_phone.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool get jobsBrowseEnabled {
    user.value;
    return true;
  }

  @override
  bool get taxisEnabled {
    user.value;
    return true;
  }
}

_Auth _setup({String name = 'Rahul Sharma', bool owner = false, bool payment = false, bool verified = true}) {
  final a = _Auth();
  Get.put<AuthController>(a);
  Get.put<TabConfigController>(_Tabs());
  final p = Get.put(PlanController());
  a.profileName.value = name;
  a.profilePhone.value = '9876543210';
  a.profilePhoneVerified.value = verified;
  if (owner) {
    a.canListStays.value = true;
    a.roleKey.value = 'STAY_OWNER';
  }
  p.myPlan.value = MyPlanModel(paymentEnabled: payment);
  return a;
}

void main() {
  setUpAll(() {
    loadRealFonts();
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\profile';
  });
  tearDown(Get.reset);

  Future<void> run(WidgetTester t, String name, {Size size = const Size(390, 844), double scale = 1.0, Future<void> Function()? after}) async {
    debugDisableShadows = false;
    await pumpPhone(t, const ProfileScreen(), size: size, textScale: scale);
    await settlePhone(t);
    await shot(t, '${name}_y0');
    await scrollShots(t, find.byType(ProfileScreen), name, [500, 1400]);
    if (after != null) await after();
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  }

  testWidgets('owner with payment 390', (t) async {
    _setup(owner: true, payment: true);
    await run(t, 'owner_390');
  });

  testWidgets('seeker 360', (t) async {
    _setup();
    await run(t, 'seeker_360', size: phoneSize);
  });

  testWidgets('owner 360 x1.3 not verified', (t) async {
    _setup(owner: true, payment: true, verified: false);
    await run(t, 'owner_360_s13', size: phoneSize, scale: 1.3);
  });

  testWidgets('long name 300 no name avatar', (t) async {
    _setup(name: 'Venkatanarasimha Raghavendra Subramaniam', owner: true);
    await run(t, 'long_300', size: const Size(300, 700));
  });

  testWidgets('empty name 360', (t) async {
    _setup(name: '');
    await run(t, 'empty_name_360', size: phoneSize);
  });

  Future<void> sheet(WidgetTester t, String name, Future<void> Function() open, {double scale = 1.0, bool owner = true}) async {
    _setup(owner: owner, payment: true);
    debugDisableShadows = false;
    await pumpPhone(t, const ProfileScreen(), size: phoneSize, textScale: scale);
    await settlePhone(t);
    await open();
    await t.pump(const Duration(milliseconds: 600));
    await settlePhone(t);
    await shot(t, name);
    expect(t.takeException(), isNull);
    debugDisableShadows = true;
  }

  testWidgets('edit name sheet', (t) => sheet(t, 'sheet_edit_name', () async {
        await t.tap(find.bySemanticsLabel('Edit name'));
      }));

  testWidgets('logout sheet', (t) => sheet(t, 'sheet_logout', () async {
        final logout = find.bySemanticsLabel('Logout');
        await t.scrollUntilVisible(logout, 300, scrollable: find.byType(Scrollable).first);
        await t.tap(logout);
      }));

  testWidgets('delete sheet x1.3', (t) => sheet(t, 'sheet_delete_s13', scale: 1.3, () async {
        final del = find.text('Delete Account');
        await t.scrollUntilVisible(del, 300, scrollable: find.byType(Scrollable).first);
        await t.tap(del);
      }));

  testWidgets('visibility sheet x1.3', (t) => sheet(t, 'sheet_visibility_s13', scale: 1.3, owner: false, () async {
        await t.tap(find.byType(CupertinoSwitch));
      }));
}
