import 'package:bakhli/screens/home_screen.dart';
import 'package:bakhli/widgets/global_location_gates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/models/user_model.dart';

import '../../support/owner_fakes.dart';
import '../../support/owner_render.dart';
import 'seeker_home_harness.dart';

void main() {
  setUpAll(() async => initTestStorage('seeker_gates'));
  tearDown(Get.reset);
  useOwnerRenderScale();

  Widget gates() => const GlobalLocationGates(child: Scaffold(body: SizedBox.expand()));

  testWidgets('o_sk_7_existingGateRendersOnceForRecord', (t) async {
    registerHome(feed: fixtureNoTrip());
    Get.find<AuthController>().user.value = UserModel(id: 'user-a', phoneNumber: '9000000000', createdAt: DateTime(2026), role: 'SEEKER', roleConfirmed: true);
    Get.find<LocationController>().isOffline.value = true;
    GlobalLocationGates.notifyReady();
    await renderOwnerFrame(t, 'o_sk_7', gates());
    expect(find.text('No Internet'), findsOneWidget);
    expect(find.text("Please check your internet connection. App will resume automatically when you're back online."), findsOneWidget);
    expect(find.text('Open my trips (offline copy)'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('o_sk_8_existingGateRendersOnceForRecord', (t) async {
    registerHome(feed: fixtureNoTrip());
    final loc = Get.find<LocationController>();
    loc.isOffline.value = false;
    loc.gpsEnabled.value = false;
    GlobalLocationGates.notifyReady();
    await renderOwnerFrame(t, 'o_sk_8', gates());
    expect(find.text('Location Required'), findsOneWidget);
    expect(find.text('Enable Location'), findsOneWidget);
    expect(find.text('Check Again'), findsOneWidget);
  });
}
