import 'package:dio/dio.dart';

import '../../../utils/dio_error_mapper.dart';

class TaxiErrorTypes {
  static const String executionDisabled = 'TripExecutionDisabled';
  static const String planLocked = 'PlanLocked';
  static const String alreadyActive = 'TaxiRequestAlreadyActive';
  static const String stateInvalid = 'TaxiRequestStateInvalid';
  static const String offerStateInvalid = 'OfferStateInvalid';
  static const String legacyActive = 'LegacyTaxiActive';
  static const String allDriversBusy = 'AllDriversBusy';
  static const String notFound = 'TaxiRequestNotFound';
  static const String overlapping = 'OverlappingTaxiRequest';
  static const String seatsTooFew = 'SeatsTooFew';
  static const String tooManyTravellers = 'TooManyTravellers';
}

class TaxiLegacyRow {
  final String id;
  final bool booked;

  const TaxiLegacyRow({required this.id, required this.booked});
}

sealed class TaxiResult<T> {
  const TaxiResult();

  T? get valueOrNull => switch (this) {
        TaxiOk<T>(:final value) => value,
        _ => null,
      };

  static TaxiResult<T> fromError<T>(Object error) {
    if (error is! DioException) return TaxiFailed<T>(message: error.toString());
    if (DioErrorMapper.isNetworkError(error) || error.response == null) return TaxiOffline<T>();
    final status = error.response?.statusCode;
    final body = error.response?.data;
    final map = body is Map ? body : const {};
    final err = map['error'];
    final type = err is Map && err['type'] is String ? err['type'] as String : null;
    final message = err is Map && err['message'] is String ? err['message'] as String : null;
    final data = map['data'] is Map ? Map<String, dynamic>.from(map['data'] as Map) : const <String, dynamic>{};
    switch (type) {
      case TaxiErrorTypes.executionDisabled:
        return TaxiPaused<T>(message: message);
      case TaxiErrorTypes.planLocked:
        return TaxiPlanLocked<T>(reason: data['reason'] as String?, requestId: data['requestId'] as String?, message: message);
      case TaxiErrorTypes.alreadyActive:
        return TaxiAlreadyActive<T>(requestId: data['requestId'] as String?, message: message);
      case TaxiErrorTypes.stateInvalid:
      case TaxiErrorTypes.offerStateInvalid:
        return TaxiStateInvalid<T>(
            state: data['state'] as String?, version: (data['version'] as num?)?.toInt(), message: message);
      case TaxiErrorTypes.legacyActive:
        final rows = data['enquiries'];
        return TaxiLegacyActive<T>(
          rows: [
            if (rows is List)
              for (final r in rows)
                if (r is Map && r['id'] is String) TaxiLegacyRow(id: r['id'] as String, booked: r['booked'] == true),
          ],
          message: message,
        );
      case TaxiErrorTypes.allDriversBusy:
        return TaxiAllDriversBusy<T>(message: message);
      case TaxiErrorTypes.notFound:
        return TaxiNotFound<T>(message: message);
      case TaxiErrorTypes.overlapping:
        return TaxiOverlap<T>(tripId: data['tripId'] as String?, tripName: data['tripName'] as String?, message: message);
    }
    return TaxiRefused<T>(
      type: type,
      statusCode: status ?? 0,
      message: message,
      retryAfterSeconds: status == 429 ? _retryAfter(error) : null,
    );
  }

  static int _retryAfter(DioException error) {
    final seconds = int.tryParse(error.response?.headers.value('retry-after')?.trim() ?? '');
    return seconds == null || seconds < 1 ? 1 : (seconds > 120 ? 120 : seconds);
  }
}

class TaxiOk<T> extends TaxiResult<T> {
  final T value;

  const TaxiOk(this.value);
}

class TaxiPaused<T> extends TaxiResult<T> {
  final String? message;

  const TaxiPaused({this.message});
}

class TaxiPlanLocked<T> extends TaxiResult<T> {
  final String? reason;
  final String? requestId;
  final String? message;

  const TaxiPlanLocked({this.reason, this.requestId, this.message});
}

class TaxiAlreadyActive<T> extends TaxiResult<T> {
  final String? requestId;
  final String? message;

  const TaxiAlreadyActive({this.requestId, this.message});
}

class TaxiStateInvalid<T> extends TaxiResult<T> {
  final String? state;
  final int? version;
  final String? message;

  const TaxiStateInvalid({this.state, this.version, this.message});
}

class TaxiLegacyActive<T> extends TaxiResult<T> {
  final List<TaxiLegacyRow> rows;
  final String? message;

  const TaxiLegacyActive({required this.rows, this.message});
}

class TaxiAllDriversBusy<T> extends TaxiResult<T> {
  final String? message;

  const TaxiAllDriversBusy({this.message});
}

class TaxiOverlap<T> extends TaxiResult<T> {
  final String? tripId;
  final String? tripName;
  final String? message;

  const TaxiOverlap({this.tripId, this.tripName, this.message});
}

class TaxiNotFound<T> extends TaxiResult<T> {
  final String? message;

  const TaxiNotFound({this.message});
}

class TaxiRefused<T> extends TaxiResult<T> {
  final String? type;
  final int statusCode;
  final String? message;
  final int? retryAfterSeconds;

  const TaxiRefused({required this.type, required this.statusCode, this.message, this.retryAfterSeconds});

  bool get rateLimited => statusCode == 429;
}

class TaxiOffline<T> extends TaxiResult<T> {
  const TaxiOffline();
}

class TaxiFailed<T> extends TaxiResult<T> {
  final String message;

  const TaxiFailed({required this.message});
}
