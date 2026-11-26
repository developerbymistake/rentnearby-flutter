import 'dart:math' as math;

import '../../../utils/app_toast.dart';
import '../../owner_core/data/owner_api.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/json/owner_json.dart';
import '../strings/taxi_availability_strings.dart';
import 'taxi_availability_models.dart';

class TaxiAvailabilityApi {
  const TaxiAvailabilityApi();

  static const String path = '/taxis/me/days-off';

  Future<OwnerResult<TaxiAvailability>> load() => OwnerApi.get(path, TaxiAvailability.fromJson);

  Future<OwnerResult<TaxiAvailability>> save({required List<TaxiDayOff> set, required List<String> clear}) => OwnerApi.put(
        path,
        {
          'set': [for (final d in set) d.toJson()],
          'clear': clear,
        },
        TaxiAvailability.fromJson,
      );
}

abstract final class TaxiHourlyLimit {
  static const String availability = 'availability';
  static const String bookings = 'bookings';
  static const String tooManyType = 'TooManyRequests';

  static DateTime Function() clock = DateTime.now;
  static final Map<String, DateTime> _blockedUntil = {};

  static String? bucketOf(OwnerRefused<dynamic> r) => r.statusCode == 429 ? OwnerJson.strOrNull(r.data['bucket']) : null;

  static int secondsOf(OwnerRefused<dynamic> r) {
    final header = r.retryAfterSeconds ?? 1;
    final body = OwnerJson.intOrNull(r.data['retryAfterSeconds']) ?? 1;
    return math.max(1, math.max(header, body));
  }

  static int minutes(int seconds) => math.max(1, (seconds / 60).ceil());

  static int? heldSeconds(String bucket) {
    final until = _blockedUntil[bucket];
    if (until == null) return null;
    final left = until.difference(clock()).inMilliseconds;
    if (left <= 0) {
      _blockedUntil.remove(bucket);
      return null;
    }
    return (left / 1000).ceil();
  }

  static void hold(String bucket, int seconds) => _blockedUntil[bucket] = clock().add(Duration(seconds: math.max(1, seconds)));

  static OwnerRefused<T> heldRefusal<T>(String bucket, int seconds) => OwnerRefused<T>(
        type: tooManyType,
        statusCode: 429,
        message: TaxiAvailabilityStrings.rateLimited(minutes(seconds)),
        data: {'bucket': bucket, 'retryAfterSeconds': seconds},
        retryAfterSeconds: seconds,
      );

  // Keeps the hold and puts the minutes text in the message, so every caller that shows the message shows the right line.
  static OwnerResult<T> note<T>(OwnerResult<T> r) {
    if (r is! OwnerRefused<T>) return r;
    final bucket = bucketOf(r);
    if (bucket == null) return r;
    final seconds = secondsOf(r);
    hold(bucket, seconds);
    return OwnerRefused<T>(
      type: r.type,
      statusCode: r.statusCode,
      message: TaxiAvailabilityStrings.rateLimited(minutes(seconds)),
      data: r.data,
      retryAfterSeconds: seconds,
    );
  }

  static Future<OwnerResult<T>> guard<T>(String bucket, Future<OwnerResult<T>> Function() call) async {
    final held = heldSeconds(bucket);
    if (held != null) return heldRefusal<T>(bucket, held);
    return note<T>(await call());
  }

  static bool toastIfLimited(OwnerRefused<dynamic> r) {
    final bucket = bucketOf(r);
    if (bucket == null) return false;
    final seconds = secondsOf(r);
    hold(bucket, seconds);
    AppToast.warning(TaxiAvailabilityStrings.rateLimited(minutes(seconds)));
    return true;
  }

  static bool toastIfHeld(String bucket) {
    final held = heldSeconds(bucket);
    if (held == null) return false;
    AppToast.warning(TaxiAvailabilityStrings.rateLimited(minutes(held)));
    return true;
  }

  static void reset() {
    _blockedUntil.clear();
    clock = DateTime.now;
  }
}
