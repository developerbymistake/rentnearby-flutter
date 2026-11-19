import 'package:bakhli/features/taxi/requests/controllers/driver_bookings_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_rating_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_requests_controller.dart';
import 'package:bakhli/features/taxi/requests/data/driver_request_repository.dart';
import 'package:bakhli/features/taxi/requests/driver_bookings_screen.dart';
import 'package:bakhli/features/taxi/requests/driver_rating_screen.dart';
import 'package:bakhli/features/taxi/requests/driver_request_detail_screen.dart';
import 'package:bakhli/features/taxi/requests/driver_requests_screen.dart';
import 'package:bakhli/features/taxi/requests/driver_ring_screen.dart';
import 'package:bakhli/features/taxi/requests/models/driver_request_models.dart';
import 'package:bakhli/features/trip/controllers/trip_taxi_request_controller.dart';
import 'package:bakhli/features/trip/models/taxi_request_models.dart';
import 'package:bakhli/features/trip/screens/trip_taxi_request_screen.dart';
import 'package:bakhli/features/trip/screens/trip_taxi_request_status_screen.dart';
import 'package:bakhli/features/trip/utils/taxi_result.dart';
import 'package:bakhli/features/trip/widgets/taxi_request/taxi_day_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../features/taxi_request/taxi_request_controller_fakes.dart';
import '../support/five_sizes.dart';
import '../support/real_phone.dart';

const _scale = String.fromEnvironment('UI_SCALE', defaultValue: 'normal');
const _checkSizes = [Size(320, 568), Size(360, 640), Size(411, 891), Size(600, 960)];

Map<String, dynamic> _j(String name) => sampleJson(name);

const _days = [
  ('Nainital', ['Naini Lake', 'Snow View', 'Eco Cave Gardens'], 25),
  ('Nainital', ['Naina Devi Temple', 'Tiffin Top', 'Mall Road'], 30),
  ('Nainital', ['Bhimtal Lake', 'Sattal', 'Hanuman Garhi'], 40),
  ('Ranikhet', ['Chaubatia Gardens', 'Jhula Devi Temple', 'Golf Course'], 18),
  ('Kausani', ['Tea Garden', 'Anasakti Ashram', 'Baijnath Temple'], 22),
  ('Almora', ['Kasar Devi', 'Chitai Golu Temple', 'Bright End Corner'], 20),
  ('Almora', ['Jageshwar Dham', 'Binsar Sanctuary'], 55),
  ('Jim Corbett', ['Corbett Museum', 'Garjia Temple', 'Kosi River'], 28),
  ('Jim Corbett', ['Corbett Falls', 'Sitabani'], 24),
];

final List<TaxiRequestDayRow> _rows = [
  for (var i = 0; i < _days.length; i++)
    TaxiRequestDayRow(
      day: i + 1,
      leg: _days.indexWhere((d) => d.$1 == _days[i].$1) + 1,
      city: _days[i].$1,
      places: _days[i].$2,
      km: _days[i].$3,
    ),
];

TripTaxiRequestController _reqController(FakeTaxiRepo repo) {
  var n = 0;
  return TripTaxiRequestController(
    repo: repo,
    enquiries: FakeEnquiries(),
    realtime: null,
    refreshPlan: (_) async => true,
    onLegacyClosed: () {},
    newClientId: () => 'client-${++n}',
  );
}

class _DriverRepo extends DriverRequestRepository {
  Map<String, dynamic> detail = _j('driver_offer_detail_ringing.json');
  Map<String, dynamic> list = _j('driver_offer_list.json');

  @override
  Future<TaxiResult<DriverOfferList>> offers({String? cursor}) async => TaxiOk(DriverOfferList.fromJson(list));

  @override
  Future<TaxiResult<DriverOffer>> offer(String offerId) async => TaxiOk(DriverOffer.fromJson(detail));

  @override
  Future<TaxiResult<DriverBookings>> bookings(DateTime from, DateTime to) async =>
      TaxiOk(DriverBookings.fromJson(_j('driver_bookings.json')));

  @override
  Future<TaxiResult<DriverRating>> rating() async => TaxiOk(DriverRating.fromJson(_j('driver_rating.json')));
}

typedef _Act = Future<void> Function(WidgetTester tester);

class _Frame {
  const _Frame(this.name, this.build, [this.act]);
  final String name;
  final Widget Function() build;
  final _Act? act;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _settle(tester);
}

_Act _keys(List<String> keys) => (tester) async {
      for (final k in keys) {
        await _tapKey(tester, k);
      }
    };

