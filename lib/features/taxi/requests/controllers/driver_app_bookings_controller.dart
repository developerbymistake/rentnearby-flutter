import 'dart:async';

import 'package:get/get.dart';

import '../../../trip/utils/taxi_result.dart';
import '../data/driver_request_repository.dart';
import '../models/driver_request_models.dart';
import 'driver_requests_controller.dart';

enum DriverAppBookingAction { load, withdraw, end }

/// "From the app": bookings that ended in the last 90 days plus the active and coming ones (two 91-day reads, server cap 92).
class DriverAppBookingsController extends GetxController {
  DriverAppBookingsController({this._repo = const DriverRequestRepository(), DateTime Function()? now, void Function()? onChanged})
      : _now = now ?? DateTime.now,
        _onChanged = onChanged ?? DriverRequestsController.onPushIfRegistered;

  static const String tag = 'taxi-app-bookings';

  static DriverAppBookingsController ensure() => Get.isRegistered<DriverAppBookingsController>(tag: tag)
      ? Get.find<DriverAppBookingsController>(tag: tag)
      : Get.put(DriverAppBookingsController(), tag: tag);

  static void onPushIfRegistered() {
    if (Get.isRegistered<DriverAppBookingsController>(tag: tag)) unawaited(Get.find<DriverAppBookingsController>(tag: tag).reload());
  }

  final DriverRequestRepository _repo;
  final DateTime Function() _now;
  final void Function() _onChanged;

  final items = <DriverBooking>[].obs;
  final loaded = false.obs;
  final busy = <String>{}.obs;
  final failed = <String>{}.obs;
  int _seq = 0;

  static String _key(DriverAppBookingAction a, [String? id]) => id == null ? a.name : '${a.name}:$id';

  bool isBusy(DriverAppBookingAction a, [String? id]) => busy.contains(_key(a, id));

  bool hasFailed(DriverAppBookingAction a, [String? id]) => failed.contains(_key(a, id));

  static List<DriverBooking> order(Iterable<DriverBooking> all) {
    final seen = <String>{};
    final list = [for (final b in all) if (b.bookingId.isNotEmpty && seen.add(b.bookingId)) b];
    list.sort((a, b) {
      final ad = a.fromDay;
      final bd = b.fromDay;
      if (ad == null || bd == null) return ad == null ? (bd == null ? 0 : 1) : -1;
      return ad.compareTo(bd);
    });
    return list;
  }

  Future<void> reload() async {
    final seq = ++_seq;
    final key = _key(DriverAppBookingAction.load);
    busy.add(key);
    failed.remove(key);
    final n = _now();
    final today = DateTime(n.year, n.month, n.day);
    try {
      final rs = await Future.wait([
        _repo.bookings(today.subtract(const Duration(days: 90)), today),
        _repo.bookings(today.add(const Duration(days: 1)), today.add(const Duration(days: 91))),
      ]);
      if (isClosed || seq != _seq) return;
      final ok = [for (final r in rs) if (r case TaxiOk<DriverBookings>(:final value)) value];
      if (ok.length < rs.length) failed.add(key);
      if (ok.isNotEmpty) {
        items.assignAll(order([for (final b in ok) ...b.items]));
        loaded.value = true;
      }
    } finally {
      if (!isClosed) busy.remove(key);
    }
  }

  Future<TaxiResult<DriverOffer>> withdraw(DriverBooking b, ReasonChip chip) => _guard(DriverAppBookingAction.withdraw, b.bookingId, () async {
        final r = await _repo.withdraw(b.offerId, chip);
        if (r is TaxiOk<DriverOffer> || r is TaxiStateInvalid<DriverOffer>) _changed();
        return r;
      });

  Future<TaxiResult<DriverBooking>> end(DriverBooking b) => _guard(DriverAppBookingAction.end, b.bookingId, () async {
        final r = await _repo.endBooking(b.bookingId);
        if (r is TaxiOk<DriverBooking> || r is TaxiStateInvalid<DriverBooking>) _changed();
        return r;
      });

  final Map<String, Future<Object>> _inFlight = {};

  Future<TaxiResult<T>> _guard<T>(DriverAppBookingAction a, String id, Future<TaxiResult<T>> Function() body) {
    final key = _key(a, id);
    final running = _inFlight[key];
    if (running != null) return running as Future<TaxiResult<T>>;
    Future<TaxiResult<T>> run() async {
      busy.add(key);
      failed.remove(key);
      try {
        final r = await body();
        if (r is! TaxiOk<T> && !isClosed) failed.add(key);
        return r;
      } finally {
        if (!isClosed) busy.remove(key);
        _inFlight.remove(key);
      }
    }

    final f = run();
    _inFlight[key] = f;
    return f;
  }

  void _changed() {
    unawaited(reload());
    _onChanged();
  }
}
