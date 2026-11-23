import 'package:get/get.dart';
import '../config/shell_kind.dart';
import '../features/trip/data/trip_city_catalog.dart';
import 'auth_controller.dart';

/// Home tab's data source: the popular destinations rail (trip city catalog).
class HomeController extends GetxController {
  final popularLoading = false.obs;
  final popularFailed = false.obs;
  final popularVersion = 0.obs;

  final _workers = <Worker>[];
  Future<void>? _running;

  TripCityCatalog get _catalog => TripCityCatalog.to;

  @override
  void onInit() {
    super.onInit();
    _catalog.warmFromDisk();
    if (Get.isRegistered<AuthController>()) {
      _workers.add(ever<ShellKind>(Get.find<AuthController>().shellKind, (k) {
        if (k == ShellKind.seeker) reload();
      }));
    }
    reload();
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  bool get hasAnyRail {
    popularVersion.value;
    return _catalog.popular().isNotEmpty;
  }

  bool get anyRailLoading => popularLoading.value;

  bool get railsFailedNoCopy => popularFailed.value && !hasAnyRail;

  // Owners never see the Seeker rails (FX-17).
  static bool get _ownerShell => Get.isRegistered<AuthController>() && Get.find<AuthController>().isOwnerShell;

  /// Pull-to-refresh and retry; single flight.
  Future<void> reload() {
    final running = _running;
    if (running != null) return running;
    if (_ownerShell) return Future.value();
    final f = _load();
    _running = f;
    return f.whenComplete(() => _running = null);
  }

  Future<void> _load() async {
    popularLoading.value = true;
    try {
      await _catalog.load();
      popularFailed.value = false;
    } catch (_) {
      popularFailed.value = true;
    } finally {
      popularLoading.value = false;
      popularVersion.value++;
    }
  }
}
