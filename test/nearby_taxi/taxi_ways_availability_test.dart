import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_availability.dart';
import 'package:bakhli/features/taxi/ways/taxi_ways_controller.dart';
import 'package:bakhli/models/place_result_model.dart';

import 'fake_ways_repo.dart';

PlaceResult place(String n, double lat) => PlaceResult(name: n, subtitle: '', latLng: LatLng(lat, 79));

Future<void> settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late FakeWaysRepo repo;
  late TaxiWaysAvailabilityCheck check;

  setUp(() {
    repo = FakeWaysRepo();
    check = TaxiWaysAvailabilityCheck(repo: repo);
  });

  test('starts idle and not available', () {
    expect(check.state.value, WaysAvailability.idle);
    expect(check.isAvailable, isFalse);
  });

  test('asks with the same date and people the ways feed opens with', () async {
    await check.check(from: place('Haldwani', 29.2), to: place('Almora', 29.6), fromMyLocation: true);
    final c = repo.calls.single;
    expect(c.fromLat, 29.2);
    expect(c.toLat, 29.6);
    expect(c.date, TaxiWaysController.defaultDate());
    expect(c.people, TaxiWaysController.defaultPeople);
    expect(c.fromMyLocation, isTrue);
  });

  test('loading while the answer is out, then available', () async {
    repo.manual = true;
    final f = check.check(from: place('A', 29.2), to: place('B', 29.6));
    expect(check.state.value, WaysAvailability.loading);
    expect(check.isAvailable, isFalse);
    repo.pending.single.complete(true);
    await f;
    expect(check.state.value, WaysAvailability.available);
    expect(check.isAvailable, isTrue);
  });

  test('false answer is unavailable', () async {
    repo.answer = false;
    await check.check(from: place('A', 29.2), to: place('B', 29.6));
    expect(check.state.value, WaysAvailability.unavailable);
    expect(check.isAvailable, isFalse);
  });

  test('a failed check is failed, never available', () async {
    repo.error = StateError('503');
    await check.check(from: place('A', 29.2), to: place('B', 29.6));
    expect(check.state.value, WaysAvailability.failed);
    expect(check.isAvailable, isFalse);
  });

  test('a second call for the same places while loading does not refetch', () async {
    repo.manual = true;
    unawaited(check.check(from: place('A', 29.2), to: place('B', 29.6)));
    unawaited(check.check(from: place('A', 29.2), to: place('B', 29.6)));
    expect(repo.calls, hasLength(1));
    repo.pending.single.complete(true);
    await settle();
    expect(check.isAvailable, isTrue);
  });

  test('a refresh of the same places keeps the shown answer until the new one arrives', () async {
    await check.check(from: place('A', 29.2), to: place('B', 29.6));
    repo.manual = true;
    unawaited(check.check(from: place('A', 29.2), to: place('B', 29.6)));
    expect(check.state.value, WaysAvailability.available);
    repo.pending.single.completeError(StateError('offline'));
    await settle();
    expect(check.state.value, WaysAvailability.available);
  });

  test('a new search drops the old answer and never shows it', () async {
    repo.manual = true;
    unawaited(check.check(from: place('A', 29.2), to: place('B', 29.6)));
    unawaited(check.check(from: place('A', 29.2), to: place('C', 30.1)));
    expect(check.state.value, WaysAvailability.loading);
    repo.pending.first.complete(true);
    await settle();
    expect(check.state.value, WaysAvailability.loading);
    repo.pending.last.complete(false);
    await settle();
    expect(check.state.value, WaysAvailability.unavailable);
  });

  test('reset clears the answer and drops a late reply', () async {
    repo.manual = true;
    unawaited(check.check(from: place('A', 29.2), to: place('B', 29.6)));
    check.reset();
    expect(check.state.value, WaysAvailability.idle);
    repo.pending.single.complete(true);
    await settle();
    expect(check.state.value, WaysAvailability.idle);
  });
}
