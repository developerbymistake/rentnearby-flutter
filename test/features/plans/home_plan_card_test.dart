import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/home_plan_card.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/stay_owner/plan/stay_plan_copy.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_plan_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/owner_fakes.dart';
import '../../support/owner_render.dart';
import '../../support/owner_sizes.dart';
import '../../support/real_phone.dart';
import 'plans_harness.dart';

OwnerPlanCard? _card(String state, {Map<String, dynamic> extra = const {}}) => OwnerPlanCard.maybe({'state': state, ...extra});

const _stay = StayPlanCopy();
const _taxi = TaxiPlanCopy();

Widget _host(Widget child) => Scaffold(body: SingleChildScrollView(child: child));

Future<void> _pump(WidgetTester t, PlanRoleCopy copy, OwnerPlanCard? card, {String? city = 'Mukteshwar'}) async {
  await pumpPhone(t, _host(HomePlanCard(card: card, copy: copy, city: city)), size: const Size(392, 800));
  await t.pump();
}

void _texts(List<String> all) {
  for (final s in all) {
    expect(find.text(s), findsOneWidget, reason: s);
  }
}

final Map<String, Map<String, dynamic>> _fx = {
  'Free': {'trialAvailable': true, 'weekly': {'shown': 140, 'requestsNoRoute': 12}},
  'Trial': {'endsAt': '2026-11-28', 'limits': {'photos': 8, 'roomTypes': 6, 'routes': 5}},
  'Plus': {'renewsOn': '2026-12-21', 'weekly': {'shown': 412, 'enquiries': 9, 'requestsOnRoutes': 31, 'accepted': 12}},
  'Cancelled': {'endsAt': '2026-12-21'},
  'Grace': {},
  'OnHold': {},
  'Ended': {'hidden': {'photos': 6, 'roomTypes': 4, 'routes': 3}},
  'PaymentOff': {},
};

