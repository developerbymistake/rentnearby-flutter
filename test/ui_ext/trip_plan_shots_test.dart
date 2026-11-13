import 'dart:async';
import 'dart:io';

import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_summary_model.dart';
import 'package:bakhli/features/trip/widgets/trip_city_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_spot_detail_sheet.dart';
import 'package:bakhli/features/trip/screens/trip_summary_screen.dart';
import 'package:bakhli/features/trip/screens/trip_map_screen.dart';
import 'package:bakhli/features/trip/utils/trip_summary_source.dart';
import 'package:dio/dio.dart';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_spots_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/features/trip/screens/trip_spots_screen.dart';
import 'package:bakhli/features/trip/screens/trip_edit_spot_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_days_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_lifecycle_actions.dart';
import 'package:bakhli/features/trip/widgets/trip_pace_sheet.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_dates_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_leg_impact_dialog.dart';
import 'package:bakhli/features/trip/widgets/trip_update_ask_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../journeys/fake_api.dart';
import '../support/real_phone.dart';

const _dir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\trip-plan';

class _Spots extends TripSpotsController {
  _Spots(super.cityKey, this.seed, {this.mode = 'ok'});
  final List<TripSpotModel> seed;
  final String mode;
  @override
  Future<void> load() async {
    if (mode == 'loading') {
      isLoading.value = true;
      return;
    }
    if (mode == 'error') {
      loadFailed.value = true;
      return;
    }
    if (mode == 'off') {
      plannerOff.value = true;
      return;
    }
    if (mode == 'notready') {
      status.value = TripSpotStatus.notReady;
      return;
    }
    items.assignAll(seed);
    total.value = seed.length;
  }
}

class _Repo implements TripShortlistRepository {
  @override
  Future<TripShortlist> list(String tripId) async => const TripShortlist(items: []);
  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async => [item];
  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async {}
  @override
  Future<void> close(String tripId, String stepKey, {required String reason}) async {}
  @override
  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async =>
      const MarkBookedResult(closedEnquiries: 0, closedShortlist: 0);
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

TripSpotModel _s(String id, String name, String cat, int min, {bool featured = false, int rank = 1, String? area, String? desc}) =>
    TripSpotModel(
      id: id,
      source: 'osm',
      name: name,
      latitude: 29.38,
      longitude: 79.45,
      category: cat,
      visitMinutes: min,
      isFeatured: featured,
      rank: rank,
      area: area,
      description: desc,
    );

final _nainital = const TripCityModel(cityKey: 1, name: 'Nainital', latitude: 29.38, longitude: 79.45);
final _almora = const TripCityModel(cityKey: 2, name: 'Almora', latitude: 29.6, longitude: 79.65);

List<TripSpotModel> _seed() => [
      _s('a', 'Naini Lake', 'lake', 90, featured: true, area: 'Mall Road', desc: 'Boat rides on the green lake.'),
      _s('b', 'Snow View Point', 'viewpoint', 60, featured: true, area: 'Sher Ka Danda', desc: 'Ropeway to Himalayan views.'),
      _s('c', 'Naina Devi Temple', 'temple', 45, featured: true, area: 'Mall Road'),
      _s('d', 'High Altitude Zoo', 'park', 90, area: 'Sher Ka Danda', desc: 'Snow leopards and red pandas.', rank: 2),
      _s('e', 'Sat Tal', 'lake', 120, rank: 2),
      _s('f', 'Hanuman Garhi', 'temple', 40, rank: 2),
      _s('g', 'Tiffin Top', 'viewpoint', 120, rank: 2),
    ];

Future<void> _bootStorage() async {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
    return Directory.systemTemp.createTempSync('tp_gs').path;
  });
  await GetStorage.init();
}

