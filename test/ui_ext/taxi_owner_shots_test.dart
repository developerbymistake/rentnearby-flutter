import 'dart:async';
import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_taxi_owner.dart';
import 'package:bakhli/features/taxi/leads/trip_fare_sheet.dart';
import 'package:bakhli/features/taxi/leads/trip_leads_controller.dart';
import 'package:bakhli/features/taxi/leads/trip_leads_screen.dart';
import 'package:bakhli/features/taxi/models/taxi_owner_model.dart';
import 'package:bakhli/features/taxi/models/taxi_vehicle_type_model.dart';
import 'package:bakhli/features/taxi/setup/my_taxi_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_routes_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_controller.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_hub_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_submit_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_vehicle_screen.dart';
import 'package:bakhli/features/taxi/taxi_option_sets.dart';
import 'package:bakhli/features/taxi/taxi_vehicle_types_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';

class _Auth extends JAuth {
  _Auth({this.taxis = true});
  final bool taxis;
  @override
  bool get taxisEnabled {
    user.value;
    return taxis;
  }

  @override
  Future<void> refreshProfile() async {}
}

class _Plan extends PlanController {
  @override
  // ignore: must_call_super
  void onInit() {
    myPlan.value = const MyPlanModel(paymentEnabled: true, featureKey: 'Taxi');
  }
}

class _Taxi extends TaxiSetupController {
  _Taxi(this.model, {this.fail = false, this.hang = false});
  final TaxiOwnerModel? model;
  final bool fail;
  final bool hang;

  @override
  Future<bool> load() {
    if (hang) {
      isLoading.value = true;
      return Completer<bool>().future;
    }
    if (fail) {
      loadFailed.value = true;
      return Future.value(false);
    }
    taxi.value = model;
    hasLoaded.value = true;
    return Future.value(true);
  }
}

class _Types extends TaxiVehicleTypesController {
  _Types({this.loading = false, this.failed = false});
  final bool loading;
  final bool failed;
  @override
  // ignore: must_call_super
  void onInit() {
    isLoading.value = loading;
    loadFailed.value = failed;
    if (loading || failed) return;
    types.value = const [
      TaxiVehicleTypeModel(id: 'v0', name: 'Swift Dzire', category: 'Sedan', defaultSeats: 4, sortOrder: 1),
      TaxiVehicleTypeModel(id: 'v2', name: 'Toyota Etios', category: 'Sedan', defaultSeats: 4, sortOrder: 2),
      TaxiVehicleTypeModel(id: 'v3', name: 'Maruti Ertiga', category: 'MUV', defaultSeats: 7, sortOrder: 1),
      TaxiVehicleTypeModel(id: 'v1', name: 'Innova Crysta', category: 'MUV', defaultSeats: 7, sortOrder: 2),
      TaxiVehicleTypeModel(id: 'v4', name: 'Force Traveller', category: 'TempoTraveller', defaultSeats: 12, sortOrder: 1),
    ];
  }

  @override
  Future<void> load() async {}
}

class _Notif extends GetxService implements NotificationService {
  @override
  Future<void> onInit() async {
    super.onInit();
  }