void main() {
  tearDown(resetPlans);

  group('o_pl_16 sixteen states', () {
    final stay = <String, List<String>>{
      'Free': ['Shown 140 times', 'Free plan', 'Plus stays come first when travellers plan a trip to Mukteshwar.', 'Try free for 7 days'],
      'Trial': ['Free until 28 Nov', 'Trial', '8 photos and 6 room types are open now.', 'Manage in Google Play'],
      'Plus': ['Shown 412 times', 'Plus', '9 enquiries this week. Renews on 21 Dec 2026.', 'Manage in Google Play'],
      'Cancelled': ['Plus till 21 Dec 2026', 'Plus', 'After that, you keep 2 photos and 2 room types.', 'Manage in Google Play'],
      'Grace': ['Payment issue', 'Plus', 'Plus keeps working for now.', 'Fix'],
      'OnHold': ['Payment on hold', 'Fix the payment in Google Play first.', 'Fix'],
      'Ended': ['Subscription ended', 'Up to 6 photos and 4 room types are hidden. Nothing is deleted.', 'Subscribe again'],
      'PaymentOff': ['Paid plans are coming', 'Plus will put your stay first in trip plans. Not open yet.'],
    };
    final taxi = <String, List<String>>{
      'Free': ['Free plan', '12 requests this week were for cities you have no route to.', 'Try free for 7 days'],
      'Trial': ['Free until 28 Nov', 'Trial', 'Up to 5 routes are open now.', 'Manage in Google Play'],
      'Plus': ['31 requests on your routes', 'Plus', 'You accepted 12. Renews on 21 Dec 2026.', 'Manage in Google Play'],
      'Cancelled': ['Plus till 21 Dec 2026', 'Plus', 'After that, you keep 1 route.', 'Manage in Google Play'],
      'Grace': ['Payment issue', 'Plus', 'Plus keeps working for now.', 'Fix'],
      'OnHold': ['Payment on hold', 'Fix the payment in Google Play first.', 'Fix'],
      'Ended': ['Subscription ended', 'Extra routes are hidden. Nothing is deleted.', 'Subscribe again'],
      'PaymentOff': ['Paid plans are coming', 'Featured in taxi lists and your turn 2x as often. Not open yet.'],
    };
    for (final e in stay.entries) {
      testWidgets('stay ${e.key}', (t) async {
        await _pump(t, _stay, _card(e.key, extra: _fx[e.key]!));
        _texts(e.value);
      });
    }
    for (final e in taxi.entries) {
      testWidgets('taxi ${e.key}', (t) async {
        await _pump(t, _taxi, _card(e.key, extra: _fx[e.key]!));
        _texts(e.value);
      });
    }
  });

  testWidgets('trial not available: See Plus', (t) async {
    await _pump(t, _taxi, _card('Free', extra: {'weekly': {'requestsNoRoute': 9}}));
    _texts(['Free plan', 'More routes, more requests.', 'See Plus']);
    expect(find.byKey(GateKeys.seePlus), findsOneWidget);
  });

  testWidgets('under 10 or unknown: stay title Free plan, no counter', (t) async {
    await _pump(t, _stay, _card('Free', extra: {'weekly': {'shown': 9}}));
    expect(find.text('Shown 9 times'), findsNothing);
    _texts(['Free plan', 'Plus stays come first when travellers plan a trip to Mukteshwar.', 'See Plus']);
  });

  testWidgets('no city: reach sentence not drawn', (t) async {
    await _pump(t, _stay, _card('Free'), city: null);
    expect(find.textContaining('Plus stays come first'), findsNothing);
  });

  testWidgets('missing counters: Plus + Renews only, no zeros', (t) async {
    await _pump(t, _stay, _card('Plus', extra: {'renewsOn': '2026-12-21'}));
    _texts(['Plus', 'Renews on 21 Dec 2026.']);
    expect(find.textContaining('0 '), findsNothing);
  });

  testWidgets('unknown state: Free look, no button', (t) async {
    await _pump(t, _taxi, _card('Paused'));
    _texts(['Free plan']);
    expect(find.text('See Plus'), findsNothing);
    expect(find.text('Manage in Google Play'), findsNothing);
  });

  testWidgets('admin grant: Plus look, no Google Play button, no Billed', (t) async {
    await _pump(t, _stay, _card('AdminGrant', extra: {'endsAt': '2026-12-21', 'weekly': {'shown': 412, 'enquiries': 9}}));
    _texts(['Shown 412 times', '9 enquiries this week.']);
    expect(find.text('Manage in Google Play'), findsNothing);
    expect(find.textContaining('Billed'), findsNothing);
  });

  testWidgets('payment OFF: no button, no gate key', (t) async {
    await _pump(t, _taxi, _card('PaymentOff'));
    expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
    expect(find.text('See Plus'), findsNothing);
  });

  testWidgets('on hold with carried-over days: Plus till date + Fix', (t) async {
    await _pump(t, _stay, _card('OnHold', extra: {'isPaid': true, 'endsAt': '2026-12-05'}));
    _texts(['Plus till 5 Dec 2026', 'Fix']);
  });

  testWidgets('null card (old server) never crashes', (t) async {
    await _pump(t, _stay, null);
    _texts(['Free plan']);
  });

  testWidgets('wrong types in the card never crash', (t) async {
    for (final v in jsonVariants({'state': 'Plus', 'renewsOn': '2026-12-21', 'weekly': {'shown': 412, 'enquiries': 9}, 'limits': {'routes': 5}})) {
      await _pump(t, _taxi, OwnerPlanCard.maybe(v));
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('Fix and Manage open Google Play', (t) async {
    final c = installPlans(Fx.grace('Stay'));
    await _pump(t, _stay, _card('Grace'));
    await t.tap(find.text('Fix'));
    await t.pump();
    expect(c.manageCalls, 1);
  });

  for (final s in ['Free', 'Plus', 'Ended']) {
    testOwnerSizes('home plan card stay $s', () => _host(HomePlanCard(card: _card(s, extra: _fx[s]!), copy: _stay, city: 'Mukteshwar')));
    testOwnerSizes('home plan card taxi $s', () => _host(HomePlanCard(card: _card(s, extra: _fx[s]!), copy: _taxi)));
  }

  group('render', () {
    useOwnerRenderScale();
    testWidgets('render o_pl_16 board', (t) async {
      final board = Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(children: [
            for (final s in _fx.keys) ...[
              HomePlanCard(card: _card(s, extra: s == 'Free' ? {'trialAvailable': true, 'weekly': {'shown': 140}} : _fx[s]!), copy: _stay, city: 'Mukteshwar'),
              HomePlanCard(card: _card(s, extra: s == 'Free' ? {'weekly': {'requestsNoRoute': 12}} : _fx[s]!), copy: _taxi),
            ],
          ]),
        ),
      );
      await renderPlanFrame(t, 'o_pl_16', board, height: 2400);
      expect(t.takeException(), isNull);
    });
  });
}
