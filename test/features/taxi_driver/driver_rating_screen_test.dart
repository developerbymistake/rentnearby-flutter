import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/taxi/requests/controllers/driver_rating_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/driver_rating_screen.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bakhli/design/tokens/design_scale.dart';

import '../../support/five_sizes.dart';
import '../../support/owner_render.dart';
import '../../support/real_phone.dart';

Map<String, dynamic> _sample() =>
    jsonDecode(File('test/features/taxi_request/samples/driver_rating.json').readAsStringSync()) as Map<String, dynamic>;

class _FakeRepo extends DriverRequestRepository {
  _FakeRepo(this.json);

  final Map<String, dynamic> json;

  @override
  Future<TaxiResult<DriverRating>> rating() async => TaxiOk(DriverRating.fromJson(json));
}

class _ScriptedRepo extends DriverRequestRepository {
  _ScriptedRepo(this.results);

  final List<Future<TaxiResult<DriverRating>> Function()> results;
  int calls = 0;

  @override
  Future<TaxiResult<DriverRating>> rating() => results[(calls++).clamp(0, results.length - 1)]();
}

Future<TaxiResult<DriverRating>> _fail() async => const TaxiFailed<DriverRating>(message: 'boom');

Widget _screen(Map<String, dynamic> json) => DriverRatingScreen(controller: DriverRatingController(repo: _FakeRepo(json)));

Map<String, dynamic> _noRatings() => {'average': null, 'ratingCount': 0, 'ridesCompleted': 3, 'latest': <Object>[]};

void main() {
  group('o_tx_20 render', () {
    setUp(DS.applyApproved);
    tearDown(DS.debugReset);

    testWidgets('render o_tx_20 frame strings', (tester) async {
      await renderOwnerFrame(tester, 'o_tx_20', _screen(_sample()), arrange: (t) => t.pumpAndSettle());
      for (final s in ['My rating', 'Your driver record', 'Average stars', '4.8', '72', 'Ratings', '86', 'Completed rides', 'Latest ratings', '2 Nov', '24 Oct']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
    });
  });

  testWidgets('sample_values', (tester) async {
    await pumpPhone(tester, _screen(_sample()));
    await tester.pumpAndSettle();
    expect(find.text('My rating'), findsOneWidget);
    expect(find.text('Your driver record'), findsOneWidget);
    expect(find.text('Average stars'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    expect(find.text('Ratings'), findsOneWidget);
    expect(find.text('86'), findsOneWidget);
    expect(find.text('Completed rides'), findsOneWidget);
    expect(find.text('Latest ratings'), findsOneWidget);
    for (final d in ['2 Nov', '24 Oct', '12 Oct', '30 Sep']) {
      expect(find.text(d), findsOneWidget);
    }
    expect(find.byIcon(Icons.star), findsNWidgets(5 + 4 * 5));
    expect(find.text('No ratings yet'), findsNothing);
  });

  testWidgets('null_average', (tester) async {
    await pumpPhone(tester, _screen(_noRatings()));
    await tester.pumpAndSettle();
    expect(find.text('-'), findsOneWidget);
    expect(find.text('No ratings yet'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Latest ratings'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('no_points_or_rank', (tester) async {
    await pumpPhone(tester, _screen(_sample()));
    await tester.pumpAndSettle();
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => (t.data ?? '').toLowerCase());
    for (final t in texts) {
      expect(t, isNot(contains('point')));
      expect(t, isNot(contains('rank')));
    }
    expect(texts.any((t) => t.contains('aarav') || t.contains('traveller')), isFalse);
  });

  testWidgets('loading_spinner', (tester) async {
    final gate = Completer<TaxiResult<DriverRating>>();
    final repo = _ScriptedRepo([() => gate.future]);
    await pumpPhone(tester, DriverRatingScreen(controller: DriverRatingController(repo: repo)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Could not load your rating'), findsNothing);
    gate.complete(TaxiOk(DriverRating.fromJson(_sample())));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('4.8'), findsOneWidget);
  });

  testWidgets('load_failed_then_retry', (tester) async {
    final repo = _ScriptedRepo([_fail, () async => TaxiOk(DriverRating.fromJson(_sample()))]);
    await pumpPhone(tester, DriverRatingScreen(controller: DriverRatingController(repo: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Could not load your rating'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('4.8'), findsNothing);
    expect(repo.calls, 1);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('Could not load your rating'), findsNothing);
    expect(find.text('4.8'), findsOneWidget);
  });

  testWidgets('refresh_failure_keeps_last_rating', (tester) async {
    final repo = _ScriptedRepo([() async => TaxiOk(DriverRating.fromJson(_sample())), _fail]);
    final c = DriverRatingController(repo: repo);
    await c.load();
    await pumpPhone(tester, DriverRatingScreen(controller: c));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(c.failed.value, isTrue);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Could not load your rating'), findsNothing);
  });

  testFiveSizes('rating_screen_sample', () => _screen(_sample()), check: (t, size) async {
    await t.pumpAndSettle();
    expect(find.text('4.8'), findsOneWidget);
  });

  testFiveSizes('rating_screen_no_ratings', () => _screen(_noRatings()), check: (t, size) async {
    await t.pumpAndSettle();
    expect(find.text('No ratings yet'), findsOneWidget);
  });
}
