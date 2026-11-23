import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tour_controller.dart';
import 'package:bakhli/features/trip/controllers/my_trips_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/screens/trips_discovery_screen.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/navigation/tab_keys.dart';
import 'package:bakhli/services/tour_dismiss_observer.dart';
import 'package:bakhli/widgets/tour_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../ui_golden/golden_support.dart';

class TourAuth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class TourLoc extends LocationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Catalog extends TripCityCatalog {
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => true;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async => const [];
}

class _Trips extends MyTripsController {
  @override
  Future<void> ensureLoaded() async {}
  @override
  Future<void> load({bool refresh = false}) async {}
  @override
  Future<void> refreshIfStale() async {}
}

const harnessRoot = ValueKey('tour-harness-root');

Future<void> initTourStorage() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    return Directory.systemTemp.createTempSync('tour_gs').path;
  });
  await GetStorage.init();
  await loadGoldenFonts();
}

Future<void> eraseTourStorage() async {
  await GetStorage().erase();
}

UserModel tourUser() => UserModel(id: 'u1', phoneNumber: '9876543210', isPhoneVerified: true, name: 'Asha', createdAt: DateTime(2026), roleConfirmed: true);

class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      final seeker = auth.shellKind.value == ShellKind.seeker;
      return IndexedStack(
        index: auth.tabIndex.value,
        children: [
          for (var i = 0; i < AppTabs.count; i++)
            Navigator(
              key: tabKeys[i],
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => i == AppTabs.trips && seeker
                    ? const TripsDiscoveryScreen()
                    : Scaffold(body: Center(child: Text('tab $i'))),
              ),
            ),
        ],
      );
    });
  }
}

class TourHarness {
  TourHarness(this.auth, this.loc);
  final TourAuth auth;
  final TourLoc loc;

  TourController get ctrl => Get.find<TourController>();

  // In the app the controller is put inside MainScreen.initState, so a frame always follows.
  void startController() {
    Get.put(TourController());
    WidgetsBinding.instance.scheduleFrame();
  }

  void restartController() {
    Get.delete<TourController>(force: true);
    startController();
  }
}

Future<TourHarness> pumpTourHarness(
  WidgetTester t, {
  Size size = const Size(360, 800),
  double scale = 1.0,
  int tab = AppTabs.home,
  ShellKind shell = ShellKind.seeker,
  bool disableAnimations = false,
  bool startController = true,
}) async {
  setGoldenView(t, size);
  final auth = TourAuth();
  auth.user.value = tourUser();
  auth.shellKind.value = shell;
  auth.tabIndex.value = tab;
  final loc = TourLoc();
  Get.put<AuthController>(auth, permanent: true);
  Get.put<LocationController>(loc, permanent: true);
  Get.put<TripCityCatalog>(_Catalog(), permanent: true);
  Get.put<MyTripsController>(_Trips(), permanent: true);
  await t.pumpWidget(GetMaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(fontFamily: 'Poppins'),
    initialRoute: AppRoutes.main,
    navigatorObservers: [TourDismissObserver()],
    getPages: [
      GetPage(name: AppRoutes.main, page: () => const _Shell()),
      GetPage(name: AppRoutes.notifications, page: () => const Scaffold(body: Text('pushed page'))),
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        textScaler: TextScaler.linear(scale),
        disableAnimations: disableAnimations,
      ),
      child: RepaintBoundary(
        key: harnessRoot,
        child: Stack(children: [child!, const TourHost()]),
      ),
    ),
  ));
  await t.pump();
  await t.runAsync(() async {
    for (final e in find.byType(Image, skipOffstage: false).evaluate().toList()) {
      try {
        await precacheImage((e.widget as Image).image, e);
      } catch (_) {}
    }
  });
  await t.pump(const Duration(milliseconds: 400));
  final h = TourHarness(auth, loc);
  if (startController) h.startController();
  return h;
}

Future<void> advance(WidgetTester t, Duration total) async {
  const step = Duration(milliseconds: 100);
  var left = total;
  while (left > Duration.zero) {
    await t.pump(left < step ? left : step);
    left -= step;
  }
}
