// JT-A-SK-1: Trip overview cards from the first frame (owner-reported defect, FX-01 with FB-01).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bakhli/design/tokens/design_scale.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/buddy/sharing/controllers/owner_sharing_controller.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/features/buddy/sharing/widgets/owner_overview_seam.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/trip_today_cache.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/screens/trip_overview_screen.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../features/buddy/sharing/sharing_fixtures.dart' as fx;
import '../features/trip/support/engine_rig.dart';

const _travellers = ValueKey('overview_travellers_card');
const _expenses = ValueKey('overview_expenses_card');

// Old server shape: create / update bodies carry no `sharing` key.
class _OldServer implements HttpClientAdapter {
  _OldServer(this.trip);

  final Map<String, dynamic> trip;
  int puts = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final json = {Headers.contentTypeHeader: [Headers.jsonContentType]};
    if (o.method.toUpperCase() == 'PUT' && o.path == '/trips/t1') {
      puts++;
      final body = Map<String, dynamic>.from(o.data is String ? jsonDecode(o.data as String) as Map : o.data as Map);
      return ResponseBody.fromString(jsonEncode({'status': '200', 'code': 200, 'data': {...trip, 'plan': body['plan']}}), 200, headers: json);
    }
    return ResponseBody.fromString(jsonEncode({'status': '200', 'code': 200, 'data': trip}), 200, headers: json);
  }

  @override
  void close({bool force = false}) {}
}

Widget _overview(TripPlanController c) => fx.app(Builder(
      builder: (context) => Obx(() {
        final t = c.trip.value!;
        final x = OwnerOverviewSeam.of(context, t, progressPercent: 50);
        return TripOverviewScreen(
          trip: t,
          parts: fx.allArranged,
          stay: TripOverviewStay.booked,
          onViewPlan: () {},
          onTaxi: (_) {},
          onDone: () {},
          onBack: () {},
          onStay: (_) {},
          extraCards: x.extraCards,
          extraMenuItems: x.extraMenuItems,
          travellerCount: x.travellerCount,
        );
      }),
    ));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late int fetches;
  Completer<BuddyResult<TripSharingBlock?>>? pending;
  Completer<BuddyResult<TripSharingBlock?>> answer() => pending ??= Completer();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (call) async => Directory.systemTemp.createTempSync('jt_sk1').path);
    await GetStorage.init();
  });

  setUp(() {
    DS.applyApproved();
    fetches = 0;
    pending = null;
    StorageService.clearTripCache('t1');
    StorageService.clearTripPending('t1');
    OwnerSharingController.debugFetch = (_) {
      fetches++;
      return answer().future;
    };
  });

  tearDown(() {
    OwnerSharingController.debugFetch = null;
    DS.debugReset();
    Get.reset();
  });

  Future<void> pumpPhone(WidgetTester t, Widget w) async {
    t.view.devicePixelRatio = 2;
    t.view.physicalSize = const Size(784, 1600);
    addTearDown(t.view.reset);
    await t.pumpWidget(w);
  }

  testWidgets('create -> overview first frame -> fetch -> save -> offline copy -> re-entry', (t) async {
    final plan = enginePlan([[2, 2]]);
    final server = engineTripJson(plan);
    ApiService.init();
    final api = _OldServer(server);
    ApiService.dio.httpClientAdapter = api;

    // 1. Create answer without `sharing`: both cards on the first frame, one fetch.
    final c = engineRig(plan);
    c.trip.value = TripModel.fromJson(server);
    expect(c.trip.value!.sharing, isNull);
    await pumpPhone(t, _overview(c));
    expect(find.byKey(_travellers), findsOneWidget);
    expect(find.byKey(_expenses), findsOneWidget);
    expect(fetches, 1);

    // 2. The one fetch lands: same card element, numbers change.
    final card = t.element(find.byKey(_travellers));
    answer().complete(BuddyOk(fx.sharedBlock(expenses: const TripExpenseCard(hasExpenses: true, spent: 900, myShare: 300))));
    await t.pump();
    await t.pump();
    expect(identical(card, t.element(find.byKey(_travellers))), isTrue);
    expect(fetches, 1);

    // 3. A plan save whose answer has no `sharing` keeps the block the trip already holds.
    c.trip.value = c.trip.value!.copyWith(sharing: OwnerSharingController.of('t1')!.sharing.value);
    c.plan.value = plan.copyWith(days: [plan.days[1].copyWith(spots: [...plan.days[1].spots, ...plan.days[0].spots]), plan.days[0].copyWith(spots: const []), ...plan.days.skip(2)]);
    await t.runAsync(() => c.saveNow());
    await t.pump();
    expect(api.puts, 1);
    expect(c.trip.value!.sharing, isNotNull, reason: 'save answer without sharing keeps the known block');
    expect(find.byKey(_travellers), findsOneWidget);
    expect(find.byKey(_expenses), findsOneWidget);

    // 4. Offline copy written after the save carries the block.
    TripTodayCache.saveTrip(c.trip.value!);
    expect(TripTodayCache.trip('t1')?.sharing?.expenses.hasExpenses, isTrue);

    // 5. Leave and come back (controller released): cards from the first frame again.
    OwnerOverviewSeam.release('t1');
    await pumpPhone(t, const SizedBox());
    await pumpPhone(t, _overview(c));
    expect(find.byKey(_travellers), findsOneWidget);
    expect(find.byKey(_expenses), findsOneWidget);
  });

  testWidgets('app restart: a new controller shows the cards before the GET completes', (t) async {
    final plan = enginePlan([[2]]);
    final c = engineRig(plan);
    c.trip.value = TripModel.fromJson(engineTripJson(plan));
    await pumpPhone(t, _overview(c));
    expect(find.byKey(_travellers), findsOneWidget);
    expect(find.byKey(_expenses), findsOneWidget);
    expect(pending!.isCompleted, isFalse);
  });

  testWidgets('network failure keeps the default cards and does not loop on rebuilds', (t) async {
    final plan = enginePlan([[2]]);
    final c = engineRig(plan);
    c.trip.value = TripModel.fromJson(engineTripJson(plan));
    await pumpPhone(t, _overview(c));
    answer().complete(const BuddyOffline());
    await t.pump();
    c.trip.value = c.trip.value!.copyWith(title: 'renamed');
    await t.pump();
    expect(fetches, 1);
    expect(find.byKey(_travellers), findsOneWidget);
  });

  testWidgets('an older server (200 without sharing) hides the cards so no 404 route is reachable', (t) async {
    final plan = enginePlan([[2]]);
    final c = engineRig(plan);
    c.trip.value = TripModel.fromJson(engineTripJson(plan));
    await pumpPhone(t, _overview(c));
    answer().complete(const BuddyOk(null));
    await t.pump();
    await t.pump();
    expect(find.byKey(_travellers), findsNothing);
    expect(find.byKey(_expenses), findsNothing);
  });
}
