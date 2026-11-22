import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart' show CachedNetworkImageProvider;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:get/get.dart';
import '../models/role_model.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../config/app_routes.dart';
import '../config/app_tabs.dart';
import '../config/tab_shell.dart';
import '../config/user_roles.dart';
import 'tab_config_controller.dart';
import 'home_controller.dart';
import 'location_controller.dart';
import '../utils/account_delete_message.dart';
import '../utils/app_toast.dart';
import '../utils/jwt_claims.dart';
import '../services/hub_session_manager.dart';
import '../features/stay/setup/stay_setup_controller.dart';
import '../features/taxi/setup/taxi_setup_controller.dart';
import '../features/buddy/buddy_session_hooks.dart';
import '../features/owner_core/data/owner_cache.dart';
import '../features/owner_core/plan/plan_bindings.dart';
import '../features/owner_core/session/owner_session_hooks.dart';

/// What triggered a logout — decides whether the server-side revoke call fires and which (if
/// any) toast is shown. Kept as a typed reason rather than booleans so each of the 3 real-world
/// triggers (explicit tap, account deletion, a server-forced 401) is unambiguous at the call site.
enum LogoutReason { explicitLogout, accountDeleted, sessionExpired, roleChanged, accountSuspended }

enum RoleActionResult { success, unavailable, failed }

enum AppPlace { home, stays, trips, taxi, profile }

abstract final class AppPlaces {
  static AppPlace ofTab(int index) => switch (index) {
        AppTabs.stays => AppPlace.stays,
        AppTabs.trips => AppPlace.trips,
        AppTabs.taxi => AppPlace.taxi,
        AppTabs.profile => AppPlace.profile,
        _ => AppPlace.home,
      };
}

class AuthController extends GetxController {
  final isLoading = false.obs;
  // Deliberately separate from isLoading, which is already shared/overloaded
  // across login-OTP send/verify/resend, profile update, and delete-account
  // — piling explicit logout onto that same flag risks some unrelated screen
  // reacting to it. Drives the Profile screen's non-dismissible "Logging
  // out..." overlay and blocks MainScreen's root back-handling while true.
  final isLoggingOut = false.obs;
  final cleaningUp = false.obs;
  final user = Rxn<UserModel>();
  final roleKey = UserRoleKeys.seeker.obs;
  final canListStays = false.obs;
  final canListTaxis = false.obs;
  final tabIndex = AppTabs.home.obs;
  // A tab root is built on its first visit only (FX-06); every tabIndex change counts as a visit.
  final visitedTabs = <int>{AppTabs.home}.obs;

  void markVisited(int index) {
    if (!visitedTabs.contains(index)) visitedTabs.add(index);
  }

  void resetVisitedTabs() {
    visitedTabs.assignAll({AppTabs.home, tabIndex.value});
  }
  final profileTabTrigger = 0.obs;
  final shellKind = ShellKind.seeker.obs;
  final ownerShellEmpty = false.obs;
  final tabIntent = Rxn<TabIntent>();
  int _intentSeq = 0;

  /// Every tabIndex-setting call site (bottom nav tap, Home CTA, deep link, notification tap)
  /// should route through this rather than assigning tabIndex directly — falls back to Home if
  /// the target tab has been admin-deactivated (TabConfigController), so a stale deep link/push
  /// can never land the user on a tab whose entire API surface is now server-rejected.
  /// Home/Profile are always active so they're never redirected.
  void switchToTab(int index) {
    if (!TabShell.isActive(shellKind.value, index)) {
      tabIndex.value = AppTabs.home;
      return;
    }
    tabIndex.value = index;
  }

  void openTab(int index, {Map<String, dynamic>? intent}) {
    if (Get.currentRoute != AppRoutes.main && Get.isRegistered<HomeController>()) {
      Get.until((r) => r.settings.name == AppRoutes.main);
    }
    switchToTab(index);
    if (tabIndex.value != index) return;
    tabIntent.value = TabIntent(index: index, args: intent ?? const {}, seq: ++_intentSeq);
  }

  TabIntent? takeIntent(int index) {
    final i = tabIntent.value;
    if (i == null || i.index != index) return null;
    tabIntent.value = null;
    return i;
  }

