import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../ui_golden/golden_support.dart';

const journeyWidths = [300.0, 360.0, 412.0, 560.0];
const journeyScales = [1.0, 2.0];

class JLoc extends LocationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class JAuth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool get staysEnabled {
    user.value;
    return false;
  }
  @override
  bool get jobsEnabled {
    user.value;
    return false;
  }
  @override
  bool get taxisEnabled {
    user.value;
    return false;
  }
}

class JTabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

Future<void> flush(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> pumpJourney(WidgetTester t, Widget screen, {required double width, required double scale, double height = 2600}) async {
  setGoldenView(t, Size(width, height));
  await t.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'WorkSans'),
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height), textScaler: TextScaler.linear(scale)),
      child: screen,
    ),
  ));
  await t.pump(const Duration(milliseconds: 700));
  await t.pump(const Duration(milliseconds: 700));
}