Widget _request({FakeTaxiRepo? repo}) => TripTaxiRequestScreen(
      controller: _reqController(repo ?? FakeTaxiRepo()),
      tripId: 't1',
      rows: _rows,
      onSent: (_) {},
      onTryAnotherCity: () {},
      onBack: () {},
    );

Widget _status(Map<String, dynamic> json) {
  final repo = FakeTaxiRepo();
  final req = TaxiRequest.fromJson(json);
  repo.getAnswer = (_) => TaxiOk(req);
  return TripTaxiRequestStatusScreen(
    requestId: json['id'] as String,
    controller: _reqController(repo),
    onDone: () {},
    onOpenRequest: ({required keepChoices}) {},
    onCall: (_) async {},
    onBack: () {},
  );
}

Map<String, dynamic> _s(String name, [Map<String, dynamic> change = const {}]) => {..._j(name), ...change};

Map<String, dynamic> _firstDriverOnly(Map<String, dynamic> base) => {...base, 'drivers': [(base['drivers'] as List).first]};

Widget _detail(Map<String, dynamic> json) {
  final repo = _DriverRepo()..detail = json;
  return DriverRequestDetailScreen(
    offerId: 'a1b2c3d4-0001-4a00-8000-000000000001',
    controller: DriverRequestsController(repo: repo, now: () => DateTime.utc(2026, 12, 10, 9, 43)),
    onBack: () {},
    onCall: (_) async {},
    onOpenBookings: () {},
  );
}

final _frames = <_Frame>[
  _Frame('21_request_taxi_all_on', _request, _keys(['taxi_day_switch_3', 'taxi_day_switch_7', 'taxi_day_switch_9'])),
  _Frame('22_all_off', _request, _keys(['taxi_pickup_switch', 'taxi_sightseeing_switch', 'taxi_drop_switch'])),
  _Frame('23_pickup_only', _request, _keys(['taxi_sightseeing_switch', 'taxi_drop_switch', 'taxi_pickup_6377270'])),
  _Frame('24_sightseeing_only', _request,
      _keys(['taxi_pickup_switch', 'taxi_drop_switch', 'taxi_day_switch_3', 'taxi_day_switch_7', 'taxi_day_switch_9'])),
  _Frame('25_drop_only', _request, _keys(['taxi_pickup_switch', 'taxi_sightseeing_switch'])),
  _Frame('26_pickup_and_drop', _request, _keys(['taxi_sightseeing_switch', 'taxi_pickup_6377270'])),
  _Frame('27_all_on_ready', _request,
      _keys(['taxi_day_switch_3', 'taxi_day_switch_7', 'taxi_day_switch_9', 'taxi_pickup_6377270'])),
  _Frame(
    '28_empty_pickup_list',
    () => _request(
      repo: FakeTaxiRepo()
        ..placesAnswer = TaxiOk(TaxiPickupPlaces.fromJson({
          ..._j('pickup_places.json'),
          'firstCity': {'cityKey': 1, 'name': 'Mukteshwar'},
          'pickup': <Object>[],
        })),
    ),
    _keys(['taxi_sightseeing_switch', 'taxi_drop_switch']),
  ),
  _Frame('29_finding_driver', () => _status(_s('taxi_request_finding.json'))),
  _Frame('30_finding_driver_waiting', () => _status(_s('taxi_request_waiting.json'))),
  _Frame('31_collecting', () => _status(_firstDriverOnly(_s('taxi_request_collecting.json')))),
  _Frame('32_collecting_two_drivers', () => _status(_s('taxi_request_collecting.json'))),
  _Frame('33_selected', () => _status(_s('taxi_request_selected.json'))),
  _Frame('34_booked', () => _status(_s('taxi_request_booked.json'))),
  _Frame('35_in_progress', () => _status(_s('taxi_request_in_progress.json'))),
  _Frame('36_rate_driver', () => _status(_s('taxi_request_rate.json'))),
  _Frame(
      '37_thank_you',
      () => _status(_s('taxi_request_rate.json', {
            'state': 'Completed',
            'view': 'Done',
            'rating': {'stars': 4, 'ratedAt': '2026-12-22T10:00:00Z'},
          }))),
  _Frame('38_cancel_booking', () => _status(_s('taxi_request_booked.json')), (tester) async {
    await _tapKey(tester, 'cancel_booking');
    await tester.pump(const Duration(milliseconds: 400));
  }),
  _Frame('39_all_drivers_busy', () => _status(_s('taxi_request_busy.json'))),
  _Frame('40_no_reply', () => _status(_s('taxi_request_no_reply.json'))),
  _Frame(
    '41_ringing',
    () => DriverRingScreen(
      offerId: 'a1b2c3d4-0001-4a00-8000-000000000001',
      controller: DriverRequestsController(repo: _DriverRepo(), now: () => DateTime.utc(2026, 12, 10, 9, 40)),
      onAccepted: (_) {},
      onClose: () {},
    ),
  ),
  _Frame(
    '43_requests_list',
    () => DriverRequestsScreen(
      controller: DriverRequestsController(repo: _DriverRepo(), now: () => DateTime.utc(2026, 12, 10, 9, 43)),
      onOpenOffer: (_) {},
      onBack: () {},
    ),
  ),
  _Frame('44_request_details', () => _detail(_j('driver_offer_detail_ringing.json'))),
  _Frame('45_waiting_for_traveller',
      () => _detail({..._j('driver_offer_detail_selected.json'), 'state': 'Accepted', 'confirmBy': null, 'datesConflict': null})),
  _Frame('46_booking_request', () => _detail({..._j('driver_offer_detail_selected.json'), 'datesConflict': null})),
  _Frame('47_dates_already_booked', () => _detail(_j('driver_offer_detail_selected.json'))),
  _Frame(
    '48_my_bookings',
    () => DriverBookingsScreen(
      controller: DriverBookingsController(repo: _DriverRepo(), now: () => DateTime(2026, 12, 10), onChanged: () {}),
      onCall: (_) {},
    ),
  ),
  _Frame(
    '49_withdraw',
    () => DriverBookingsScreen(
      controller: DriverBookingsController(repo: _DriverRepo(), now: () => DateTime(2026, 12, 10), onChanged: () {}),
      onCall: (_) {},
    ),
    (tester) async {
      await _tapKey(tester, 'booking_withdraw_b00c1e55-0001-4b00-8000-000000000001');
      await tester.pump(const Duration(milliseconds: 400));
    },
  ),
  _Frame('50_my_rating', () => DriverRatingScreen(controller: DriverRatingController(repo: _DriverRepo()))),
];

