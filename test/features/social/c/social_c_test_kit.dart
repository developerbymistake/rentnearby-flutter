import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/real_phone.dart';

const List<double> socialWidths = [360, 411];
const List<double> socialScales = [1.0, 1.3];

Future<void> pumpSocial(WidgetTester t, Widget child, {double width = 360, double scale = 1.0, List<GetPage<dynamic>>? pages}) async {
  await pumpPhone(t, child, size: Size(width, 800), textScale: scale, toastHost: true, pages: pages);
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> disposeSocial(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 5));
}