Future<void> _spots(WidgetTester t, String name,
    {double scale = 1,
    Size size = phoneSize,
    String mode = 'ok',
    Set<String> picked = const {},
    bool chain = true,
    int limit = -1,
    String? filter,
    Future<void> Function(WidgetTester t)? then}) async {
  shotsDir = _dir;
  debugDisableShadows = false;
  Get.put<TabConfigController>(_Tabs());
  final c = Get.put<TripSpotsController>(_Spots(1, _seed(), mode: mode), tag: '1');
  c.selected.addAll(picked);
  await pumpPhone(t, const Scaffold(body: SizedBox()), size: size, textScale: scale);
  Get.to(() => const TripSpotsScreen(), arguments: {
    'city': _nainital,
    if (chain) 'cities': [_nainital, _almora],
  });
  await _settle(t);
  if (limit >= 0) c.limit.value = limit;
  if (filter != null) c.filter.value = filter;
  await _settle(t);
  if (then != null) await then(t);
  await shot(t, name);
  expect(t.takeException(), isNull);
  debugDisableShadows = true;
}

Future<TripPlanController> _plan(WidgetTester t, String name,
    {double scale = 1,
    Size size = phoneSize,
    List<int> legs = const [3, 2],
    void Function(TripPlanController c)? setup,
    Future<void> Function(WidgetTester t, TripPlanController c)? then}) async {
  shotsDir = _dir;
  debugDisableShadows = false;
  final sl = TripShortlistController(repo: _Repo(), tripId: () async => 't1', offline: () => false, warn: (_) {});
  Get.put<TripShortlistController>(sl);
  Get.put<TripEnquiryController>(TripEnquiryController());
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  Get.put<TripPlanController>(c, permanent: true);
  c.plan.value = journeyPlan(legs, start: DateTime.now().add(const Duration(days: 10)));
  setup?.call(c);
  await pumpPhone(t, const TripPlanScreen(), size: size, textScale: scale);
  await _settle(t);
  c.planStep.value = 1;
  await _settle(t);
  if (then != null) await then(t, c);
  await shot(t, name);
  t.takeException();
  debugDisableShadows = true;
  return c;
}

BuildContext _ctx(WidgetTester t) => t.element(find.byType(TripPlanScreen));

TripCityModel _cm(int k, String n, {bool popular = false, int spots = 0}) => TripCityModel(
    cityKey: k, name: n, districtName: 'Nainital', stateName: 'Uttarakhand', latitude: 1, longitude: 1, isPopularDestination: popular, spotCount: spots);

class _Catalog extends TripCityCatalog {
  _Catalog(this.list, {this.fail = false});
  final List<TripCityModel> list;
  final bool fail;
  @override
  void warmFromDisk() {}
  @override
  bool get hasData => list.isNotEmpty;
  @override
  Future<List<TripCityModel>> load({bool force = false}) async {
    if (fail) throw DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);
    return list;
  }

  @override
  List<TripCityModel> search(String q) => TripCitySearch.filter(list, q);
  @override
  List<TripCityModel> popular({String? stateName}) => list.where((c) => c.isPopularDestination).toList();
}

List<TripCityModel> _cities() => [
      _cm(1, 'Nainital', popular: true, spots: 24),
      _cm(2, 'Almora', popular: true, spots: 12),
      _cm(3, 'Mussoorie', popular: true, spots: 18),
      _cm(4, 'Kausani', spots: 9),
      _cm(5, 'Munsiyari', spots: 7),
    ];

Future<void> _city(WidgetTester t, String name,
    {double scale = 1,
    Size size = phoneSize,
    List<TripCityModel>? list,
    bool fail = false,
    TripCitySheetMode mode = TripCitySheetMode.start,
    Future<void> Function(WidgetTester t)? then}) async {
  shotsDir = _dir;
  debugDisableShadows = false;
  Get.put<TripCityCatalog>(_Catalog(list ?? _cities(), fail: fail), permanent: true);
  await pumpPhone(t, const Scaffold(body: SizedBox()), size: size, textScale: scale);
  TripCitySheet.pick(t.element(find.byType(Scaffold).first), mode: mode, afterCity: mode == TripCitySheetMode.add ? 'Nainital' : null, inTrip: const {1});
  await _settle(t);
  if (then != null) await then(t);
  await shot(t, name);
  expect(t.takeException(), isNull);
  debugDisableShadows = true;
}

