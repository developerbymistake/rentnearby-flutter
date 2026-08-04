import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../config/app_routes.dart';
import '../controllers/location_controller.dart';
import 'api_service.dart';

/// Receiver for `developerbymistake.tech/go/{type}/{slug}` App Links (the QR smart-link's
/// payload — see AndroidManifest.xml's `/go/` pathPrefix, added alongside the existing `/app`
/// one under the same verified host).
///
/// A cold-started, freshly-installed user opens straight into `splash_screen.dart`, which
/// routes to `main`/`intro`/`login` purely off session state — none of the listing screens
/// exist in the navigator yet at that point. So a link caught before `MainScreen` has ever
/// mounted this session is cached here (`_pendingType`/`_pendingSlug`) instead of navigated
/// immediately, and replayed once `MainScreen.initState()` calls [markMainReady] — which only
/// happens after intro/login have already completed (splash's only route to `main`). A link
/// caught while `MainScreen` has already mounted at least once this session resolves and
/// navigates immediately, on top of whatever screen is currently showing.
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
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  /// Called once from `MainScreen.initState()` (post-frame) — flips the ready flag and
  /// replays anything a `/go/` link cached before `main` was ever reached this session.
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

  Future<void> _resolveAndNavigate(String type, String slug) async {
    final isRoom = type == 'r';
    try {
      final res = await ApiService.get(isRoom ? '/listings/by-slug/$slug' : '/plots/by-slug/$slug');
      final data = res['data'];
      if (data is! Map) return;
      final id = data['id'] as String?;
      if (id == null) return;

      Get.toNamed(
        isRoom ? AppRoutes.listingDetail : AppRoutes.plotDetail,
        arguments: {'id': id},
      );

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
