import 'dart:async';
import 'package:bakhli/features/taxi/ways/taxi_ways_repository.dart';

class FakeWaysRepo extends TaxiWaysRepository {
  FakeWaysRepo({this.answer = true});

  final calls = <({double fromLat, double toLat, DateTime date, int people, bool fromMyLocation})>[];
  final pending = <Completer<bool>>[];
  bool manual = false;
  bool answer;
  Object? error;

  @override
  Future<bool> available({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required DateTime date,
    required int people,
    bool fromMyLocation = false,
  }) {
    calls.add((fromLat: fromLat, toLat: toLat, date: date, people: people, fromMyLocation: fromMyLocation));
    if (manual) {
      final c = Completer<bool>();
      pending.add(c);
      return c.future;
    }
    final e = error;
    return e != null ? Future.error(e) : Future.value(answer);
  }
}
