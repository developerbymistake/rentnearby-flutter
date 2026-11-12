import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../config/app_constants.dart';
import '../config/app_routes.dart';
import '../controllers/app_version_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/tab_config_controller.dart';
import '../design/design.dart';
import '../services/storage_service.dart';
import '../utils/update_decision.dart';
import 'splash/splash_hero.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with WidgetsBindingObserver {
  static const _minSplash = Duration(milliseconds: 1500);
  static const _minSplashReduced = Duration(milliseconds: 1000);
  bool _waitingForSettings = false;
  Worker? _updateGateWorker;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.removeObserver(this);
    _updateGateWorker?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _navigate();
    }
  }

  Future<void> _start() async {
    await Future.wait([
      Future.delayed(WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations
          ? _minSplashReduced : _minSplash),
      AppVersionController.to.initialCheck
          .timeout(AppConstants.appVersionSplashWait, onTimeout: () {})
          .catchError((_) {}),
      TabConfigController.to.ready
          .timeout(AppConstants.appVersionSplashWait, onTimeout: () {})
          .catchError((_) {}),
    ]);
    if (!mounted) return;
    _navigate();
  }

  bool _parkWhileForced() {
    final versionCtrl = AppVersionController.to;
    if (versionCtrl.gate.value != UpdateGateState.force) return false;
    _updateGateWorker ??= ever<UpdateGateState>(versionCtrl.gate, (state) {
      if (state == UpdateGateState.force) return;
      _updateGateWorker?.dispose();
      _updateGateWorker = null;
      if (mounted && !_waitingForSettings) _navigate();
    });
    return true;
  }

  Future<void> _navigate() async {
    while (true) {
      if (_parkWhileForced()) return;
      final granted = await _ensureLocationPermission();
      if (!mounted) return;
      if (_waitingForSettings) return;
      if (granted) break;
    }

    if (!mounted) return;
    if (_parkWhileForced()) return;

    if (StorageService.isLoggedIn) {
      final auth = Get.find<AuthController>();
      if (auth.hasPendingSetup && !TabConfigController.to.loaded.value) {
        // Setup vs main must not be decided from a stale persisted tab seed.
        await TabConfigController.to.load()
            .timeout(AppConstants.appVersionSplashWait, onTimeout: () {})
            .catchError((_) {});
        if (!mounted) return;
      }
      Get.offAllNamed(auth.postLoginRoute);
    } else if (!StorageService.getTourSeen(AppConstants.introCarouselSeenKey)) {
      Get.offAllNamed(AppRoutes.intro);
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (_isGranted(permission)) return true;

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (_isGranted(permission)) return true;
    }

    // If requestPermission() returned denied again, Android won't re-show
    // the system dialog — treat as deniedForever and direct user to settings
    if (permission == LocationPermission.denied) {
      permission = LocationPermission.deniedForever;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: GateDialog(
            asset: TravelIcon.place,
            title: 'Location Access Required',
            body: 'This app helps you discover stays, taxis and trips near you. '
                'Location access is essential for the app to function. '
                'Please enable it to continue.',
            actions: [
              GateButton(
                label: 'Allow Location',
                height: 48,
                onPressed: () {
                  Navigator.pop(context);
                  _waitingForSettings = true;
                  Geolocator.openAppSettings();
                },
              ),
            ],
          ),
        ),
      );
      return false;
    }

    return false;
  }

  bool _isGranted(LocationPermission p) =>
      p == LocationPermission.whileInUse || p == LocationPermission.always;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: DesignColors.dinnerEnd,
      body: SplashHero(),
    );
  }
}