  /// [detail]: a detail screen is pushed next, so an owner shell does not push the list first.
  void openPlace(AppPlace place, {bool detail = false}) {
    if (shellKind.value == ShellKind.seeker) {
      switchToTab(switch (place) {
        AppPlace.home => AppTabs.home,
        AppPlace.stays => AppTabs.stays,
        AppPlace.trips => AppTabs.trips,
        AppPlace.taxi => AppTabs.taxi,
        AppPlace.profile => AppTabs.profile,
      });
      return;
    }
    switch (place) {
      case AppPlace.home:
        openTab(AppTabs.home);
      case AppPlace.profile:
        openTab(AppTabs.profile);
      case AppPlace.trips:
        Get.toNamed(AppRoutes.tripWhere);
      case AppPlace.taxi:
        if (!detail && _tabs.isTaxiActive) Get.toNamed(AppRoutes.taxiList);
      case AppPlace.stays:
        break;
    }
  }

  bool get isOwnerShell => shellKind.value != ShellKind.seeker;

  void syncShell() {
    final u = user.value;
    final empty = (u?.listingDeleted ?? false) || OwnerCache.shellEmpty(u?.id);
    ownerShellEmpty.value = empty;
    shellKind.value = TabShell.kindFor(
      roleKey: roleKey.value,
      stayStatus: u?.stayStatus,
      taxiStatus: u?.taxiStatus,
      emptyShell: empty,
    );
    ShellState.current.value = shellKind.value;
  }

  void setOwnerShellEmpty(bool value) {
    OwnerCache.setShellEmpty(user.value?.id, value);
    syncShell();
  }

  // Granular profile observables — each fires only when its specific field changes
  final profileName = ''.obs;
  final profilePhone = ''.obs;
  final profilePhoneVerified = false.obs;
  final profilePhoneChangeLocked = false.obs;
  final signupUsername = RxnString();

  static String? signupUsernameOf(Map<String, dynamic> data) {
    final user = data['user'];
    return UserModel.usernameOf(data['username']) ?? (user is Map ? UserModel.usernameOf(user['username']) : null);
  }

  void _syncProfileFields(UserModel? u) {
    profileName.value = u?.name ?? '';
    profilePhone.value = u?.phoneNumber ?? '';
    profilePhoneVerified.value = u?.isPhoneVerified ?? false;
    profilePhoneChangeLocked.value = u?.hasUsedPhoneChange ?? false;
  }

  bool get isOwner => canListStays.value || canListTaxis.value;

  TabConfigController get _tabs => TabConfigController.to;

  // Effective capabilities = role AND tab; raw canListX stay for role change/profile/contact visibility.
  bool get staysEnabled => canListStays.value && _tabs.isStaysActive;
  bool get taxisEnabled => canListTaxis.value && _tabs.isTaxiActive;
  bool get jobsEnabled => staysEnabled && _tabs.isJobsActive;
  bool get jobsBrowseEnabled => _tabs.isStaysActive && _tabs.isJobsActive;
  bool get effectiveIsOwner => staysEnabled || taxisEnabled;

  bool get roleTabActive {
    final key = UserRoleKeys.tabKeyOf(roleKey.value);
    return key == null || _tabs.isActive(key);
  }

  bool get roleChangeLocked =>
      (user.value?.roleLocked ?? false) ||
      (user.value?.stayStatus == 'Approved' || user.value?.stayStatus == 'PendingReview') ||
      (user.value?.taxiStatus == 'Approved' || user.value?.taxiStatus == 'PendingReview');

  bool canOpenRoute(String route) {
    if (!AppRoutes.isRegistered(route)) return false;
    if (AppRoutes.ownerOnly.contains(route) && !isOwner) return false;
    if (AppRoutes.stayOwnerOnly.contains(route) && !canListStays.value) return false;
    if (AppRoutes.taxiDriverOnly.contains(route) && !canListTaxis.value) return false;
    final tab = TabShell.tabForRoute(shellKind.value, route, null);
    if (tab != null) return TabShell.isActive(shellKind.value, tab);
    if (AppRoutes.stayOwnerNewRoutes.contains(route) || AppRoutes.taxiDriverNewRoutes.contains(route)) return true;
    final tabKey = AppRoutes.tabKeyForRoute(route);
    if (tabKey == null) return true;
    if (tabKey == AppTabKeys.jobs) return _tabs.isJobsActive && _tabs.isStaysActive;
    return _tabs.isActive(tabKey);
  }

