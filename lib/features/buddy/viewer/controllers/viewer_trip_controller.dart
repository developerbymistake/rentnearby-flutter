import 'package:get/get.dart';

import '../../../trip/utils/trip_clock.dart';
import '../../buddy_error_types.dart';
import '../../buddy_live.dart';
import '../../ledger/data/ledger_api.dart';
import '../../shared/buddy_result.dart';
import '../data/trip_viewer_api.dart';
import '../data/viewer_trip_cache.dart';
import '../models/viewer_models.dart';
import '../viewer_deps.dart';
import '../viewer_rules.dart';

enum ViewerTripState { loading, ready, notOnTrip, deleted, failed, owner }

class ViewerTripController extends GetxController {
  ViewerTripController(this.tripId, {this.startDeleted = false, TripViewerApi? api, LedgerApi? ledger})
      : _api = api ?? ViewerDeps.viewer,
        _ledger = ledger ?? ViewerDeps.ledger;

  final String tripId;
  final bool startDeleted;
  final TripViewerApi _api;
  final LedgerApi _ledger;

  final state = ViewerTripState.loading.obs;
  final trip = Rxn<ViewerTrip>();
  final offline = false.obs;
  final notOnTrip = Rxn<NotOnTripInfo>();
  final dayTotals = <int, int>{}.obs;
  String? _etag;
  int _seq = 0;
  final List<Worker> _workers = [];

  static ViewerTripController? maybeOf(String tripId) => Get.isRegistered<ViewerTripController>(tag: tripId) ? Get.find<ViewerTripController>(tag: tripId) : null;

  static ViewerTripController ensure(String tripId) => maybeOf(tripId) ?? Get.put(ViewerTripController(tripId), tag: tripId);

  @override
  void onInit() {
    super.onInit();
    final saved = ViewerTripCache.read(tripId);
    if (saved != null) {
      trip.value = saved.trip;
      _etag = saved.etag;
    }
    _workers.add(ever<int>(BuddyLive.tripView(tripId), (_) => load()));
    _workers.add(ever<int>(BuddyLive.expenses(tripId), (_) => load()));
    _workers.add(ever<String?>(BuddyLive.goneTrip, (id) {
      if (id == tripId) {
        ViewerTripCache.remove(tripId);
        load();
      }
    }));
    if (startDeleted) {
      _markDeleted();
    } else {
      if (trip.value != null) state.value = ViewerTripState.ready;
      load();
    }
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void _markDeleted() {
    ViewerTripCache.remove(tripId);
    state.value = ViewerTripState.deleted;
  }

  Future<void> load() async {
    if (state.value == ViewerTripState.deleted || state.value == ViewerTripState.owner) return;
    final seq = ++_seq;
    if (trip.value == null && state.value != ViewerTripState.notOnTrip) state.value = ViewerTripState.loading;
    final r = await _api.view(tripId, etag: trip.value == null ? null : _etag);
    if (seq != _seq || isClosed) return;
    switch (r) {
      case BuddyOk(:final value):
        offline.value = false;
        notOnTrip.value = null;
        if (value.etag != null) _etag = value.etag;
        final t = value.trip;
        if (value.notModified || t == null) {
          state.value = trip.value == null ? ViewerTripState.failed : ViewerTripState.ready;
        } else if (t.isOwner) {
          state.value = ViewerTripState.owner;
        } else {
          trip.value = t;
          ViewerTripCache.write(tripId, t, _etag);
          state.value = ViewerTripState.ready;
        }
        if (state.value == ViewerTripState.ready) await loadDayTotals();
      case BuddyRefused(:final type, :final statusCode, :final data):
        if (type == BuddyErrorTypes.notOnTrip) {
          ViewerTripCache.remove(tripId);
          notOnTrip.value = NotOnTripInfo.fromJson(data);
          state.value = ViewerTripState.notOnTrip;
        } else if (statusCode == 404) {
          _markDeleted();
        } else {
          state.value = trip.value == null ? ViewerTripState.failed : ViewerTripState.ready;
        }
      case BuddyOffline():
        offline.value = trip.value != null;
        state.value = trip.value == null ? ViewerTripState.failed : ViewerTripState.ready;
      case BuddyFailed():
        state.value = trip.value == null ? ViewerTripState.failed : ViewerTripState.ready;
    }
  }

  Future<void> loadDayTotals() async {
    final t = trip.value;
    if (t == null || !t.expenses.hasExpenses) {
      dayTotals.clear();
      return;
    }
    final r = await _ledger.summary(tripId);
    if (isClosed) return;
    if (r case BuddyOk(:final value)) {
      final sums = <int, int>{};
      for (final d in value.byDay) {
        sums[d.day] = (sums[d.day] ?? 0) + d.total;
      }
      dayTotals.assignAll(sums);
    }
  }

  bool get tripEnded => ViewerRules.ended(trip.value?.endDate, TripClock.today());
}
