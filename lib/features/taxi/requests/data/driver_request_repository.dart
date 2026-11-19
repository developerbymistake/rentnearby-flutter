import 'package:dio/dio.dart';

import '../../../../services/api_service.dart';
import '../../../../services/storage_service.dart';
import '../../../../utils/network_retry.dart';
import '../../../trip/utils/taxi_result.dart';
import '../models/driver_request_models.dart';

class DriverErrorTypes {
  static const String offerMissed = 'OfferMissed';
  static const String datesAlreadyBooked = 'DatesAlreadyBooked';
  static const String confirmWindowPassed = 'ConfirmWindowPassed';
}

class TaxiOfferMissed<T> extends TaxiRefused<T> {
  final String? state;

  const TaxiOfferMissed({this.state, super.message})
      : super(type: DriverErrorTypes.offerMissed, statusCode: 409);
}

class TaxiDatesAlreadyBooked<T> extends TaxiRefused<T> {
  final String? from;
  final String? to;

  const TaxiDatesAlreadyBooked({this.from, this.to, super.message})
      : super(type: DriverErrorTypes.datesAlreadyBooked, statusCode: 409);

  DriverDatesConflict? get conflict => from == null || to == null ? null : DriverDatesConflict(from: from!, to: to!);
}

class TaxiConfirmWindowPassed<T> extends TaxiRefused<T> {
  const TaxiConfirmWindowPassed({super.message}) : super(type: DriverErrorTypes.confirmWindowPassed, statusCode: 409);
}

class DriverRequestRepository {
  const DriverRequestRepository();

  static const String _base = '/taxi-requests/driver';

  Map<String, dynamic> _data(Map<String, dynamic> res) {
    final data = res['data'];
    return data is Map<String, dynamic> ? data : const {};
  }

  static String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static TaxiResult<T> mapError<T>(Object error) {
    final base = TaxiResult.fromError<T>(error);
    if (base is! TaxiRefused<T> || error is! DioException) return base;
    final body = error.response?.data;
    final raw = body is Map ? body['data'] : null;
    final data = raw is Map ? raw : const {};
    switch (base.type) {
      case DriverErrorTypes.offerMissed:
        return TaxiOfferMissed<T>(state: data['state'] as String?, message: base.message);
      case DriverErrorTypes.datesAlreadyBooked:
        return TaxiDatesAlreadyBooked<T>(from: data['from'] as String?, to: data['to'] as String?, message: base.message);
      case DriverErrorTypes.confirmWindowPassed:
        return TaxiConfirmWindowPassed<T>(message: base.message);
    }
    return base;
  }

  Future<TaxiResult<T>> _run<T>(Future<T> Function() call) async {
    try {
      return TaxiOk(await call());
    } catch (e) {
      return mapError<T>(e);
    }
  }

  Future<TaxiResult<DriverOffer>> _offer(Future<Map<String, dynamic>> Function() call) =>
      _run(() async => DriverOffer.fromJson(_data(await call())));

  Future<TaxiResult<DriverOfferList>> offers({String? cursor}) => _run(() async => DriverOfferList.fromJson(_data(
      await withRetry(() => ApiService.get('$_base/offers', params: cursor == null ? null : {'cursor': cursor})))));

  Future<TaxiResult<DriverOffer>> offer(String offerId) =>
      _offer(() => withRetry(() => ApiService.get('$_base/offers/$offerId')));

  // The server ends the ring on the driver's other devices only, never on this one.
  Future<TaxiResult<DriverOffer>> accept(String offerId) =>
      _offer(() => ApiService.post('$_base/offers/$offerId/accept', {'deviceToken': StorageService.getFcmToken()}));

  Future<TaxiResult<DriverOffer>> decline(String offerId, {ReasonChip? chip}) => _offer(() =>
      ApiService.post('$_base/offers/$offerId/decline', {'chip': chip?.wire, 'deviceToken': StorageService.getFcmToken()}));

  Future<TaxiResult<DriverOffer>> confirm(String offerId) =>
      _offer(() => ApiService.post('$_base/offers/$offerId/confirm', const {}));

  Future<TaxiResult<DriverOffer>> withdraw(String offerId, ReasonChip chip) =>
      _offer(() => ApiService.post('$_base/offers/$offerId/withdraw', {'chip': chip.wire}));

  Future<TaxiResult<DriverBooking>> endBooking(String bookingId) =>
      _run(() async => DriverBooking.fromJson(_data(await ApiService.post('$_base/bookings/$bookingId/end', const {}))));

  Future<TaxiResult<DriverBookings>> bookings(DateTime from, DateTime to) => _run(() async => DriverBookings.fromJson(_data(
      await withRetry(() => ApiService.get('$_base/bookings', params: {'from': day(from), 'to': day(to)})))));

  Future<TaxiResult<DriverRating>> rating() =>
      _run(() async => DriverRating.fromJson(_data(await withRetry(() => ApiService.get('$_base/rating')))));

  Future<TaxiResult<DriverReadiness>> readiness() =>
      _run(() async => DriverReadiness.fromJson(_data(await withRetry(() => ApiService.get('$_base/readiness')))));

  Future<TaxiResult<DriverReadiness>> reportDevice(DriverDeviceState state) =>
      _run(() async => DriverReadiness.fromJson(_data(await ApiService.put('$_base/readiness', state.toJson()))));

  Future<TaxiResult<void>> testRing() => _run(() async {
        await ApiService.post('$_base/test-ring', const {});
      });
}
