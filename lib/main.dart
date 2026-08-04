import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:toastification/toastification.dart';
import 'config/app_theme.dart';
import 'config/app_routes.dart';
import 'controllers/auth_controller.dart';
import 'services/api_service.dart';
import 'services/deep_link_service.dart';
import 'services/map_pause_observer.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/tour_dismiss_observer.dart';
import 'widgets/global_location_gates.dart';
import 'widgets/tour_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await StorageService.init();
  ApiService.init();
  await Firebase.initializeApp();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));
  // Empty list = no restriction (Android 16+ ignores orientation locks on large
  // screens anyway; this app has no responsive/tablet layouts yet, so landscape
  // will render at phone-like proportions rather than a tailored layout).
  SystemChrome.setPreferredOrientations([]);

  Get.put(NotificationService(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(DeepLinkService(), permanent: true);
  unawaited(DeepLinkService.to.init());

  runApp(const BakhliApp());
}

class BakhliApp extends StatelessWidget {
  const BakhliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Bakhli',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.routes,
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      navigatorObservers: [MapPauseObserver(), TourDismissObserver()],
      builder: (context, child) => ToastificationWrapper(
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: GlobalLocationGates(
            child: Stack(
              children: [
                Positioned.fill(child: child!),
                const TourHost(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