Future<void> _show(WidgetTester tester, _Frame f, Size size) async {
  await pumpAtSize(tester, f.build(), size);
  await _settle(tester);
  await f.act?.call(tester);
  await settlePhone(tester);
}

ScrollPosition? _mainScroll(WidgetTester tester) {
  ScrollPosition? best;
  for (final e in find.byType(Scrollable).evaluate()) {
    final p = (e as StatefulElement).state as ScrollableState;
    final pos = p.position;
    if (pos.axis != Axis.vertical || pos.maxScrollExtent <= 0) continue;
    if (best == null || pos.maxScrollExtent > best.maxScrollExtent) best = pos;
  }
  return best;
}

Future<void> _scrollAll(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  for (var i = 0; i < scrollables.evaluate().length; i++) {
    final state = tester.state<ScrollableState>(scrollables.at(i));
    if (state.position.axis != Axis.vertical) continue;
    state.position.jumpTo(state.position.maxScrollExtent);
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  shotsDir = r'F:\Dhasu\TaxiRequest_resume\evidence\ui';
  tearDown(Get.reset);

  for (final f in _frames) {
    testWidgets('render ${f.name} 360x800 $_scale', (tester) async {
      await _show(tester, f, phoneSize);
      expect(tester.takeException(), isNull);
      await shot(tester, 'p2_${f.name}_360x800_$_scale');
    });

    testWidgets('render ${f.name} pages $_scale', (tester) async {
      await _show(tester, f, phoneSize);
      final position = _mainScroll(tester);
      if (position == null) return;
      final pages = <double>[];
      for (var o = 0.0; o < position.maxScrollExtent + 600; o += 600) {
        pages.add(o);
      }
      for (var i = 0; i < pages.length && i < 12; i++) {
        position.jumpTo(pages[i].clamp(0, position.maxScrollExtent));
        await tester.pump(const Duration(milliseconds: 100));
        await shot(tester, 'p2_${f.name}_page${i}_$_scale');
      }
      expect(tester.takeException(), isNull);
    });

    for (final size in _checkSizes) {
      testWidgets('overflow ${f.name} ${sizeLabel(size)} $_scale', (tester) async {
        await _show(tester, f, size);
        expect(tester.takeException(), isNull);
        await _scrollAll(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