TripSummaryRecord _sumRecord({bool done = false}) => TripSummaryRecord.fromJson({
      'tripId': 't1',
      'title': 'Nainital to Almora',
      'city': 'Nainital',
      'legCities': ['Nainital', 'Almora'],
      'startDate': '2026-11-13',
      'endDate': '2026-11-17',
      'adults': 2,
      'agreedTotal': 9400,
      if (done) 'status': 'completed',
      'days': [
        {'day': 1, 'date': '2026-11-13', 'city': 'Nainital', 'spots': ['Naini Lake', 'Naina Devi', 'Snow View'], 'minutes': 310},
        {'day': 2, 'date': '2026-11-14', 'city': 'Nainital', 'spots': ['Tiffin Top', 'Raj Bhavan', 'Sat Tal'], 'minutes': 460},
        {'day': 4, 'date': '2026-11-16', 'city': 'Almora', 'spots': ['Kasar Devi', 'Bright End Corner'], 'minutes': 240},
      ],
      'nights': [
        {
          'night': 1,
          'date': '2026-11-13',
          'listingName': 'Lakeside Rooms',
          'displayStatus': 'confirmedByBoth',
          'agreedTotal': 6600,
          'roomLines': [
            {'roomName': 'Deluxe', 'units': 1, 'guests': 2}
          ],
          'advanceStatus': 'received',
          'advanceAmount': 1000,
          'confirmedBy': 'both',
          'confirmedAt': '2026-11-10T10:00:00Z',
        },
      ],
      'taxis': [
        {
          'listingName': 'Pradeep Kumar',
          'vehicleTypeName': 'Dzire',
          'days': [1, 2, 3],
          'displayStatus': 'bookedByYou',
          'agreedFare': 2800,
          'tollExtra': true,
          'pickupTime': '09:00',
          'pickupPlace': 'Mall Road',
          'confirmedBy': 'you',
          'confirmedAt': '2026-11-11T10:00:00Z',
        },
      ],
      'arrangements': [
        {'key': 'gettingThere', 'title': 'Getting there', 'state': 'todo', 'detail': 'Haldwani to Nainital · 13 Nov'},
        {'key': 'stay:1', 'title': 'Stay in Nainital', 'state': 'confirmed', 'detail': 'Lakeside Rooms · 3 nights'},
        {'key': 'stay:2', 'title': 'Stay in Almora', 'state': 'asked', 'detail': 'Asked · 1 night'},
        {'key': 'taxi', 'title': 'Local taxi', 'state': 'booked', 'detail': 'Days 1-3 · Dzire'},
        {'key': 'comingBack', 'title': 'Coming back', 'state': 'todo', 'detail': 'Almora to Haldwani · 17 Nov'},
      ],
    });

Future<void> _sum(WidgetTester t, String name,
    {double scale = 1, Size size = phoneSize, Future<TripSummarySnapshot> Function(String)? loader, double scroll = 0}) async {
  shotsDir = _dir;
  debugDisableShadows = false;
  await pumpPhone(
    t,
    TripSummaryScreen(tripId: 't1', loader: loader ?? (_) async => TripSummarySnapshot(_sumRecord()), isGone: (_) => false),
    size: size,
    textScale: scale,
  );
  await _settle(t);
  if (scroll > 0) {
    await t.drag(find.byType(Scrollable).first, Offset(0, -scroll));
    await _settle(t);
  }
  await shot(t, name);
  expect(t.takeException(), isNull);
  debugDisableShadows = true;
}

String _tag(double s, Size z) => '${s.toString().replaceAll('.', '')}_${z.width.toInt()}';

const _sizes = [(1.0, Size(360, 800)), (1.3, Size(360, 800)), (1.0, Size(300, 700))];