  @override
  Future<bool> isPermissionDenied() async => true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Leads extends TripLeadsController {
  _Leads(this.byBucket, {this.fail = false, this.disabled = false, this.hang = false, int news = 0}) {
    newCount.value = news;
  }
  final Map<String, List<TripEnquiryModel>> byBucket;
  final bool fail;
  final bool disabled;
  final bool hang;

  @override
  void reset() {}
  @override
  Future<void> loadBadge({bool force = false}) async {}
  @override
  Future<void> refreshList() async {}
  @override
  Future<void> loadMore() async {}
  @override
  Future<String?> bucketFor(String enquiryId) async => null;
  @override
  Future<void> selectBucket(String value) async {
    bucket.value = value;
    await load();
  }

  @override
  Future<void> load() async {
    if (hang) {
      loading.value = true;
      return;
    }
    failed.value = fail;
    executionDisabled.value = disabled;
    items.value = fail ? [] : (byBucket[bucket.value] ?? []);
  }
}

TaxiRouteModel _route(String id, String to, int fare, String trip, {String from = 'Haldwani'}) => TaxiRouteModel(
      id: id,
      routeIndex: 0,
      fromName: from,
      fromLatitude: 29.2,
      fromLongitude: 79.5,
      toName: to,
      toLatitude: 29.4 + id.length * 0.01 + fare / 100000,
      toLongitude: 79.6,
      fare: fare,
      tripType: trip,
    );

const _ten = ['Nainital', 'Almora', 'Bhimtal', 'Ranikhet', 'Mukteshwar', 'Kausani', 'Kathgodam', 'Pantnagar', 'Jim Corbett', 'Delhi'];

TaxiOwnerModel taxiModel({
  String status = TaxiStatus.draft,
  int percent = 0,
  bool step1 = false,
  bool identity = false,
  bool routes = false,
  bool tenRoutes = false,
  int? rate,
  int? km,
  bool available = true,
  int reports = 0,
  String? reason,
  bool empty = false,
  bool noSeats = false,
  String? plate = 'UK 07 TA 1234',
  bool photo = true,
  String phone = '9876543210',
  String? whatsApp,
}) =>
    TaxiOwnerModel(
      id: 'o1',
      status: status,
      percent: percent,
      step1Done: step1,
      routesDone: routes || tenRoutes,
      vehicleTypeId: empty ? null : 'v1',
      vehicleTypeName: empty ? null : 'Innova Crysta',
      seats: empty || noSeats ? null : 7,
      plateDisplay: empty ? null : plate,
      platePhotoUrl: empty || !photo ? null : 'http://localhost/plate.jpg',
      contactPhone: phone,
      whatsAppNumber: whatsApp,
      latitude: 29.2,
      longitude: 79.5,
      cityName: 'Haldwani',
      districtName: 'Nainital',
      minFare: routes || tenRoutes ? 900 : null,
      isAvailable: available,
      rejectedReason: reason,
      slug: 'uk07',
      pendingReportCount: reports,
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 2)),
      hasDrivingLicence: identity,
      hasDateOfBirth: identity,
      localDayRate: rate,
      localDayKm: km ?? (rate == null ? null : 120),
      routes: tenRoutes
          ? [for (var i = 0; i < 10; i++) _route('r$i', _ten[i], 900 + i * 300, i.isEven ? 'OneWay' : 'RoundTrip')]
          : routes
              ? [
                  _route('r1', 'Nainital', 900, 'OneWay'),
                  _route('r2', 'Almora', 2600, 'RoundTrip'),
                  _route('r3', 'Delhi', 6500, 'OneWay', from: 'Kathgodam'),
                ]
              : const [],
    );

final _live = taxiModel(status: TaxiStatus.approved, percent: 100, step1: true, identity: true, routes: true, rate: 2500);

String _d(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

TripEnquiryModel lead(
  String id, {
  required String status,
  required String display,
  String guest = 'Rahul Sharma',
  String city = 'Nainital',
  bool urgent = false,
  String? phone = '9876543210',
  String text = '',
  int start = 4,
  int days = 3,
  int? driverFare,
  int? agreedFare,
  int left = 2,
  List<String> spots = const ['Naini Lake', 'Snow View', 'Tiffin Top', 'Bhimtal'],
}) =>
    TripEnquiryModel.fromJson({
      'id': id,
      'kind': 'Taxi',
      'listingId': 'o1',
      'listingName': 'UK 07 TA 1234',
      'status': status,
      'displayStatus': display,
      'isUrgent': urgent,
      'checkIn': _d(start),
      'checkOut': _d(start + days),
      'isSegment': text.isNotEmpty,
      'context': {
        'city': city,
        'adults': 4,
        'text': text,
        'pickupTime': '08:00',
        'pickupPlace': 'Haldwani bus stand',
        'days': [
          for (var i = 0; i < days; i++)
            {'day': i + 1, 'date': _d(start + i), 'minutes': 390 - i * 60, 'spots': i == 0 ? spots : ['Bhimtal', 'Sattal']},
        ],
      },
      'traveller': {'id': 't$id', 'name': guest, 'phone': phone},
      'taxi': {'listedRate': 2500, 'driverFare': driverFare, 'agreedFare': agreedFare, 'fareEditsLeft': left},
    });

void base({bool correct = false, bool taxis = true}) {
  Get.reset();
  (Get.put<LocationController>(JLoc()) as JLoc).userLocation.value = const LatLng(29.2, 79.5);
  final auth = Get.put<AuthController>(_Auth(taxis: taxis));
  auth.user.value = UserModel.fromJson({'id': 'u1', 'phoneNumber': '9876543210', 'name': 'Pradeep Kumar', 'createdAt': '2026-01-01T00:00:00Z', 'canCorrectRole': correct});
  Get.put<TabConfigController>(JTabs());
  Get.put<PlanController>(_Plan());
}

const _dir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\taxi-owner';

class ArgHost extends StatefulWidget {
  const ArgHost({super.key, required this.args, required this.child});
  final Object args;
  final Widget child;
  @override
  State<ArgHost> createState() => _ArgHostState();
}

class _ArgHostState extends State<ArgHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.to(() => widget.child, arguments: widget.args, transition: Transition.noTransition));
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

