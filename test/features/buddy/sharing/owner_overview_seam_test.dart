import 'dart:async';

import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/sharing/controllers/owner_sharing_controller.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/features/buddy/sharing/sharing_strings.dart';
import 'package:bakhli/features/buddy/sharing/widgets/owner_overview_seam.dart';
import 'package:bakhli/features/buddy/sharing/widgets/trip_delete_flow.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/screens/trip_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'sharing_fixtures.dart';

const _travellers = ValueKey('overview_travellers_card');
const _expenses = ValueKey('overview_expenses_card');

class _Host extends StatefulWidget {
  const _Host({required this.trip});

  final TripModel trip;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => Obx(() {
        final t = widget.trip;
        final x = OwnerOverviewSeam.of(context, t, progressPercent: 100);
        return TripOverviewScreen(
          trip: t,
          parts: allArranged,
          stay: TripOverviewStay.booked,
          onViewPlan: () {},
          onTaxi: (_) {},
          onDone: () {},
          onBack: () {},
          onStay: (_) {},
          subtitle: x.subtitle,
          travellerCount: x.travellerCount,
          extraCards: x.extraCards,
          extraMenuItems: x.extraMenuItems,
          progressLine: x.progressLine,
          showProgress: x.showProgress,
        );
      });
}

Future<void> _pump(WidgetTester t, TripModel trip) async {
  t.view.devicePixelRatio = 2;
  t.view.physicalSize = const Size(784, 1600);
  addTearDown(t.view.reset);
  await t.pumpWidget(app(_Host(trip: trip)));
}

void main() {
  late int calls;
  // Created on the first call, inside the test zone, so pump() runs its microtasks.
  Completer<BuddyResult<TripSharingBlock?>>? pending;
  Completer<BuddyResult<TripSharingBlock?>> answer() => pending ??= Completer();

  setUp(() {
    DS.applyApproved();
    calls = 0;
    pending = null;
    OwnerSharingController.debugFetch = (_) {
      calls++;
      return answer().future;
    };
  });

  tearDown(() {
    OwnerSharingController.debugFetch = null;
    DS.debugReset();
    TripDeleteFlow.debugReset();
    Get.reset();
  });

  testWidgets('owned trip without a sharing block shows both cards and Delete trip on the first frame', (t) async {
    await _pump(t, trip());
    expect(find.byKey(_travellers), findsOneWidget);
    expect(find.byKey(_expenses), findsOneWidget);
    expect(find.text(SharingStrings.inviteFriendsLine), findsOneWidget);
    expect(calls, 1);
    await t.tap(find.byKey(const ValueKey('overview_menu')));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text(SharingStrings.deleteTrip), findsOneWidget);
  });

  testWidgets('the fetch updates the numbers in the same card elements, one fetch only', (t) async {
    await _pump(t, trip());
    final before = t.element(find.byKey(_travellers));
    answer().complete(BuddyOk(sharedBlock()));
    await t.pump();
    await t.pump();

    expect(identical(before, t.element(find.byKey(_travellers))), isTrue);
    expect(find.text(SharingStrings.inviteFriendsLine), findsNothing);
    t.state<_HostState>(find.byType(_Host)).rebuild();
    await t.pump();
    expect(calls, 1);
  });

  testWidgets('a failed fetch keeps the default cards and does not refetch on rebuild', (t) async {
    await _pump(t, trip());
    answer().complete(const BuddyOffline());
    await t.pump();
    for (var i = 0; i < 3; i++) {
      t.state<_HostState>(find.byType(_Host)).rebuild();
      await t.pump();
    }
    expect(calls, 1);
    expect(find.byKey(_travellers), findsOneWidget);
    expect(find.byKey(_expenses), findsOneWidget);
  });

  testWidgets('a 200 answer without any sharing key (old server) hides the cards', (t) async {
    await _pump(t, trip());
    answer().complete(const BuddyOk(null));
    await t.pump();
    await t.pump();
    expect(find.byKey(_travellers), findsNothing);
    expect(find.byKey(_expenses), findsNothing);
  });

  testWidgets('a trip that carries the block renders it without any fetch', (t) async {
    await _pump(t, trip(sharing: sharedBlock()));
    expect(find.byKey(_travellers), findsOneWidget);
    expect(calls, 0);
  });

  test('copyWith keeps sharing; fromJson reads it; the offline copy puts it back', () {
    final t = trip(sharing: sharedBlock());
    expect(t.copyWith(title: 'x').sharing!.viewerCount, 2);
    final noRaw = trip().copyWith(sharing: aloneBlock());
    expect(noRaw.sharing!.travellerCount, 1);
    final withRaw = TripModel.fromJson({
      'id': tripId,
      'cityKey': 1,
      'plan': {'cityKey': 1, 'cityName': 'Dehradun', 'days': <Object>[]},
    }).copyWith(sharing: sharedBlock());
    expect(withRaw.rawWithSharing!['sharing'], isA<Map<String, dynamic>>());
    expect(TripModel.fromJson(withRaw.rawWithSharing!).sharing!.viewerCount, 2);
  });

  test('ownerAlone default is one traveller, no invites, no expenses', () {
    final b = TripSharingBlock.ownerAlone(userId: rahul, ownerName: 'rahul');
    expect(b.travellerCount, 1);
    expect(b.viewerCount, 0);
    expect(b.pendingInvites, 0);
    expect(b.firstTravellers.single.initial, 'R');
    expect(b.expenses.hasExpenses, isFalse);
    expect(TripSharingBlock.ownerAlone(userId: '', ownerName: '').firstTravellers.single.initial, '');
  });
}