void main() {
  setUpAll(() async {
    await _bootStorage();
    await loadRealFonts();
  });
  tearDown(Get.reset);

  for (final (s, z) in _sizes) {
    testWidgets('spots main ${_tag(s, z)}', (t) async {
      await _spots(t, 'sp_main_${_tag(s, z)}', scale: s, size: z, picked: {'a'});
    });
    testWidgets('spots list ${_tag(s, z)}', (t) async {
      await _spots(t, 'sp_list_${_tag(s, z)}', scale: s, size: z, picked: {'a', 'b', 'c'}, then: (t) async {
        final list = find.byType(Scrollable).last;
        await t.drag(list, const Offset(0, -900));
        await _settle(t);
      });
    });
  }
  testWidgets('spots first', (t) async => _spots(t, 'sp_first', chain: false));
  testWidgets('spots loading', (t) async => _spots(t, 'sp_loading', mode: 'loading'));
  testWidgets('spots error', (t) async => _spots(t, 'sp_error', mode: 'error'));
  testWidgets('spots off', (t) async => _spots(t, 'sp_off', mode: 'off'));
  testWidgets('spots notready', (t) async => _spots(t, 'sp_notready', mode: 'notready'));
  testWidgets('spots limit', (t) async => _spots(t, 'sp_limit', picked: {'a', 'b'}, limit: 2));
  testWidgets('spots nofilter', (t) async => _spots(t, 'sp_nofilter', filter: 'museum'));
  testWidgets('spots detail', (t) async => _spots(t, 'sp_detail', picked: {'a'}, then: (t) async {
        TripSpotDetailSheet.show(t.element(find.byType(TripSpotsScreen)), spot: _seed().first, selected: false, locked: false, onToggle: () {});
        await _settle(t);
      }));

  for (final (s, z) in _sizes) {
    testWidgets('plan main ${_tag(s, z)}', (t) async {
      await _plan(t, 'plan_main_${_tag(s, z)}', scale: s, size: z);
    });
    testWidgets('plan edit ${_tag(s, z)}', (t) async {
      await _plan(t, 'plan_edit_${_tag(s, z)}', scale: s, size: z, then: (t, c) async {
        c.editMode.value = true;
        await _settle(t);
      });
    });
  }
  testWidgets('plan scrolled', (t) async {
    await _plan(t, 'plan_more', then: (t, c) async {
      await t.drag(find.byType(ListView).first, const Offset(0, -1400));
      await _settle(t);
    });
  });
  testWidgets('plan offline', (t) async {
    await _plan(t, 'plan_offline', then: (t, c) async {
      c.offline.value = true;
      await _settle(t);
    });
  });
  testWidgets('plan notfound', (t) async {
    await _plan(t, 'plan_notfound', then: (t, c) async {
      c.tripGone.value = true;
      await _settle(t);
    });
  });
  testWidgets('plan error', (t) async {
    await _plan(t, 'plan_error', setup: (c) {
      c.plan.value = null;
      c.openFailed.value = true;
    });
  });
  testWidgets('plan loading', (t) async {
    await _plan(t, 'plan_loading', setup: (c) => c.plan.value = null);
  });
  testWidgets('plan menu', (t) async {
    await _plan(t, 'plan_menu', then: (t, c) async {
      await t.tap(find.byIcon(Icons.more_vert_rounded).first);
      await _settle(t);
    });
  });
  testWidgets('plan legmenu', (t) async {
    await _plan(t, 'plan_legmenu', then: (t, c) async {
      await t.tap(find.byTooltip('More').first);
      await _settle(t);
    });
  });
  testWidgets('plan spotmenu', (t) async {
    await _plan(t, 'plan_spotmenu', then: (t, c) async {
      c.editMode.value = true;
      await _settle(t);
      await t.tap(find.text('Place s1').first);
      await _settle(t);
    });
  });
  testWidgets('plan move', (t) async {
    await _plan(t, 'plan_move', then: (t, c) async {
      TripEditSpotSheet.show(_ctx(t), c.plan.value!.days.first.spots.first.id);
      await _settle(t);
    });
  });
  testWidgets('plan delete', (t) async {
    await _plan(t, 'plan_delete', then: (t, c) async {
      TripLifecycleActions.confirmDelete(_ctx(t), open: 1, confirmed: 1);
      await _settle(t);
    });
  });
  testWidgets('plan rename', (t) async {
    await _plan(t, 'plan_rename', then: (t, c) async {
      await t.tap(find.byIcon(Icons.more_vert_rounded).first);
      await _settle(t);
      await t.tap(find.text('Rename trip'));
      await _settle(t);
    });
  });
  for (final (s, z) in _sizes) {
    testWidgets('summary main ${_tag(s, z)}', (t) async => _sum(t, 'sum_main_${_tag(s, z)}', scale: s, size: z));
    testWidgets('summary more ${_tag(s, z)}', (t) async => _sum(t, 'sum_more_${_tag(s, z)}', scale: s, size: z, scroll: 2900));
  }
  for (final (s, z) in _sizes) {
    testWidgets('city main ${_tag(s, z)}', (t) async => _city(t, 'city_main_${_tag(s, z)}', scale: s, size: z, then: (t) async {
          await t.tap(find.text('Nainital').last);
          await t.tap(find.text('Almora').last);
          await _settle(t);
        }));
  }
  testWidgets('city add', (t) async => _city(t, 'city_add', mode: TripCitySheetMode.add, then: (t) async {
        await t.tap(find.text('Mussoorie').last);
        await _settle(t);
      }));
  testWidgets('city nomatch', (t) async => _city(t, 'city_nomatch', then: (t) async {
        await t.enterText(find.byType(TextField).first, 'Goa');
        await _settle(t);
      }));
  testWidgets('city none', (t) async => _city(t, 'city_none', list: const []));
  testWidgets('city failed', (t) async => _city(t, 'city_failed', list: const [], fail: true));
  testWidgets('plan today', (t) async {
    await _plan(t, 'plan_today', setup: (c) => c.plan.value = journeyPlan(const [3, 2], start: DateTime.now().subtract(const Duration(days: 1))));
  });
  testWidgets('plan more cards', (t) async {
    await _plan(t, 'plan_addcity', then: (t, c) async {
      await t.drag(find.byType(ListView).first, const Offset(0, -3000));
      await _settle(t);
    });
  });
  for (final (s, z) in _sizes) {
    testWidgets('map ${_tag(s, z)}', (t) async {
      await _plan(t, 'map_all_${_tag(s, z)}', scale: s, size: z, then: (t, c) async {
        _fakeViews();
        Get.to(() => const TripMapScreen());
        await _settle(t);
      });
    });
  }
  testWidgets('map day', (t) async {
    await _plan(t, 'map_day', then: (t, c) async {
      _fakeViews();
      Get.to(() => const TripMapScreen());
      await _settle(t);
      final chip = find.text('Day 1').first;
      await t.ensureVisible(chip);
      await _settle(t);
      await t.tap(chip, warnIfMissed: false);
      await _settle(t);
      await _settle(t);
    });
  });
  testWidgets('summary itinerary', (t) async => _sum(t, 'sum_days', scroll: 800));
  testWidgets('summary done', (t) async => _sum(t, 'sum_done', loader: (_) async => TripSummarySnapshot(_sumRecord(done: true))));
  testWidgets('summary loading', (t) async => _sum(t, 'sum_loading', loader: (_) => Completer<TripSummarySnapshot>().future));
  testWidgets('summary empty', (t) async =>
      _sum(t, 'sum_empty', loader: (_) async => TripSummarySnapshot(TripSummaryRecord.fromJson({'tripId': 't1', 'city': 'Nainital'}))));
  testWidgets('summary error', (t) async => _sum(t, 'sum_error',
      loader: (_) async => throw DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError)));

  for (final (s, z) in _sizes) {
    testWidgets('sheet pace ${_tag(s, z)}', (t) async {
      await _plan(t, 'sh_pace_${_tag(s, z)}', scale: s, size: z, then: (t, c) async {
        TripPaceSheet.show(_ctx(t));
        await _settle(t);
      });
    });
    testWidgets('sheet days ${_tag(s, z)}', (t) async {
      await _plan(t, 'sh_days_${_tag(s, z)}', scale: s, size: z, then: (t, c) async {
        TripDaysSheet.show(_ctx(t));
        await _settle(t);
      });
    });
  }

  testWidgets('plan step2', (t) async {
    await _plan(t, 'plan_step2', then: (t, c) async {
      c.planStep.value = 2;
      await _settle(t);
    });
  });
  testWidgets('plan empty', (t) async {
    await _plan(t, 'plan_empty', setup: (c) => c.plan.value = _withSpots(journeyPlan(const [3, 2]), (_) => 0));
  });
  testWidgets('plan dayfull', (t) async {
    await _plan(t, 'plan_dayfull', setup: (c) => c.plan.value = _withSpots(journeyPlan(const [3, 2]), (d) => d == 1 ? 6 : 1), then: (t, c) async {
      c.editMode.value = true;
      await _settle(t);
    });
  });
  testWidgets('plan planfail', (t) async {
    await _plan(t, 'plan_planfail', setup: (c) => c.planFailed.value = true);
  });
  testWidgets('plan complete', (t) async {
    await _plan(t, 'plan_complete', setup: (c) => c.plan.value = journeyPlan(const [3, 2], start: DateTime.now().subtract(const Duration(days: 4))));
  });
  testWidgets('plan update', (t) async {
    await _plan(t, 'plan_update', setup: (c) => c.needsUpdate.value = true);
  });
  testWidgets('plan legremove', (t) async {
    await _plan(t, 'plan_legremove', then: (t, c) async {
      await t.tap(find.byTooltip('More').last);
      await _settle(t);
      await t.tap(find.text('Remove city').last, warnIfMissed: false);
      await _settle(t);
    });
  });
  testWidgets('plan legimpact', (t) async {
    await _plan(t, 'plan_legimpact', then: (t, c) async {
      final start = c.settings.startDate ?? DateTime.now();
      TripLegImpactDialog.show(_ctx(t),
          title: 'Change days in City 1?',
          body: 'These bookings are for City 1.',
          impact: LegImpact(booked: [_enq('e1', TripEnquiryKinds.stay, start, display: 'confirmedByBoth')], open: [_enq('e2', TripEnquiryKinds.stay, start, day: 2)]),
          applyLabel: 'Cancel and change',
          keepLabel: 'Change, keep bookings',
          backLabel: 'Keep days',
          offline: false);
      await _settle(t);
    });
  });
  testWidgets('plan updateask', (t) async {
    await _plan(t, 'plan_updateask', then: (t, c) async {
      final start = c.settings.startDate ?? DateTime.now();
      TripUpdateAskSheet.show(_ctx(t), SettingsSaveResult(saved: true, openAffected: [_enq('e1', TripEnquiryKinds.stay, start), _enq('e2', TripEnquiryKinds.stay, start, day: 4, leg: 2)]));
      await _settle(t);
    });
  });
  testWidgets('sheet days min', (t) async {
    await _plan(t, 'sh_days_min', setup: (c) => c.plan.value = _withSpots(journeyPlan(const [3, 2]), (_) => 6), then: (t, c) async {
      TripDaysSheet.show(_ctx(t));
      await _settle(t);
    });
  });
  testWidgets('sheet dates', (t) async {
    await _plan(t, 'sh_dates', then: (t, c) async {
      TripDatesSheet.edit(_ctx(t));
      await _settle(t);
    });
  });
  testWidgets('sheet dates new', (t) async {
    await _plan(t, 'sh_dates_new', setup: (c) => c.plan.value = journeyPlan(const [3, 2], start: DateTime.now().subtract(const Duration(days: 20))), then: (t, c) async {
      TripDatesSheet.ensure(_ctx(t), heading: 'Pick new dates');
      await _settle(t);
    });
  });
  testWidgets('map travel', (t) async {
    await _plan(t, 'map_travel', then: (t, c) async {
      _fakeViews();
      Get.to(() => const TripMapScreen());
      await _settle(t);
      final chip = find.text('Day 4').first;
      await t.ensureVisible(chip);
      await _settle(t);
      await t.tap(chip, warnIfMissed: false);
      await _settle(t);
      await _settle(t);
    });
  });
}

TripPlan _withSpots(TripPlan p, int Function(int day) count) => TripPlan(
      legs: p.legs,
      days: [
        for (final d in p.days) TripDay(day: d.day, leg: d.leg, spots: [for (var i = 0; i < count(d.day); i++) journeySpot('s${d.day}_$i')]),
      ],
      settings: p.settings,
    );

TripEnquiryModel _enq(String id, String kind, DateTime start, {int day = 1, int? leg, String display = 'asked'}) => TripEnquiryModel.fromJson(
    enquiryJson(id: id, kind: kind, status: display == 'asked' ? TripEnquiryStatuses.asked : TripEnquiryStatuses.confirmedByBoth, start: start, day: day, cityLeg: leg, displayStatus: display));

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

void _fakeViews() {
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(SystemChannels.platform_views, (call) async => call.method == 'create' ? 0 : null);
  for (var i = 0; i < 8; i++) {
    m.setMockMethodCallHandler(MethodChannel('plugins.flutter.io/maplibre_gl_$i'), (call) async => null);
  }
}
