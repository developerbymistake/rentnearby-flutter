import 'dart:async';
import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import '../config/app_tabs.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// `type` -> where to resolve a `/go/{type}/{slug}` payload. Additive by design: a future
/// vertical (e.g. Services) is a new map entry once it has a by-slug endpoint, not a rewrite
/// of `_resolveAndNavigate` below.
class _DeepLinkTypeConfig {
  final String bySlugPath;
  final int tabIndex;

  const _DeepLinkTypeConfig(this.bySlugPath, this.tabIndex);
}

const Map<String, _DeepLinkTypeConfig> _deepLinkTypes = {
  'r': _DeepLinkTypeConfig('/listings/by-slug', AppTabs.rooms),
  'p': _DeepLinkTypeConfig('/plots/by-slug', AppTabs.plots),
};

/// Receiver for `developerbymistake.tech/go/{type}/{slug}` smart-link payloads, from two
/// distinct sources:
///
/// 1. **Android App Links** (`AppLinks`, this class's original purpose) — fires while the app
///    is already installed and the OS has verified the domain, whether cold-starting the app
///    or tapping the link while it's already running.
/// 2. **Google Play Install Referrer** (`_consumeInstallReferrer`) — the deferred-deep-link
///    case: a user without the app scans the QR, gets bounced to the Play Store (see backend's
///    `/go/{type}/{slug}` fallback route, which encodes type+slug into the store URL's
///    `referrer` param), installs, and opens the app for the first time. Play hands that
///    referrer string back on this very first launch only — everything downstream (queueing,
///    resolving, navigating) is identical to the App Links path, it just starts from a
///    different capture point.
///
/// A cold-started, freshly-installed user opens straight into `splash_screen.dart`, which
/// routes to `main`/`intro`/`login` purely off session state — none of the listing screens
/// exist in the navigator yet at that point. So a link caught before `MainScreen` has ever
/// mounted this session is cached here (`_pendingType`/`_pendingSlug`) instead of navigated
/// immediately, and replayed once `MainScreen.initState()` calls [markMainReady] — which only
/// happens after intro/login have already completed (splash's only route to `main`). A link
/// caught while `MainScreen` has already mounted at least once this session resolves and
/// switches tabs immediately — a background state change, visible right away if `MainScreen`
/// is the current screen, or as soon as the user returns to it if something else is pushed on
/// top. The install-referrer
/// path is only *started* during `init()`, before `runApp()` — its actual plugin call is a
/// platform-channel round-trip that can resolve after `MainScreen` has already mounted and
/// called [markMainReady] (e.g. an already-logged-in cold start, which skips intro/login), so
/// `_consumeInstallReferrer` mirrors `_handleUri`'s own `_mainReady` check rather than assuming
/// it always resolves first.
class DeepLinkService extends GetxService {
  static DeepLinkService get to => Get.find<DeepLinkService>();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _mainReady = false;
  String? _pendingType;
  String? _pendingSlug;

  Future<void> init() async {
    _sub = _appLinks.uriLinkStream.listen(_handleUri, onError: (_) {});

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handleUri(initial);
    } catch (_) {}

    await _consumeInstallReferrer();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  /// Called once from `MainScreen.initState()` (post-frame) — flips the ready flag and
  /// replays anything a `/go/` link (App Link or install referrer) cached before `main` was
  /// ever reached this session.
  void markMainReady() {
    _mainReady = true;
    final type = _pendingType;
    final slug = _pendingSlug;
    _pendingType = null;
    _pendingSlug = null;
    if (type != null && slug != null) {
      unawaited(_resolveAndNavigate(type, slug));
    }
  }

  void _handleUri(Uri uri) {
    // Only /go/{type}/{slug} is a listing deep link — anything else (incl. plain /app opens,
    // which have no in-app listener at all today and just launch the app normally) is ignored.
    final segments = uri.pathSegments;
    if (segments.length < 3 || segments[0] != 'go') return;
    final type = segments[1];
    final slug = segments[2];
    if (type.isEmpty || slug.isEmpty) return;

    if (_mainReady) {
      unawaited(_resolveAndNavigate(type, slug));
    } else {
      // Last link wins if more than one arrives before main is reached.
      _pendingType = type;
      _pendingSlug = slug;
    }
  }