  void _syncRoleFromToken(String? token) {
    final key = JwtClaims.role(token) ?? UserRoleKeys.seeker;
    roleKey.value = key;
    final c = RoleCapabilities.of(key);
    canListStays.value = c.canListStays;
    canListTaxis.value = c.canListTaxis;
    syncShell();
  }

  static bool _setupPending(String? status) => status == null || status == 'Draft';

  // Role-only (ignores tab state): true when the tab config alone decides between setup and main.
  bool get hasPendingSetup =>
      (user.value?.roleConfirmed ?? false) &&
      ((canListStays.value && _setupPending(user.value?.stayStatus)) ||
          (canListTaxis.value && _setupPending(user.value?.taxiStatus)));

  String get postLoginRoute {
    if (user.value?.needsProfilePhoto ?? false) return AppRoutes.profilePhoto;
    if (!(user.value?.roleConfirmed ?? false)) return AppRoutes.roleSelect;
    if (ownerShellEmpty.value && isOwner) return AppRoutes.main;
    if (staysEnabled && _setupPending(user.value?.stayStatus)) return AppRoutes.staySetup;
    if (taxisEnabled && _setupPending(user.value?.taxiStatus)) return AppRoutes.taxiSetup;
    return AppRoutes.main;
  }

  @override
  void onInit() {
    super.onInit();
    _syncRoleFromToken(StorageService.getToken());
    user.value = StorageService.getUser();
    _syncProfileFields(user.value);
    syncShell();
    ever<UserModel?>(user, (_) => syncShell());
    ever<String>(roleKey, (_) => syncShell());
    ever<int>(_tabs.version, (_) => leaveOffTabRoute());
    markVisited(tabIndex.value);
    ever<int>(tabIndex, markVisited);
    ever<UserModel?>(user, gateProfilePhoto);
  }

  // These pages navigate through postLoginRoute themselves, so the worker stays silent there.
  static const Set<String> _photoGateQuiet = {
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.phoneVerify,
    AppRoutes.otp,
    AppRoutes.onboarding,
    AppRoutes.profilePhoto,
  };

  void gateProfilePhoto(UserModel? u) {
    if (u == null || !u.needsProfilePhoto || !StorageService.isLoggedIn) return;
    if (_photoGateQuiet.contains(Get.currentRoute)) return;
    Get.offAllNamed(AppRoutes.profilePhoto);
  }

  /// Gated setup screens have no MainScreen underneath; MainScreen's own worker covers the rest.
  void leaveOffTabRoute() {
    final route = Get.currentRoute;
    if (AppRoutes.tabKeyForRoute(route) == null || canOpenRoute(route)) return;
    if (Get.isRegistered<HomeController>() || !StorageService.isLoggedIn) return;
    if (postLoginRoute == AppRoutes.main) Get.offAllNamed(AppRoutes.main);
  }

  // ── Phone Login ───────────────────────────────────────────────────────────

