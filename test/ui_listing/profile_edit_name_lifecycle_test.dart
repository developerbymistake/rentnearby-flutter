import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter/material.dart';
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

void _setup() {
  final a = _Auth();
  Get.put<AuthController>(a);
  Get.put<TabConfigController>(_Tabs());
  final p = Get.put(PlanController());
  a.profileName.value = 'Rahul Sharma';
  a.profilePhone.value = '9876543210';
  p.myPlan.value = MyPlanModel(paymentEnabled: false);
}

Future<void> _open(WidgetTester t) async {
  _setup();
  await pumpPhone(t, const ProfileScreen());
  await settlePhone(t);
  await t.tap(find.bySemanticsLabel('Edit name'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  expect(find.text('Enter your full name'), findsOneWidget);
}

void main() {
  setUpAll(loadRealFonts);
  tearDown(Get.reset);

  for (final how in ['Cancel', 'barrier', 'typing then Cancel']) {
    testWidgets('edit name sheet closes by $how without a disposed controller error', (t) async {
      await _open(t);
      if (how.startsWith('typing')) {
        await t.enterText(find.byType(TextFormField), 'Rahul S');
        await t.pump();
        expect(find.text('Rahul S'), findsOneWidget);
      }
      if (how == 'barrier') {
        await t.tapAt(const Offset(180, 60));
      } else {
        await t.tap(find.bySemanticsLabel('Cancel'));
      }
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 16));
        expect(t.takeException(), isNull, reason: 'frame $i while the sheet animates out');
      }
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Enter your full name'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('delete account dialog closes without a disposed controller error', (t) async {
    _setup();
    await pumpPhone(t, const ProfileScreen());
    await settlePhone(t);
    final del = find.text('Delete Account');
    await t.scrollUntilVisible(del, 300, scrollable: find.byType(Scrollable).first);
    await t.tap(del);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.enterText(find.byType(TextField), 'DEL');
    await t.pump();
    await t.tap(find.bySemanticsLabel('Cancel'));
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 16));
      expect(t.takeException(), isNull, reason: 'frame $i while the dialog animates out');
    }
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Type DELETE to confirm'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('edit name sheet keeps the typed name and Save stays off for blank', (t) async {
    await _open(t);
    await t.enterText(find.byType(TextFormField), '   ');
    await t.pump();
    await t.tap(find.bySemanticsLabel('Save'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Enter your full name'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Cancel'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
  });
}
