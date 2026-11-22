import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter_test/flutter_test.dart';

// FX-37: the app fallback rule and the server rule are tested with the same facts (copy of the backend
// RentNearBy.Tests/Owner/Vectors/plan_card_states.json, FB-12). The server `state` is left out on purpose,
// so the app's own D-09 order is what is checked.
Map<String, dynamic> _plansMe(Map<String, dynamic> v, DateTime now) {
  final source = v['source'] as String?;
  final playState = v['playState'] as String?;
  final ended = v['endedRecently'] == true;
  final paid = source != null;
  final ahead = now.add(const Duration(days: 20)).toUtc().toIso8601String();
  final behind = now.subtract(const Duration(days: 2)).toUtc().toIso8601String();
  return {
    'paymentEnabled': v['paymentEnabled'],
    'featureKey': 'Stay',
    'isPaid': paid,
    'source': source,
    'endsAt': paid ? ahead : null,
    'plan': {'id': paid ? 'plus' : 'free', 'name': paid ? 'Plus' : 'Free', 'isDefault': !paid},
    if (playState != null || ended)
      'play': {
        'state': ended ? 'SUBSCRIPTION_STATE_EXPIRED' : playState,
        'autoRenewEnabled': v['playAutoRenew'],
        'expiryAt': ended ? behind : ahead,
        'trialEndsAt': v['inPlayTrial'] == true ? ahead : null,
        'productId': 'stay_plus',
        'ownsActivePlan': paid && !ended,
      },
  };
}

void main() {
  final file = File('test/features/owner_core/samples/plan_card_states.json');
  final vectors = (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  final now = DateTime.now();

  test('the shared vector file is not empty', () => expect(vectors.length, greaterThanOrEqualTo(15)));

  for (final v in vectors) {
    test('vector: ${v['name']} -> ${v['expected']}', () {
      final me = MyPlanModel.fromJson(_plansMe(v, now));
      expect(PlanCardStates.ofPlan(me, now: now), PlanCardStates.parse(v['expected']));
    });
  }

  test('the server state wins over the facts when sent', () {
    final me = MyPlanModel.fromJson({..._plansMe(vectors.firstWhere((v) => v['expected'] == 'Plus'), now), 'state': 'Cancelled'});
    expect(PlanCardStates.ofPlan(me, now: now), PlanCardState.cancelled);
  });
}