Future<void> snap(WidgetTester t, Widget w, String name, {Size size = const Size(360, 800), double scale = 1.0, Future<void> Function()? after, Object? args}) async {
  debugDisableShadows = false;
  await pumpPhone(t, args == null ? w : ArgHost(args: args, child: w), size: size, textScale: scale);
  if (args != null) await t.pump(const Duration(milliseconds: 400));
  await settlePhone(t);
  if (after != null) {
    await after();
    await settlePhone(t);
  }
  await shot(t, name);
  debugDisableShadows = true;
}

Finder fieldWith(String text) => find.byWidgetPredicate((w) => w is EditableText && w.controller.text == text);

void mockPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.path,
  );
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump();
  await t.tap(find.text(text).first, warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> scrollTo(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump(const Duration(milliseconds: 300));
}

const _sizes = [(1.0, 360.0, ''), (1.3, 360.0, '_1.3'), (1.0, 300.0, '_w300')];

final _hubCases = <String, (TaxiOwnerModel?, bool, bool, bool)>{
  'hub_new': (taxiModel(), true, false, false),
  'hub_mid': (taxiModel(percent: 40, step1: true), true, false, false),
  'hub_ready': (taxiModel(percent: 90, step1: true, identity: true, routes: true, rate: 2500), true, false, false),
  'hub_review': (taxiModel(status: TaxiStatus.pendingReview, percent: 100, step1: true, identity: true, routes: true, rate: 2500), false, false, false),
  'hub_live': (taxiModel(status: TaxiStatus.approved, percent: 100, step1: true, identity: true, routes: true), false, false, false),
  'hub_rejected': (taxiModel(status: TaxiStatus.rejected, percent: 90, step1: true, identity: true, routes: true, rate: 2500, reason: 'The plate is not clear in the photo.'), false, false, false),
  'hub_loading': (null, true, false, true),
  'hub_error': (null, true, true, false),
};

Map<String, List<TripEnquiryModel>> _leadSet({bool noPhone = false, bool noChange = false}) => {
      TripLeadBucket.newOnes: [
        if (noPhone)
          lead('n0', status: 'Asked', display: 'asked', guest: '', city: 'Bhimtal', phone: null, spots: ['Bhimtal Lake', 'Naukuchiatal', 'Sattal']),
        lead('n1', status: 'Asked', display: 'asked', urgent: true, text: 'Car 1 of 2: Haldwani to Bhowali, 14 Nov, 4 people.'),
        lead('n2', status: 'Asked', display: 'asked', guest: 'Anita Joshi', city: 'Almora', days: 2, spots: ['Kasar Devi', 'Bright End Corner', 'Jageshwar']),
      ],
      TripLeadBucket.replied: [
        lead('r1', status: 'FareSent', display: 'fareSent', driverFare: 7000, left: noChange ? 0 : 2, text: 'Car 1 of 2: Haldwani to Bhowali, 14 Nov, 4 people.'),
        lead('r2', status: 'FareSent', display: 'fareSent', guest: 'Vikram Bisht', city: 'Ranikhet', days: 2, driverFare: 5200),
      ],
      TripLeadBucket.booked: [
        lead('b1', status: 'BookedByTraveller', display: 'bookedByYou', guest: 'Anita Joshi', city: 'Almora', days: 2, agreedFare: 4800),
        lead('b2', status: 'ConfirmedByBoth', display: 'confirmedByBoth', guest: 'Meera Rawat', city: 'Nainital'),
      ],
      TripLeadBucket.closed: [
        lead('c1', status: 'CancelledByTraveller', display: 'cancelled', guest: 'Sanjay Pant', city: 'Mukteshwar', start: -12, days: 2),
        lead('c2', status: 'Expired', display: 'expired', guest: '', city: 'Bhimtal', start: -16, days: 1),
        lead('c3', status: 'NotAvailable', display: 'notAvailable', guest: 'Pooja Arya', city: 'Kausani', start: -24),
        lead('c4', status: 'ConfirmedByBoth', display: 'confirmedByBoth', guest: 'Kiran Negi', city: 'Almora', start: -6),
      ],
    };

void main() {
  setUpAll(() {
    shotsDir = _dir;
    mockPathProvider();
  });
  tearDown(Get.reset);

  group('hub', () {
    for (final e in _hubCases.entries) {
      for (final cfg in _sizes) {
        testWidgets('${e.key}${cfg.$3}', (t) async {
          base(correct: e.value.$2);
          Get.put<TaxiSetupController>(_Taxi(e.value.$1, fail: e.value.$3, hang: e.value.$4));
          final args = e.value.$1 != null && !e.value.$1!.isDraft ? {'fromMyTaxi': true} : null;
          await snap(t, const TaxiSetupHubScreen(), '${e.key}${cfg.$3}', size: Size(cfg.$2, 800), scale: cfg.$1, args: args);
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('hub_menu', (t) async {
      base();
      Get.put<TaxiSetupController>(_Taxi(taxiModel()));
      await snap(t, const TaxiSetupHubScreen(), 'hub_menu', after: () async {
        await t.tap(find.byTooltip('Menu'));
        await t.pump(const Duration(milliseconds: 300));
      });
      expect(find.text('Change role'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('hub full heights', (t) async {
      for (final k in ['hub_live', 'hub_ready', 'hub_rejected']) {
        base();
        Get.put<TaxiSetupController>(_Taxi(_hubCases[k]!.$1));
        await snap(t, const TaxiSetupHubScreen(), '${k}_full', size: const Size(360, 1500), args: {'fromMyTaxi': true});
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    });
  });

  group('vehicle', () {
    Future<void> open(WidgetTester t, TaxiOwnerModel? m, String name,
        {Future<void> Function()? after, Size size = const Size(360, 800), double scale = 1, _Types? types}) async {
      base();
      Get.put<TaxiSetupController>(_Taxi(m));
      Get.find<TaxiSetupController>().taxi.value = m;
      Get.put<TaxiVehicleTypesController>(types ?? _Types());
      await snap(t, const TaxiVehicleScreen(), name, size: size, scale: scale, after: after);
    }

    final full = taxiModel(step1: true);
    for (final cfg in _sizes) {
      testWidgets('veh_vehicle${cfg.$3}', (t) async {
        await open(t, full, 'veh_vehicle${cfg.$3}', size: Size(cfg.$2, 800), scale: cfg.$1);
        expect(find.text('Innova Crysta'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 11));
      });
    }

    testWidgets('veh_vehicle full', (t) async {
      await open(t, full, 'veh_vehicle_full', size: const Size(360, 1400));
      expect(t.takeException(), isNull);
    });

    testWidgets('veh validation states', (t) async {
      final cases = {
        'veh_empty': (taxiModel(empty: true), 'Pick a vehicle type'),
        'veh_seats': (taxiModel(noSeats: true), 'Pick the number of seats'),
        'veh_plate': (taxiModel(plate: ''), 'Enter your number plate'),
        'veh_platebad': (taxiModel(plate: 'UK 07 1234'), TaxiOptionSets.plateHelp),
        'veh_photo': (taxiModel(photo: false), 'Add a photo that shows the plate'),
      };
      for (final c in cases.entries) {
        await open(t, c.value.$1, c.key, after: () async {
          await t.tap(find.text('Next: Driver'));
          await t.pump(const Duration(milliseconds: 600));
        });
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
      }
    });

    testWidgets('veh_live', (t) async {
      await open(t, _live, 'veh_live', after: () => scrollTo(t, 'Changing the plate or photo sends your taxi back to review.'));
      expect(t.takeException(), isNull);
    });

    testWidgets('type sheet states', (t) async {
      final cases = {
        'type_sheet': _Types(),
        'type_loading': _Types(loading: true),
        'type_error': _Types(failed: true),
      };
      for (final c in cases.entries) {
        await open(t, c.key == 'type_sheet' ? taxiModel() : taxiModel(empty: true), c.key, types: c.value, after: () async {
          await t.tap(find.text(c.key == 'type_sheet' ? 'Innova Crysta' : 'Select'));
          await t.pump(const Duration(milliseconds: 600));
        });
        expect(find.text('Vehicle Type'), findsWidgets);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
      await open(t, taxiModel(empty: true), 'type_nomatch', after: () async {
        await t.tap(find.text('Select'));
        await t.pump(const Duration(milliseconds: 600));
        await t.enterText(find.byType(TextField).last, 'Bolero xyz');
        await t.pump(const Duration(milliseconds: 300));
      });
      expect(find.text('No match. Try another name.'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 11));
    });

    testWidgets('photo_sheet', (t) async {
      await open(t, full, 'photo_sheet', after: () async {
        await t.ensureVisible(find.text('Add'));
        await t.pump();
        await t.tap(find.text('Add'));
        await t.pump(const Duration(milliseconds: 600));
      });
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
    });

    testWidgets('driver states', (t) async {
      final cases = {
        'veh_driver_saved': (taxiModel(step1: true, identity: true, status: TaxiStatus.approved), false),
        'veh_driver_err': (taxiModel(step1: true), true),
        'veh_phone_err': (taxiModel(step1: true, identity: true, phone: '98765432'), true),
        'veh_wa_err': (taxiModel(step1: true, identity: true, whatsApp: '91234567'), true),
      };
      for (final c in cases.entries) {
        await open(t, c.value.$1, c.key, after: () async {
          await t.tap(find.text('Next: Driver'));
          await t.pump(const Duration(milliseconds: 700));
          if (c.value.$2) {
            await t.tap(find.text('Next: Base'));
            await t.pump(const Duration(milliseconds: 700));
          }
        });
        expect(t.takeException(), isNull, reason: c.key);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
      }
    });

    testWidgets('veh_driver typed', (t) async {
      await open(t, taxiModel(step1: true), 'veh_driver', after: () async {
        await t.tap(find.text('Next: Driver'));
        await t.pump(const Duration(milliseconds: 700));
        await t.enterText(find.byType(TextFormField).first, 'UK0720150012345');
        await t.pump(const Duration(milliseconds: 300));
      });
      expect(find.text('Back'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('dob_picker', (t) async {
      await open(t, taxiModel(step1: true), 'dob_picker', after: () async {
        await t.tap(find.text('Next: Driver'));
        await t.pump(const Duration(milliseconds: 700));
        await t.tap(find.text('Select date'));
        await t.pump(const Duration(milliseconds: 700));
      });
      expect(find.text('Apply'), findsOneWidget);
    });

    testWidgets('dlg_discard and dialogs', (t) async {
      await open(t, full, 'dlg_discard', after: () async {
        await t.tap(find.text('7'));
        await t.tap(find.text('6'));
        await t.pump();
        await t.tap(find.byTooltip('Back'));
        await t.pump(const Duration(milliseconds: 600));
      });
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);
    });

    testWidgets('busy_save', (t) async {
      await open(t, full, 'busy_save', after: () async {
        Get.find<TaxiSetupController>().isSaving.value = true;
        await t.pump(const Duration(milliseconds: 300));
      });
      expect(find.text('Saving your taxi...'), findsOneWidget);
      Get.find<TaxiSetupController>().isSaving.value = false;
      await t.pump();
    });
  });

  group('dialogs', () {
    Future<void> dlg(WidgetTester t, String name, String art, String title, String body, String a, String b, {bool danger = false}) async {
      base();
      await snap(t, Scaffold(backgroundColor: ListingPalette.coral.page, body: Builder(builder: (c) => Center(child: TextButton(onPressed: () => showTaxiOwnerDialog(c, art: art, title: title, body: body, cancelLabel: a, confirmLabel: b, destructive: danger), child: const Text('open'))))), name, after: () async {
        await t.tap(find.text('open'));
        await t.pump(const Duration(milliseconds: 500));
      });
      expect(find.text(title), findsOneWidget);
      expect(t.takeException(), isNull);
    }

    testWidgets('dlg_permission', (t) => dlg(t, 'dlg_permission', ListingArt.camera, 'Camera Permission Required', 'Please enable Camera access in your device Settings to add photos.', 'Cancel', 'Open Settings'));
    testWidgets('dlg_upload', (t) => dlg(t, 'dlg_upload', ListingArt.camera, 'Upload Failed', 'The plate photo could not be uploaded. Retry?', 'Skip', 'Retry'));
    testWidgets('dlg_permission_1.3', (t) async {
      base();
      await snap(t, Scaffold(body: Builder(builder: (c) => Center(child: TextButton(onPressed: () => showTaxiOwnerDialog(c, art: ListingArt.taxi, title: 'Delete taxi?', body: 'Your taxi, routes and plate photo will be deleted.', cancelLabel: 'Cancel', confirmLabel: 'Delete', destructive: true), child: const Text('open'))))), 'dlg_delete_1.3', scale: 1.3, after: () async {
        await t.tap(find.text('open'));
        await t.pump(const Duration(milliseconds: 500));
      });
      expect(t.takeException(), isNull);
    });
  });

  group('routes', () {
    Future<void> open(WidgetTester t, TaxiOwnerModel m, String name, {Future<void> Function()? after, Size size = const Size(360, 800), double scale = 1}) async {
      base();
      Get.put<TaxiSetupController>(_Taxi(m)).taxi.value = m;
      await snap(t, const TaxiRoutesScreen(), name, size: size, scale: scale, after: after);
    }

    final withRoutes = taxiModel(step1: true, routes: true, rate: 2500);
    for (final cfg in _sizes) {
      testWidgets('routes_main${cfg.$3}', (t) async {
        await open(t, withRoutes, 'routes_main${cfg.$3}', size: Size(cfg.$2, 800), scale: cfg.$1, after: () => scrollTo(t, 'Nainital'));
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('routes_first', (t) async {
      await open(t, taxiModel(step1: true), 'routes_first', size: const Size(360, 1300));
      expect(find.text('Route 1'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('routes_main full', (t) async {
      await open(t, withRoutes, 'routes_main_full', size: const Size(360, 1700));
      expect(t.takeException(), isNull);
    });

    testWidgets('routes errors', (t) async {
      Future<void> err(String name, TaxiOwnerModel m, Future<void> Function() act, String toast) async {
        await open(t, m, name, after: () async {
          await act();
          await t.tap(find.text('Save').last);
          await t.pump(const Duration(milliseconds: 700));
        });
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
      }

      await err('routes_none', taxiModel(step1: true), () async {}, 'Add at least one route');
      await err('routes_rate', taxiModel(step1: true, routes: true), () async {}, 'Add your day rate');
      await err('routes_km', taxiModel(step1: true, routes: true, rate: 2500, km: 1500), () async {}, 'Km per day must be between 1 and 1000');
      await err('routes_noto', withRoutes, () async {
        await t.scrollUntilVisible(find.text('One way'), 300, scrollable: find.byType(Scrollable).first);
        await tapText(t, 'One way');
      }, 'Pick a To place');
      await err('routes_nofare', withRoutes, () async {
        await t.ensureVisible(find.byTooltip('Edit route').first);
        await t.pump();
        await t.tap(find.byTooltip('Edit route').first);
        await t.pump(const Duration(milliseconds: 300));
        await t.enterText(fieldWith('900'), '');
        await t.pump();
      }, 'Enter the fare');
      await err('routes_farerange', withRoutes, () async {
        await t.ensureVisible(find.byTooltip('Edit route').first);
        await t.pump();
        await t.tap(find.byTooltip('Edit route').first);
        await t.pump(const Duration(milliseconds: 300));
        await t.enterText(fieldWith('900'), '50');
        await t.pump();
      }, 'Fare must be between ₹100 and ₹99,00,000');
    });

    testWidgets('routes_limit', (t) async {
      await open(t, taxiModel(step1: true, tenRoutes: true, rate: 2500), 'routes_limit', size: const Size(360, 2400));
      expect(find.text('Limit reached'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('busy_routes', (t) async {
      await open(t, withRoutes, 'busy_routes', after: () async {
        Get.find<TaxiSetupController>().isSaving.value = true;
        await t.pump(const Duration(milliseconds: 300));
      });
      expect(find.text('Saving routes...'), findsOneWidget);
      Get.find<TaxiSetupController>().isSaving.value = false;
      await t.pump();
    });
  });

  group('submit', () {
    Future<void> open(WidgetTester t, TaxiOwnerModel m, String name, {bool tap = false, Size size = const Size(360, 800), double scale = 1}) async {
      base();
      Get.put<TaxiSetupController>(_Taxi(m)).taxi.value = m;
      await snap(t, const TaxiSubmitScreen(), name, size: size, scale: scale, after: tap
          ? () async {
              await t.tap(find.text('Submit'));
              await t.pump(const Duration(milliseconds: 600));
            }
          : null);
    }

    final ready = taxiModel(percent: 90, step1: true, identity: true, routes: true, rate: 2500);
    for (final cfg in _sizes) {
      testWidgets('submit${cfg.$3}', (t) async {
        await open(t, ready, 'submit${cfg.$3}', size: Size(cfg.$2, 800), scale: cfg.$1);
        expect(find.text('Check your taxi'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('submit warnings', (t) async {
      final cases = {
        'submit_missing': (taxiModel(step1: true, routes: true, rate: 2500), 'Add your licence and date of birth.'),
        'submit_step1': (taxiModel(), 'Complete step 1 first.'),
        'submit_step2': (taxiModel(step1: true, identity: true), 'Complete step 2 first.'),
      };
      for (final c in cases.entries) {
        await open(t, c.value.$1, c.key, tap: true);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
      }
    });

    testWidgets('submit_busy', (t) async {
      base();
      Get.put<TaxiSetupController>(_Taxi(ready)).taxi.value = ready;
      Get.find<TaxiSetupController>().isSaving.value = true;
      await snap(t, const TaxiSubmitScreen(), 'submit_busy');
      expect(find.text('Submitting...'), findsOneWidget);
      Get.find<TaxiSetupController>().isSaving.value = false;
      await t.pump();
    });
  });

  group('my taxi', () {
    Future<void> open(WidgetTester t, TaxiOwnerModel? m, String name,
        {bool fail = false, bool hang = false, int news = 2, Future<void> Function()? after, Size size = const Size(360, 800), double scale = 1}) async {
      base();
      Get.put<TaxiSetupController>(_Taxi(m, fail: fail, hang: hang));
      Get.put<TripLeadsController>(_Leads(const {}, news: news), permanent: true);
      await snap(t, const MyTaxiScreen(), name, size: size, scale: scale, after: after);
    }

    tearDown(() => Get.delete<TripLeadsController>(force: true));

    for (final cfg in _sizes) {
      testWidgets('my_live${cfg.$3}', (t) async {
        await open(t, _live, 'my_live${cfg.$3}', size: Size(cfg.$2, 800), scale: cfg.$1);
        expect(find.text('VEHICLE'), findsOneWidget);
        expect(find.text('Available now'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    final cases = <String, (TaxiOwnerModel?, bool, bool)>{
      'my_live_full': (_live, false, false),
      'my_offline': (taxiModel(status: TaxiStatus.approved, step1: true, identity: true, routes: true, available: false, reports: 2), false, false),
      'my_review': (taxiModel(status: TaxiStatus.pendingReview, step1: true, identity: true, routes: true, rate: 2500), false, false),
      'my_draft': (taxiModel(step1: true), false, false),
      'my_rejected': (taxiModel(status: TaxiStatus.rejected, step1: true, identity: true, routes: true, rate: 2500, reason: 'The plate is not clear in the photo'), false, false),
      'my_empty': (null, false, false),
      'my_error': (null, true, false),
      'my_loading': (null, false, true),
    };
    for (final c in cases.entries) {
      testWidgets(c.key, (t) async {
        await open(t, c.value.$1, c.key, fail: c.value.$2, hang: c.value.$3, news: c.key == 'my_live_full' ? 2 : 0, size: Size(360, c.key.endsWith('full') || c.key == 'my_offline' || c.key == 'my_rejected' ? 1500 : 800));
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('fare_edit', (t) async {
      await open(t, _live, 'fare_edit', after: () async {
        await tapText(t, 'Edit fare');
        await t.pump(const Duration(milliseconds: 600));
      });
      expect(find.text('Edit fare'), findsWidgets);
    });

    testWidgets('fare_edit_empty and range', (t) async {
      for (final v in [('', 'fare_edit_empty', 'Enter the fare'), ('50', 'fare_edit_range', 'Fare must be between ₹100 and ₹99,00,000')]) {
        await open(t, _live, v.$2, after: () async {
          await tapText(t, 'Edit fare');
          await t.pump(const Duration(milliseconds: 600));
          await t.enterText(fieldWith('900').last, v.$1);
          await t.tap(find.text('Save').last);
          await t.pump(const Duration(milliseconds: 600));
        });
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
      }
    });

    testWidgets('dlg_delete', (t) async {
      await open(t, _live, 'dlg_delete', after: () async {
        await tapText(t, 'Delete');
        await t.pump(const Duration(milliseconds: 600));
      });
      expect(find.text('Delete taxi?'), findsOneWidget);
    });

    testWidgets('busy_update', (t) async {
      await open(t, _live, 'busy_update', after: () async {
        Get.find<TaxiSetupController>().isSaving.value = true;
        await t.pump(const Duration(milliseconds: 300));
      });
      expect(find.text('Updating...'), findsOneWidget);
      Get.find<TaxiSetupController>().isSaving.value = false;
      await t.pump();
    });
  });

  group('leads', () {
    Future<void> open(WidgetTester t, String name,
        {Map<String, List<TripEnquiryModel>>? set, String? bucket, bool fail = false, bool disabled = false, bool hang = false, bool taxis = true, int news = 2, Future<void> Function()? after, Size size = const Size(360, 800), double scale = 1, bool notifOff = false}) async {
      base(taxis: taxis);
      if (notifOff) Get.put<NotificationService>(_Notif(), permanent: true);
      Get.put<TaxiSetupController>(_Taxi(_live)).taxi.value = _live;
      Get.find<TaxiSetupController>().hasLoaded.value = true;
      Get.put<TripLeadsController>(_Leads(set ?? _leadSet(), fail: fail, disabled: disabled, hang: hang, news: news), permanent: true);
      await snap(t, const TripLeadsScreen(), name, size: size, scale: scale, after: () async {
        if (bucket != null) {
          await Get.find<TripLeadsController>().selectBucket(bucket);
          await t.pump(const Duration(milliseconds: 700));
        }
        if (after != null) await after();
      });
    }

    tearDown(() => Get.delete<TripLeadsController>(force: true));

    for (final cfg in _sizes) {
      testWidgets('leads_new${cfg.$3}', (t) async {
        await open(t, 'leads_new${cfg.$3}', size: Size(cfg.$2, 800), scale: cfg.$1);
        expect(find.text('Rahul Sharma'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    final buckets = {
      'leads_new_full': TripLeadBucket.newOnes,
      'leads_replied': TripLeadBucket.replied,
      'leads_booked': TripLeadBucket.booked,
      'leads_closed': TripLeadBucket.closed,
    };
    for (final b in buckets.entries) {
      testWidgets(b.key, (t) async {
        await open(t, b.key, bucket: b.value, size: const Size(360, 1700));
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('leads_booked_1.3', (t) async {
      await open(t, 'leads_booked_1.3', bucket: TripLeadBucket.booked, size: const Size(360, 2000), scale: 1.3);
      expect(t.takeException(), isNull);
    });

    testWidgets('leads_nophone', (t) async {
      await open(t, 'leads_nophone', set: _leadSet(noPhone: true), size: const Size(360, 1100));
      expect(find.text('Guests'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('leads_menu', (t) async {
      await open(t, 'leads_menu', after: () async {
        await t.tap(find.byTooltip('More').first);
        await t.pump(const Duration(milliseconds: 400));
      });
      expect(find.text('Report this traveller'), findsOneWidget);
    });

    testWidgets('leads_nochange', (t) async {
      await open(t, 'leads_nochange', set: _leadSet(noChange: true), bucket: TripLeadBucket.replied, after: () async {
        await tapText(t, 'Change fare');
        await t.pump(const Duration(milliseconds: 600));
      });
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    });

    final empties = {
      'leads_empty': TripLeadBucket.newOnes,
      'leads_empty_replied': TripLeadBucket.replied,
      'leads_empty_booked': TripLeadBucket.booked,
      'leads_empty_closed': TripLeadBucket.closed,
    };
    for (final e in empties.entries) {
      testWidgets(e.key, (t) async {
        await open(t, e.key, set: const {}, bucket: e.value, news: 0);
        expect(find.text('Travellers planning a trip send them here.'), findsOneWidget);
      });
    }

    testWidgets('leads_error', (t) async {
      await open(t, 'leads_error', fail: true, news: 0);
      expect(find.text('Could not load'), findsOneWidget);
    });

    testWidgets('leads_off', (t) async {
      await open(t, 'leads_off', fail: true, disabled: true, taxis: false, news: 0);
      expect(find.text('New leads are paused in your area.'), findsOneWidget);
    });

    testWidgets('leads_loading', (t) async {
      await open(t, 'leads_loading', hang: true, news: 0);
      expect(t.takeException(), isNull);
    });

    for (final (w, h, s, tag) in [(390.0, 844.0, 1.0, '390'), (360.0, 800.0, 1.3, '360_13'), (300.0, 800.0, 1.0, '300')]) {
      testWidgets('banner_taxi_$tag', (t) async {
        await open(t, 'banner_taxi_$tag', set: const {}, news: 0, size: Size(w, h), scale: s, notifOff: true);
        expect(find.text('Turn on notifications'), findsOneWidget);
        expect(find.text('No trip leads yet'), findsOneWidget);
        final title = t.getRect(find.text('No trip leads yet'));
        final msg = t.getRect(find.text('Travellers planning a trip send them here.'));
        final bar = t.getRect(find.byType(TaxiPayBar));
        expect(title.bottom <= bar.top && msg.bottom <= bar.top, isTrue);
        for (final c in ['New', 'Replied', 'Booked', 'Closed']) {
          expect(find.text(c), findsOneWidget);
        }
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('tfare_sheet and error', (t) async {
      await open(t, 'tfare_sheet', bucket: TripLeadBucket.replied, after: () async {
        await tapText(t, 'Change fare');
        await t.pump(const Duration(milliseconds: 700));
        await t.tap(fieldWith('7000'));
        await t.pump(const Duration(milliseconds: 300));
      });
      expect(find.text('Send reply'), findsOneWidget);
      await t.enterText(fieldWith('7000'), '60');
      await t.tap(find.text('Send reply'));
      await t.pump(const Duration(milliseconds: 600));
      await settlePhone(t);
      debugDisableShadows = false;
      await shot(t, 'tfare_err');
      debugDisableShadows = true;
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('tfare_sheet_1.3', (t) async {
      await open(t, 'tfare_sheet_1.3', bucket: TripLeadBucket.replied, scale: 1.3, after: () async {
        await tapText(t, 'Change fare');
        await t.pump(const Duration(milliseconds: 700));
      });
      expect(t.takeException(), isNull);
    });

    testWidgets('lead dialogs', (t) async {
      final cases = {
        'dlg_notavail': (TripLeadBucket.newOnes, 'Not available', 'Mark as not available?'),
        'dlg_confirm': (TripLeadBucket.booked, 'Yes, confirm', 'Confirm this booking?'),
        'dlg_notme': (TripLeadBucket.booked, 'Not me', 'Not your booking?'),
      };
      for (final c in cases.entries) {
        await open(t, c.key, bucket: c.value.$1, after: () async {
          await tapText(t, c.value.$2);
          await t.pump(const Duration(milliseconds: 600));
        });
        expect(find.text(c.value.$3), findsOneWidget, reason: c.key);
        await t.pumpWidget(const SizedBox());
      }
    });
  });

  testWidgets('TripFareSheet opens alone', (t) async {
    base();
    Get.put<TripLeadsController>(_Leads(const {}), permanent: true);
    final e = lead('x', status: 'Asked', display: 'asked');
    await snap(t, Scaffold(body: Builder(builder: (c) => Center(child: TextButton(onPressed: () => TripFareSheet.show(c, lead: e), child: const Text('open'))))), 'tfare_sheet_new', after: () async {
      await t.tap(find.text('open'));
      await t.pump(const Duration(milliseconds: 600));
    });
    expect(find.text('Send reply'), findsOneWidget);
    Get.delete<TripLeadsController>(force: true);
  });
}
