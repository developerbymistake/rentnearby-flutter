import 'dart:convert';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a step in a plan push opens the trip overview', () {
    final redirected = <Map<String, dynamic>>[
      {'tripId': 't1', 'step': 'gettingThere'},
      {'tripId': 't1', 'step': 'stay:2', 'nudge': true, 'name': 'Hill View'},
      {'tripId': 't1', 'row': 'stay:1'},
      {'tripId': 't1', 'nudge': true},
      {'tripId': 't1', 'nudge': 'true'},
      {'tripId': 't1', 'reopen': true},
      {'tripId': 't1', 'reopen': 'true'},
    ];

    for (final args in redirected) {
      test('liveTarget $args', () {
        final live = AppRoutes.liveTarget(AppRoutes.tripPlan, args)!;
        expect(live.route, AppRoutes.tripOverview);
        expect(live.args, {'tripId': 't1'});
      });

      test('liveRouteData $args', () {
        final data = NotificationService.liveRouteData({
          'notification_type': 'TripGuideNudge',
          'action_route': AppRoutes.tripPlan,
          'action_args_json': jsonEncode(args),
        });
        expect(data['action_route'], AppRoutes.tripOverview);
        expect(jsonDecode(data['action_args_json'] as String), {'tripId': 't1'});
        expect(data['notification_type'], 'TripGuideNudge');
      });
    }

    test('a step push without a trip id still lands on the overview', () {
      final live = AppRoutes.liveTarget(AppRoutes.tripPlan, {'step': 'taxi'})!;
      expect(live.route, AppRoutes.tripOverview);
      expect(live.args, isEmpty);
    });
  });

  group('other targets are unchanged', () {
    test('a plain plan push stays on the plan', () {
      for (final args in <Map<String, dynamic>?>[
        null,
        {'tripId': 't1'},
        {'tripId': 't1', 'nudge': false, 'reopen': false},
        {'tripId': 't1', 'nudge': 'false'},
      ]) {
        final live = AppRoutes.liveTarget(AppRoutes.tripPlan, args)!;
        expect(live.route, AppRoutes.tripPlan, reason: '$args');
        expect(identical(live.args, args), isTrue, reason: '$args');
      }
    });

    test('a plain plan push keeps its data object', () {
      final data = {'action_route': AppRoutes.tripPlan, 'action_args_json': '{"tripId":"t1"}'};
      expect(identical(NotificationService.liveRouteData(data), data), isTrue);
    });

    test('retired taxi pages still open the plan of the trip', () {
      for (final r in AppRoutes.retiredTripTaxiRoutes) {
        final live = AppRoutes.liveTarget(r, {'tripId': 't1', 'day': 2})!;
        expect(live.route, AppRoutes.tripPlan, reason: r);
        expect(live.args, {'tripId': 't1'}, reason: r);
      }
    });

    test('a step argument on another route is left alone', () {
      final args = {'tripId': 't1', 'step': 'stay:1'};
      final live = AppRoutes.liveTarget(AppRoutes.tripReplies, args)!;
      expect(live.route, AppRoutes.tripReplies);
      expect(identical(live.args, args), isTrue);
    });

    test('a null route gives null', () {
      expect(AppRoutes.liveTarget(null), isNull);
    });
  });
}
