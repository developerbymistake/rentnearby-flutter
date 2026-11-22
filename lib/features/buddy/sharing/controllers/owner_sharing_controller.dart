import 'package:get/get.dart';

import '../../../../services/api_service.dart';
import '../../buddy_live.dart';
import '../../shared/buddy_api_base.dart';
import '../../shared/buddy_json.dart';
import '../../shared/buddy_result.dart';
import '../models/sharing_models.dart';

typedef SharingFetch = Future<BuddyResult<TripSharingBlock?>> Function(String tripId);

class OwnerSharingController extends GetxController {
  OwnerSharingController(this.tripId, {TripSharingBlock? initial, SharingFetch? fetch})
      : sharing = Rx<TripSharingBlock?>(initial),
        _fetch = fetch ?? fetchSharing;

  final String tripId;
  final Rx<TripSharingBlock?> sharing;
  final SharingFetch _fetch;
  final List<Worker> _workers = [];
  Future<void>? _loading;
  bool _fetchedOnce = false;

  // The server answered the trip without any sharing key (older than the sharing feature):
  // the cards would lead to routes it does not have.
  final unsupported = false.obs;

  static SharingFetch? debugFetch;

  static Future<BuddyResult<TripSharingBlock?>> fetchSharing(String tripId) => BuddyApiBase.run(() async {
        final data = BuddyApiBase.dataOf(await BuddyApiBase.read(() => ApiService.get('/trips/$tripId')));
        final s = data['sharing'];
        return s is Map ? TripSharingBlock.fromJson(BuddyJson.map(s)) : null;
      });

  static OwnerSharingController ensure(String tripId, TripSharingBlock? initial) {
    if (Get.isRegistered<OwnerSharingController>(tag: tripId)) return Get.find<OwnerSharingController>(tag: tripId);
    return Get.put(OwnerSharingController(tripId, initial: initial, fetch: debugFetch), tag: tripId);
  }

  static OwnerSharingController? of(String tripId) =>
      Get.isRegistered<OwnerSharingController>(tag: tripId) ? Get.find<OwnerSharingController>(tag: tripId) : null;

  static void release(String? tripId) {
    if (tripId != null && Get.isRegistered<OwnerSharingController>(tag: tripId)) Get.delete<OwnerSharingController>(tag: tripId);
  }

  @override
  void onInit() {
    super.onInit();
    _workers
      ..add(ever(BuddyLive.tripView(tripId), (_) => reload()))
      ..add(ever(BuddyLive.expenses(tripId), (_) => reload()));
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  Future<void> reload() => _loading ??= _load().whenComplete(() => _loading = null);

  // One background fetch per screen entry while no real block is known; a failed fetch is not
  // retried on rebuilds (next entry or pull to refresh retries).
  void fetchOnceIfMissing() {
    if (_fetchedOnce || sharing.value != null) return;
    _fetchedOnce = true;
    reload();
  }

  Future<void> _load() async {
    _fetchedOnce = true;
    final r = await _fetch(tripId);
    if (isClosed) return;
    if (r is! BuddyOk<TripSharingBlock?>) return;
    final v = r.value;
    if (v != null) {
      sharing.value = v;
      unsupported.value = false;
    } else if (sharing.value == null) {
      unsupported.value = true;
    }
  }

  Future<T?> afterReturn<T>(Future<T?>? push) async {
    final v = await push;
    reload();
    return v;
  }
}
