import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../config/app_constants.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are shown automatically by FCM on Android.
}

class NotificationService extends GetxService {
  static NotificationService get to => Get.find();

  StreamSubscription? _messageOpenedSub;
  StreamSubscription? _tokenRefreshSub;

  // Tab indexes matching main_screen.dart tab order
  static const int _tabExplore    = 0;
  static const int _tabMyListings = 1;
  static const int _tabMyPlots    = 3;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initFirebase();
  }

  Future<void> _initFirebase() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Notification tap handlers — always active regardless of login state
    _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);

    // Token refresh listener — only registers if logged in
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (StorageService.isLoggedIn) await _registerToken(token);
      // Defensive re-subscribe — cheap no-op if already subscribed, guards against
      // any FCM-side token/topic association edge cases after a token refresh.
      final topic = StorageService.getSubscribedDistrictTopic();
      if (topic != null) {
        try {
          await FirebaseMessaging.instance.subscribeToTopic(topic);
        } catch (_) {}
      }
    });

    // Returning user: permission already granted — silently register token
    // Permission is NOT requested here. It is requested only after login (registerTokenAfterLogin)
    // so the user has context before seeing the system dialog.
    if (StorageService.isLoggedIn) {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await _registerToken(token);
      }
    }
  }

  // Screens pushed ON TOP of main screen — main is underneath in the stack
  static const _routesOnTopOfMain = {
    AppRoutes.listingDetail,
    AppRoutes.plotDetail,
    AppRoutes.addListing,
    AppRoutes.addPlot,
    AppRoutes.paymentScreen,
  };

  void _handleNotificationTap(RemoteMessage message) {
    if (!StorageService.isLoggedIn) return;

    final membershipType = message.data['membership_type'];
    final tabIndex = membershipType == 'plot'
        ? _tabMyPlots
        : membershipType == 'broadcast'
            ? _tabExplore
            : _tabMyListings;
    final currentRoute = Get.currentRoute;

    if (currentRoute == AppRoutes.main) {
      // Already on main screen — just switch tab, IndexedStack handles it, no rebuild
      Get.find<AuthController>().tabIndex.value = tabIndex;
    } else if (_routesOnTopOfMain.contains(currentRoute)) {
      // Detail/add screens are on top of main — main screen is alive underneath
      // Pop back to main WITHOUT recreating it (IndexedStack state preserved)
      Get.until((route) => route.settings.name == AppRoutes.main);
      Get.find<AuthController>().tabIndex.value = tabIndex;
    } else {
      // Main screen is NOT in stack: terminated app, login, splash, onboarding
      // Navigate fresh — double postFrameCallback waits for MainScreen.initState()
      Get.offAllNamed(AppRoutes.main);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (Get.isRegistered<AuthController>()) {
            Get.find<AuthController>().tabIndex.value = tabIndex;
          }
        });
      });
    }
  }

  Future<void> _registerToken(String token) async {
    final stored = StorageService.getFcmToken();
    if (stored == token) return;

    try {
      await ApiService.post(AppConstants.registerTokenPath, {'token': token});
      await StorageService.saveFcmToken(token);
    } catch (e) {
      debugPrint('NotificationService: token registration failed: $e');
    }
  }

  Future<void> registerTokenAfterLogin() async {
    // Delay so location permission dialog (shown by LocationController on main screen open)
    // completes first — prevents two system dialogs overlapping on Android 13+.
    await Future.delayed(const Duration(seconds: 3));

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerToken(token);
  }

  Future<void> clearToken() async {
    StorageService.clearFcmToken();
    try {
      await ApiService.delete(AppConstants.registerTokenPath);
    } catch (_) {}
  }

  /// Returns true if user should be prompted to re-enable notifications:
  /// - Previously had notifications (stored token exists)
  /// - Current permission is denied
  /// - Has not dismissed the prompt in the last 24 hours
  Future<bool> shouldShowPermissionPrompt() async {
    if (StorageService.getFcmToken() == null) return false;

    final lastDismissed = StorageService.getNotifPromptDismissedAt();
    if (lastDismissed != null) {
      final hoursSince = DateTime.now().difference(lastDismissed).inHours;
      if (hoursSince < 24) return false;
    }

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.denied;
  }

  void onPermissionPromptDismissed() =>
      StorageService.saveNotifPromptDismissedAt();

  /// Subscribes to the FCM topic for [districtId] (`district_<id>`), unsubscribing
  /// from the previously-subscribed district topic first if it changed.
  /// Pass null to unsubscribe without subscribing to a new one.
  Future<void> updateDistrictTopic(String? districtId) async {
    final previous = StorageService.getSubscribedDistrictTopic();
    final next = districtId == null
        ? null
        : '${AppConstants.districtTopicPrefix}$districtId';
    if (previous == next) return;

    if (previous != null) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(previous);
      } catch (e) {
        debugPrint('NotificationService: unsubscribe from $previous failed: $e');
      }
    }

    if (next != null) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic(next);
        await StorageService.saveSubscribedDistrictTopic(next);
        return;
      } catch (e) {
        debugPrint('NotificationService: subscribe to $next failed: $e');
        return; // leave stored topic as-is — retried on next district-change event
      }
    }

    StorageService.clearSubscribedDistrictTopic();
  }

  /// Unsubscribes from the currently-subscribed district topic, if any. Call on logout.
  Future<void> clearDistrictTopic() async {
    final topic = StorageService.getSubscribedDistrictTopic();
    if (topic == null) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (_) {}
    StorageService.clearSubscribedDistrictTopic();
  }

  @override
  void onClose() {
    _messageOpenedSub?.cancel();
    _tokenRefreshSub?.cancel();
    super.onClose();
  }
}
