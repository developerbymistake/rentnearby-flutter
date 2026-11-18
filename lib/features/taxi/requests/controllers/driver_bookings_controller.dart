import 'dart:async';

import 'package:get/get.dart';

import '../../../trip/utils/taxi_result.dart';
import '../data/driver_request_repository.dart';
import '../models/driver_request_models.dart';
import 'driver_requests_controller.dart';

enum DriverBookingAction { load, withdraw, end }

class DriverBookingsController extends GetxController {
  DriverBookingsController({
    this._repo = const DriverRequestRepository(),
    DateTime Function()? now,
    void Function()? onChanged,
  })  : _now = now ?? DateTime.now,
        _onChanged = onChanged ?? DriverRequestsController.onPushIfRegistered;

  static DriverBookingsController get to => Get.isRegistered<DriverBookingsController>()
      ? Get.find<DriverBookingsController>()
      : Get.put(DriverBookingsController());

  static void onPushIfRegistered() {
    if (Get.isRegistered<DriverBookingsController>()) unawaited(Get.find<DriverBookingsController>().reload());
  }

  final DriverRequestRepository _repo;
  final DateTime Function() _now;
  final void Function() _onChanged;

  late final month = DateTime(_now().year, _now().month).obs;
  final bookings = Rxn<DriverBookings>();
  final busy = <String>{}.obs;
  final failed = <String>{}.obs;

  int _loadSeq = 0;

  static String _key(DriverBookingAction a, [String? id]) => id == null ? a.name : '${a.name}:$id';

  bool isBusy(DriverBookingAction a, [String? id]) => busy.contains(_key(a, id));

  bool hasFailed(DriverBookingAction a, [String? id]) => failed.contains(_key(a, id));

  Future<TaxiResult<T>> _guarded<T>(String key, Future<TaxiResult<T>> Function() body) async {
    busy.add(key);
    failed.remove(key);
    try {
      final r = await body();
      if (r is! TaxiOk<T>) failed.add(key);
      return r;
    } finally {
      busy.remove(key);
    }
  }

  Future<TaxiResult<DriverBookings>> loadMonth(DateTime m) {
    month.value = DateTime(m.year, m.month);
    return reload();
  }

  Future<TaxiResult<DriverBookings>> reload() {
    final seq = ++_loadSeq;
    final m = month.value;
    return _guarded(_key(DriverBookingAction.load), () async {
      final r = await _repo.bookings(m, DateTime(m.year, m.month + 1, 0));
      if (seq != _loadSeq) return r;
      if (r case TaxiOk<DriverBookings>(:final value)) bookings.value = value;
      return r;
    });
  }

  Future<TaxiResult<DriverOffer>> withdraw(DriverBooking booking, ReasonChip chip) =>
      _guarded(_key(DriverBookingAction.withdraw, booking.bookingId), () async {
        final r = await _repo.withdraw(booking.offerId, chip);
        if (r is TaxiOk<DriverOffer> || r is TaxiStateInvalid<DriverOffer>) _changed();
        return r;
      });

  Future<TaxiResult<DriverBooking>> endBooking(DriverBooking booking) =>
      _guarded(_key(DriverBookingAction.end, booking.bookingId), () async {
        final r = await _repo.endBooking(booking.bookingId);
        if (r is TaxiOk<DriverBooking> || r is TaxiStateInvalid<DriverBooking>) _changed();
        return r;
      });

  void _changed() {
    unawaited(reload());
    _onChanged();
  }
}