  Future<bool> sendLoginOtp(String phone) async {
    try {
      isLoading.value = true;
      await ApiService.post('/auth/phone/send-otp', {'phoneNumber': phone});
      return true;
    } catch (e) {
      AppToast.error(_otpSendError(e));
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Returns null on success (login), 'onboarding' if new user, error string on failure.
  Future<String?> verifyLoginOtp(String phone, String otp) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/auth/phone/verify-otp', {
        'phoneNumber': phone,
        'otp': otp,
      });
      final data = res['data'] as Map<String, dynamic>;
      final needsOnboarding = data['needsOnboarding'] as bool? ?? false;
      if (needsOnboarding) {
        signupUsername.value = signupUsernameOf(data);
        return 'onboarding';
      }
      await _saveSession(data);
      Get.offAllNamed(postLoginRoute);
      return null;
    } catch (e) {
      return _otpVerifyError(e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Session saved, no navigation (the picture upload follows); false = the error is already shown.
  Future<bool> createOnboardingAccount({
    required String phone,
    required String name,
  }) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/auth/phone/complete-onboarding', {
        'phoneNumber': phone,
        'name': name,
      });
      await _saveSession(res['data'] as Map<String, dynamic>);
      return true;
    } catch (e) {
      if (_errorType(e) == otpRequiredType) {
        AppToast.error(_errorMessage(e) ?? 'Please verify your phone number again.');
        Get.offAllNamed(AppRoutes.login);
        return false;
      }
      AppToast.error(_onboardingError(e));
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  static const String otpRequiredType = 'OtpRequired';

  // ── Phone Verification (profile — change number) ──────────────────────────

  /// Returns null on success, error string on failure (409 = phone claimed).
  Future<String?> sendPhoneOtp(String phone) async {
    try {
      isLoading.value = true;
      await ApiService.post('/auth/send-otp', {'phoneNumber': phone});
      return null;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) return 'phone_claimed';
      return _dioMessage(e, 'Could not send OTP. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> verifyPhoneOtp(String phone, String otp) async {
    try {
      isLoading.value = true;
      final res = await ApiService.post('/auth/verify-phone', {
        'phoneNumber': phone,
        'otp': otp,
      });
      final updated = UserModel.fromJson(res['data'] as Map<String, dynamic>);
      StorageService.saveUser(updated);
      user.value = updated;
      _syncProfileFields(updated);
      Get.find<UserRepository>().invalidate();
      return true;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 409) {
        AppToast.warning('This number is already verified by another account.');
      } else {
        AppToast.error(_otpVerifyError(e) ?? 'Invalid or expired OTP.');
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> _applySession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final userData = data['user'] as Map<String, dynamic>;
    await StorageService.saveToken(token);
    _syncRoleFromToken(token);
    final userModel = UserModel.fromJson(userData);
    StorageService.saveUser(userModel);
    user.value = userModel;
    _syncProfileFields(userModel);
    signupUsername.value = null;
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    await _applySession(data);
    // Register FCM token after login — fire-and-forget, must not block login flow
    NotificationService.to.registerTokenAfterLogin()
        .catchError((e) => debugPrint('FCM token registration failed: $e'));
  }

  // The one shared cleanup routine for every logout trigger — explicit logout, account deletion,
  // and a server-forced 401 (revoked session) all funnel through here via ApiService's
  // single-flight guard, so a burst of concurrent 401s (there are ~10+ authenticated calls at
  // app start) can never race each other or diverge from what an explicit logout does.
  Future<void> forceLogout({required LogoutReason reason}) {
    return ApiService.runExclusiveLogout(() => _performLogoutCleanup(reason));
  }

  bool get blocksShellSwitch => isLoggingOut.value || cleaningUp.value;

  static const Duration hubDisconnectTimeout = Duration(seconds: 2);

  Future<void> _performLogoutCleanup(LogoutReason reason) async {
    cleaningUp.value = true;
    try {
      await _cleanupSession(reason);
    } finally {
      cleaningUp.value = false;
    }
  }

  // Local steps first and awaited; server calls run behind with the captured token, so a slow network
  // never delays the redirect and no late step can touch the next session (FX-26).
  Future<void> _cleanupSession(LogoutReason reason) async {
    final buddyUserId = user.value?.id;
    final bearer = StorageService.getToken();
    final explicit = reason == LogoutReason.explicitLogout;
    try {
      NotificationService.to.clearToken(unregister: explicit, bearer: bearer);
    } catch (_) {}
    if (explicit && bearer != null) {
      unawaited(ApiService.sendAs('POST', '/auth/logout', bearer: bearer, data: const {}).catchError((_) {}));
    }
    try {
      unawaited(NotificationService.to.clearDistrictTopic().catchError((_) {}));
    } catch (_) {}
    try {
      await StorageService.clearAll();
    } catch (_) {}
    final imageDisk = _clearImageCaches();
    try {
      await NotificationService.to.cancelAllChatNotifications();
    } catch (_) {}
    try {
      await disconnectAllHubs().timeout(hubDisconnectTimeout);
    } catch (_) {}
    try {
      await imageDisk.timeout(hubDisconnectTimeout);
    } catch (_) {}
    user.value = null;
    roleKey.value = UserRoleKeys.seeker;
    canListStays.value = false;
    canListTaxis.value = false;
    shellKind.value = ShellKind.seeker;
    ShellState.current.value = ShellKind.seeker;
    ownerShellEmpty.value = false;
    tabIntent.value = null;
    visitedTabs.assignAll({AppTabs.home});
    _syncProfileFields(null);
    signupUsername.value = null;
    if (reason == LogoutReason.sessionExpired) {
      try {
        AppToast.info('Session expired. Please log in again.');
      } catch (_) {}
    } else if (reason == LogoutReason.roleChanged) {
      try {
        AppToast.info('Role updated. Please log in again.');
      } catch (_) {}
    } else if (reason == LogoutReason.accountSuspended) {
      try {
        AppToast.info('Your account is paused.');
      } catch (_) {}
    }
    try {
      await BuddySessionHooks.onLogout(reason, buddyUserId);
      await OwnerSessionHooks.onLogout(reason, buddyUserId);
    } catch (_) {}
    Get.offAllNamed(AppRoutes.login);
    // Deliberately force:false (the default) — GetX's own delete() bypasses BOTH the permanent
    // check AND the GetxServiceMixin check when force:true, which would delete AuthController
    // itself (a GetxController marked permanent) and every hub service (GetxService) mid-call.
    // With force:false, permanent-marked instances and anything extending GetxService are
    // correctly spared, while every plain GetxController — every data controller/repository
    // registered in MainScreen.initState() — still gets wiped. This is the single place that
    // guarantees the next login on the same device never inherits a prior account's in-memory
    // state, without having to remember to hand-add a reset call per controller.
    // The stay and taxi setup hubs register LocationController as permanent.
    if (Get.isRegistered<LocationController>()) Get.delete<LocationController>(force: true);
    PlanBindings.dispose();
    Get.deleteAll();
  }

  static Future<void> _clearImageCaches() async {
    try {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    } catch (_) {}
    try {
      await CachedNetworkImageProvider.defaultCacheManager.emptyCache();
    } catch (_) {}
  }

  Future<void> logout() {
    isLoading.value = false;
    // Scoped to explicit logout only (not the shared _performLogoutCleanup)
    // — a forced session-expiry logout can fire from any screen, where a
    // Profile-tied overlay wouldn't even be visible, and already has its
    // own toast; account deletion already has its own isLoading-driven UI.
    isLoggingOut.value = true;
    return forceLogout(reason: LogoutReason.explicitLogout).whenComplete(() {
      isLoggingOut.value = false;
    });
  }

  /// Returns the blocking reasons when the server refuses with 409 AccountHasActiveItems, else null.
  Future<List<String>?> deleteAccount() async {
    try {
      isLoading.value = true;
      await ApiService.delete('/account');
      await forceLogout(reason: LogoutReason.accountDeleted);
    } catch (e) {
      // A 401 here means the interceptor has already run forceLogout(sessionExpired) and shown
      // its own toast + redirected — showing "Could not delete account" on top would be a
      // second, contradictory toast on the login screen for the same underlying event.
      if (e is DioException && e.response?.statusCode == 401) return null;
      final blocked = AccountDeleteMessage.lines(e);
      if (blocked != null) return blocked;
      AppToast.error(_dioMessage(e, 'Could not delete account. Please try again.'));
    } finally {
      isLoading.value = false;
    }
    return null;
  }

  /// Null on success or a 401; the blocks of a 409 AccountHasActiveItems; an empty list after any other failure.
  Future<List<AccountDeleteBlock>?> deleteAccountBlocks() async {
    try {
      isLoading.value = true;
      await ApiService.delete('/account');
      await forceLogout(reason: LogoutReason.accountDeleted);
      return null;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return null;
      final blocks = AccountDeleteMessage.blocks(e);
      if (blocks != null) return blocks;
      AppToast.error(_dioMessage(e, 'Could not delete account. Please try again.'));
      return const [];
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshProfile() async {
    // Role select runs before MainScreen registers UserRepository.
    if (Get.isRegistered<UserRepository>()) Get.find<UserRepository>().invalidate();
    try {
      final res = await ApiService.get('/users/profile');
      final updated = UserModel.fromJson(res['data'] as Map<String, dynamic>);
      StorageService.saveUser(updated);
      user.value = updated;
      _syncProfileFields(updated);
    } catch (_) {}
  }

  // Two independent actions (edit-name sheet, visibility-confirm sheet on ProfileScreen), two
  // independent endpoints — deliberately not one combined "update profile" call, so editing your
  // name never has to know or care about the visibility toggle's state and vice versa.
  Future<bool> updateName(String name) async {
    final error = await saveName(name);
    if (error != null) AppToast.error(error);
    return error == null;
  }

  /// Null = saved, else the message to show; no toast.
  Future<String?> saveName(String name) async {
    try {
      isLoading.value = true;
      final res = await ApiService.put('/users/profile/name', {'name': name});
      applyUser(UserModel.fromJson(res['data'] as Map<String, dynamic>));
      return null;
    } catch (e) {
      return _dioMessage(e, 'Could not update name.');
    } finally {
      isLoading.value = false;
    }
  }

  void applyUser(UserModel u) {
    StorageService.saveUser(u);
    user.value = u;
    _syncProfileFields(u);
    if (Get.isRegistered<UserRepository>()) Get.find<UserRepository>().invalidate();
  }

  Future<bool> updateContactVisibility(bool isContactVisible) async {
    try {
      isLoading.value = true;
      final res = await ApiService.put('/users/profile/contact-visibility', {'isContactVisible': isContactVisible});
      final updated = UserModel.fromJson(res['data'] as Map<String, dynamic>);
      StorageService.saveUser(updated);
      user.value = updated;
      _syncProfileFields(updated);
      Get.find<UserRepository>().invalidate();
      return true;
    } catch (e) {
      AppToast.error(_dioMessage(e, 'Could not update contact visibility.'));
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ── Role ──────────────────────────────────────────────────────────────────

  Future<List<RoleModel>> fetchRoles() async {
    try {
      final res = await ApiService.get('/roles');
      return (res['data'] as List)
          .map((e) => RoleModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (!_isUnauthorized(e)) AppToast.error(_dioMessage(e, 'Could not load roles.'));
      return const [];
    }
  }

  Future<RoleActionResult> chooseRole(String roleKey) async {
    try {
      isLoading.value = true;
      final res = await ApiService.put('/users/me/role-choice', {'role': roleKey});
      await _applySession(res['data'] as Map<String, dynamic>);
      Get.offAllNamed(postLoginRoute);
      return RoleActionResult.success;
    } catch (e) {
      if (_isUnauthorized(e)) return RoleActionResult.failed;
      if (_isRoleUnavailable(e)) {
        AppToast.warning('This role is not available right now.');
        return RoleActionResult.unavailable;
      }
      if (e is DioException && e.response?.statusCode == 409) {
        await _recoverChosenRole();
      } else {
        AppToast.error(_dioMessage(e, 'Could not save your role.'));
      }
      return RoleActionResult.failed;
    } finally {
      isLoading.value = false;
    }
  }

  // The token must carry the server's committed role, not the login-time claim.
  Future<void> _recoverChosenRole() async {
    await refreshProfile();
    final current = user.value;
    if (current == null || !current.roleConfirmed) {
      Get.offAllNamed(postLoginRoute);
      return;
    }
    try {
      final res = await ApiService.put('/users/me/role-choice', {'role': current.role});
      await _applySession(res['data'] as Map<String, dynamic>);
      Get.offAllNamed(postLoginRoute);
    } catch (e) {
      if (_isUnauthorized(e)) return;
      AppToast.error(_dioMessage(e, 'Could not save your role.'));
    }
  }

  Future<RoleActionResult> correctRole(String roleKey) async {
    try {
      isLoading.value = true;
      final res = await ApiService.put('/users/me/role-correction', {'role': roleKey});
      await _applySession(res['data'] as Map<String, dynamic>);
      if (Get.isRegistered<StaySetupController>()) Get.find<StaySetupController>().clear();
      if (Get.isRegistered<TaxiSetupController>()) Get.find<TaxiSetupController>().clear();
      Get.offAllNamed(postLoginRoute);
      return RoleActionResult.success;
    } catch (e) {
      if (_isUnauthorized(e)) return RoleActionResult.failed;
      if (_isRoleUnavailable(e)) {
        AppToast.warning('This role is not available right now.');
        return RoleActionResult.unavailable;
      }
      if (e is DioException && e.response?.statusCode == 409) {
        AppToast.warning(_dioMessage(e, 'Could not change role.'));
        await _recoverChosenRole();
      } else {
        AppToast.error(_dioMessage(e, 'Could not change role.'));
      }
      return RoleActionResult.failed;
    } finally {
      isLoading.value = false;
    }
  }

  Future<RoleActionResult> requestRoleChange(String roleKey) async {
    try {
      isLoading.value = true;
      await ApiService.post('/users/me/role-request', {'role': roleKey});
      await refreshProfile();
      return RoleActionResult.success;
    } catch (e) {
      if (_isUnauthorized(e)) return RoleActionResult.failed;
      if (_isRoleUnavailable(e)) {
        AppToast.warning('This role is not available right now.');
        return RoleActionResult.unavailable;
      }
      if (e is DioException && e.response?.statusCode == 409) {
        final type = e.response?.data?['error']?['type'];
        AppToast.warning(type == RoleRequestErrorTypes.cooldown ||
                type == RoleRequestErrorTypes.liveListing ||
                type == RoleRequestErrorTypes.locked
            ? _dioMessage(e, 'Try again later.')
            : 'A request is already pending.');
        await refreshProfile();
      } else {
        AppToast.error(_dioMessage(e, 'Could not send request.'));
      }
      return RoleActionResult.failed;
    } finally {
      isLoading.value = false;
    }
  }

  // ── Error helpers ─────────────────────────────────────────────────────────

  // The ApiService interceptor already logged out and toasted on a 401.
  static bool _isUnauthorized(dynamic e) => e is DioException && e.response?.statusCode == 401;

  static Object? _errorType(dynamic e) {
    if (e is! DioException) return null;
    final data = e.response?.data;
    final error = data is Map ? data['error'] : null;
    return error is Map ? error['type'] : null;
  }

  static String? _errorMessage(dynamic e) {
    if (e is! DioException) return null;
    final data = e.response?.data;
    final error = data is Map ? data['error'] : null;
    final message = error is Map ? error['message'] : null;
    return message is String && message.trim().isNotEmpty ? message : null;
  }

  static bool _isRoleUnavailable(dynamic e) {
    if (e is! DioException || e.response?.statusCode != 400) return false;
    final data = e.response?.data;
    final error = data is Map ? data['error'] : null;
    final type = error is Map ? error['type'] : null;
    return type == RoleRequestErrorTypes.unavailable || type == RoleRequestErrorTypes.invalidRole;
  }

  static String _retryAfter(DioException e) {
    final raw = e.response?.headers.value('retry-after');
    final seconds = raw != null ? int.tryParse(raw) : null;
    if (seconds == null || seconds <= 0) return '1 hour';
    final totalMinutes = (seconds / 60).ceil();
    if (totalMinutes < 60) return '$totalMinutes minute${totalMinutes == 1 ? '' : 's'}';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) return '$hours hour${hours == 1 ? '' : 's'}';
    return '$hours hour${hours == 1 ? '' : 's'} $mins minute${mins == 1 ? '' : 's'}';
  }

  static String _otpSendError(dynamic e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 429) return 'OTP limit reached. Try again in ${_retryAfter(e)}.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final message = e.response?.data?['error']?['message'] as String?;
      return message ?? 'Failed to send OTP. Please try again.';
    }
    return 'Failed to send OTP. Please try again.';
  }

  static String? _otpVerifyError(dynamic e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 429) return 'Too many attempts. Try again in ${_retryAfter(e)}.';
      if (status == 400) return 'Incorrect OTP. Please check and try again.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final message = e.response?.data?['error']?['message'] as String?;
      return message ?? 'Invalid or expired OTP. Please try again.';
    }
    return 'Invalid or expired OTP. Please try again.';
  }

  static String _onboardingError(dynamic e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 409) {
        final message = e.response?.data?['error']?['message'] as String?;
        return message ?? 'This phone number is not available. Please try another.';
      }
      if (status == 400) {
        final message = e.response?.data?['error']?['message'] as String?;
        return message ?? 'Invalid details. Please check and try again.';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
    }
    return 'Could not complete sign up. Please try again.';
  }

  static String _dioMessage(dynamic e, String fallback) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No internet connection. Please check your network.';
      }
      final status = e.response?.statusCode;
      final message = e.response?.data?['error']?['message'] as String?;
      if (status == 400 && message != null) return message;
      if (status == 429) return 'Too many attempts. Please try again later.';
      if (status != null && status >= 500) return 'Server error. Please try again.';
      if (message != null) return message;
    }
    return fallback;
  }
}