  /// A fresh install's first-ever launch has no App Link intent data (the user tapped the app
  /// icon after installing, not a link) — so this only ever has something to contribute when
  /// `_handleUri` above found nothing. Play returns the same referrer on every future cold
  /// start too (it's tied to the install record, not "first launch"), so the
  /// `StorageService`-backed one-time guard is what stops this from re-navigating to the same
  /// install-time listing on every unrelated future open.
  ///
  /// The plugin call below is a real platform-channel round-trip — it can resolve well after
  /// `runApp()` and, on an already-logged-in cold start (splash skips intro/login), even after
  /// `MainScreen` has already mounted and called [markMainReady] once. So unlike the doc
  /// comment on this class used to claim, this path is NOT guaranteed to run before
  /// `_mainReady` flips true — it must handle both cases exactly like `_handleUri` does: resolve
  /// immediately if main is already ready, otherwise queue.
  Future<void> _consumeInstallReferrer() async {
    if (!Platform.isAndroid) return;

    try {
      if (StorageService.getInstallReferrerConsumed()) return;

      final referrerDetails = await PlayInstallReferrer.installReferrer;
      final raw = referrerDetails.installReferrer;
      if (raw == null || raw.isEmpty) {
        // Organic install, no referrer at all — nothing will ever change here, consume once.
        StorageService.saveInstallReferrerConsumed();
        return;
      }

      final params = Uri.splitQueryString(raw);
      final type = params['type'];
      final slug = params['slug'];
      if (type == null || type.isEmpty || slug == null || slug.isEmpty) {
        // Foreign/ad-attribution referrer with no type+slug of ours — never changes, consume once.
        StorageService.saveInstallReferrerConsumed();
        return;
      }

      if (_mainReady) {
        // MainScreen already mounted and drained the pending slot before this plugin call
        // resolved — resolve directly, exactly like _handleUri does for the same case, instead
        // of writing into a slot nothing will ever drain again.
        StorageService.saveInstallReferrerConsumed();
        unawaited(_resolveAndNavigate(type, slug));
      } else if (_pendingType == null && _pendingSlug == null) {
        StorageService.saveInstallReferrerConsumed();
        _pendingType = type;
        _pendingSlug = slug;
      }
      // else: the pending slot is already occupied by a live App Link caught earlier in this
      // same init() call (or a racing stream event) — defer to it, and deliberately leave the
      // consumed flag unset so this referrer gets an uncontested retry on the next cold start
      // instead of being silently and permanently discarded.
    } catch (_) {
      // Play Services unavailable, no install record, or a plugin-internal failure — leave
      // the consumed flag unset above so this is retried next cold start.
    }
  }

  Future<void> _resolveAndNavigate(String type, String slug) async {
    final config = _deepLinkTypes[type];
    if (config == null) return; // Unknown/future type this build doesn't understand yet.

    try {
      final res = await ApiService.get('${config.bySlugPath}/$slug');
      final data = res['data'];
      if (data is! Map) return;

      // "Explore" isn't a pushed route — it's the Rooms/Plots tab-root screen itself, so
      // opening the right listing means switching to that tab, not navigating anywhere.
      // Radius chips, nearby-listing refresh, and map centering all follow automatically —
      // beginSearchOverride() below (via _applySearchPin) already drives the same reactive
      // workers Explore uses for a manual location search, regardless of how the tab was
      // reached.
      Get.find<AuthController>().tabIndex.value = config.tabIndex;

      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        unawaited(_applySearchPin(lat, lng, data['address'] as String?));
      }
    } catch (_) {
      // Unknown/soft-deleted slug (404) or a network failure — nothing to show for a route
      // the user didn't explicitly navigate to inside the app, so fail silently rather than
      // toast on top of whatever screen they land on.
    }
  }

  /// Same searchPinOverride mechanism `ExploreLocationSearchMixin.beginSearchOverride()`
  /// uses for manual location search, so Explore's map is already centered on the shared
  /// listing without the user having to search for it again. Fire-and-forget relative to
  /// navigation above — a failure here must never block opening the listing itself.
  Future<void> _applySearchPin(double lat, double lng, String? address) async {
    if (!Get.isRegistered<LocationController>()) return;
    final loc = Get.find<LocationController>();
    final generation = loc.beginSearchResolve();
    try {
      final ctx = await loc.resolveDistrictAt(lat, lng);
      if (!loc.isCurrentSearchGeneration(generation)) return;
      final nearestCity = ctx.nearestCity;
      if (nearestCity == null) {
        loc.searchResolving.value = false;
        return;
      }
      loc.beginSearchOverride(
        ctx.district,
        nearestCity,
        LatLng(lat, lng),
        address ?? ctx.district.name,
      );
    } catch (_) {
      if (loc.isCurrentSearchGeneration(generation)) loc.searchResolving.value = false;
    }
  }
}
