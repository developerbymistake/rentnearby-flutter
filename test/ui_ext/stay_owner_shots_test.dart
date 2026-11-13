import 'dart:async';
import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiries_controller.dart';
import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/stay/models/stay_registration_type_model.dart';
import 'package:bakhli/features/stay/models/stay_type_model.dart';
import 'package:bakhli/features/stay/setup/my_stays_screen.dart';
import 'package:bakhli/features/stay/setup/stay_advance_details_screen.dart';
import 'package:bakhli/features/stay/setup/stay_basic_details_screen.dart';
import 'package:bakhli/features/stay/setup/stay_rooms_screen.dart';
import 'package:bakhli/features/stay/setup/stay_rules_screen.dart';
import 'package:bakhli/features/stay/setup/stay_setup_controller.dart';
import 'package:bakhli/features/stay/setup/stay_setup_hub_screen.dart';
import 'package:bakhli/features/stay/setup/stay_submit_screen.dart';
import 'package:bakhli/features/stay/stay_registration_types_controller.dart';
import 'package:bakhli/features/stay/stay_types_controller.dart';
import 'package:bakhli/models/city_model.dart';
import 'package:bakhli/models/location_context.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
// ignore: depend_on_referenced_packages
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:toastification/toastification.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../support/real_phone.dart';

enum LoadMode { ok, loading, error }

class FakeStayCtrl extends StaySetupController {
  FakeStayCtrl(this.next, {this.mode = LoadMode.ok, this.hold = false});
  StayOwnerModel? next;
  final LoadMode mode;
  final bool hold;
  bool basicOk = false;
  int? uploadAt;
  final calls = <String>[];

  @override
  Future<bool> load() {
    if (mode == LoadMode.loading) {
      isLoading.value = true;
      return Completer<bool>().future;
    }
    if (mode == LoadMode.error) {
      loadFailed.value = true;
      return Future.value(false);
    }
    stay.value = next;
    hasLoaded.value = true;
    return Future.value(true);
  }

  Future<bool> _busy(String name) {
    calls.add(name);
    isSaving.value = true;
    if (hold) return Completer<bool>().future;
    isSaving.value = false;
    return Future.value(false);
  }

  @override
  Future<bool> saveRooms(List<Map<String, dynamic>> rooms) => _busy('rooms');
  @override
  Future<bool> saveRules(Map<String, dynamic> body) => _busy('rules');
  @override
  Future<bool> submit() => _busy('submit');
  @override
  Future<bool> saveBasic(Map<String, dynamic> body) => basicOk ? Future.value(true) : _busy('basic');
  @override
  Future<bool> uploadPhoto(String filePath, {void Function(int, int)? onProgress}) {
    final at = uploadAt;
    if (at == null) return Future.value(false);
    onProgress?.call(at, 100);
    return Completer<bool>().future;
  }
  @override
  Future<bool> setAccepting(bool accepting) => _busy('accepting');
  @override
  Future<bool> saveAdvanceDetails({String? upiId, String? whatsAppNumber}) => _busy('advance');
}

class FakeAuth extends JAuth {
  @override
  bool get staysEnabled => true;
  @override
  Future<void> refreshProfile() async {}
  @override
  Future<void> logout() async {}
}

class FakeLoc extends JLoc {
  bool closed = false;
  @override
  Future<LocationContext> resolveDistrictAt(double lat, double lng, {bool includeAddress = false}) async => LocationContext(
        district: DistrictModel(id: 'd1', name: 'Bageshwar', stateName: 'Uttarakhand', businessOnboardingEnabled: !closed),
        nearestCity: CityModel(id: 'c1', districtId: 'd1', name: 'Kausani'),
        address: 'Near Anasakti Ashram, Kausani, Bageshwar, Uttarakhand',
      );
  @override
  Future<List<CityModel>> loadCitiesForDistrict(String districtId, {bool forceRefresh = false}) async => const [];
}

class FakePicker extends ImagePickerPlatform {
  @override
  Future<List<XFile>> getMultiImageWithOptions({MultiImagePickerOptions options = const MultiImagePickerOptions()}) async =>
      [for (var i = 1; i <= 3; i++) XFile('assets/images/design/hotel/hotel_$i.png')];
}

class FakePermissions extends PermissionHandlerPlatform {
  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(List<Permission> permissions) async =>
      {for (final p in permissions) p: PermissionStatus.permanentlyDenied};
}

class FakeTypes extends StayTypesController {
  FakeTypes({this.state = 0});
  final int state;
  @override
  void ensureLoaded() {
    if (state == 1) isLoading.value = true;
    if (state == 0) {
      types.value = [
        for (final (i, n) in ['Homestay', 'Hotel', 'Resort', 'Camp', 'Cottage', 'Hostel'].indexed) StayTypeModel(id: 't$i', name: n, sortOrder: i),
      ];
    }
  }

  @override
  Future<void> load() async {}
}

class FakeRegTypes extends StayRegistrationTypesController {
  FakeRegTypes({this.state = 0});
  final int state;
  @override
  void ensureLoaded() {
    if (state == 1) isLoading.value = true;
    if (state == 0) {
      types.value = [
        StayRegistrationTypeModel.fromJson({'id': 'r1', 'code': 'UDYAM', 'name': 'Udyam Registration', 'helpText': 'Format UDYAM-XX-00-0000000', 'sortOrder': 1}),
        StayRegistrationTypeModel.fromJson({'id': 'r2', 'code': 'HOMESTAY', 'name': 'Homestay registration', 'sortOrder': 2}),
        StayRegistrationTypeModel.fromJson({'id': 'r9', 'code': 'OTHER', 'name': 'Other', 'sortOrder': 9, 'requiresOtherName': true}),
      ];
    }
  }

  @override
  Future<void> load() async {}
}

class FakePlan extends PlanController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class FakeEnq extends StayEnquiriesController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> loadBadge() async => newCount.value = 2;
}

Map<String, dynamic> stayJson({
  String status = StayStatus.draft,
  bool s1 = false,
  bool s2 = false,
  bool s3 = false,
  bool reg = true,
  bool advance = false,
  String? reason,
  bool accepting = true,
  int reports = 0,
  int photos = 4,
  bool rooms = true,
  bool gstin = false,
}) =>
    {
      'id': 's1',
      'status': status,
      'step1Done': s1,
      'roomsDone': s2,
      'rulesDone': s3,
      'name': 'Deodar Cottage',
      'stayTypeId': 't0',
      'registrationTypeId': reg ? 'r1' : null,
      'hasRegistrationNumber': reg,
      'hasGstin': gstin,
      'vehicleAccess': 'CarToGate',
      'hostLivesHere': true,
      'facilities': ['HotWater', 'Heater', 'HomeFood', 'MountainView'],
      'cityName': 'Kausani',
      'districtName': 'Bageshwar',
      'minPricePerNight': 1500,
      'slug': 'deodar',
      'acceptingGuests': accepting,
      'rejectedReason': reason,
      'pendingReportCount': reports,
      'upiId': advance ? 'deodar@okaxis' : null,
      'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'photos': [for (var i = 0; i < photos; i++) {'id': 'p$i', 'url': ''}],
      'rooms': rooms
          ? [
              {'id': 'r1', 'roomIndex': 1, 'pricePerNight': 1500, 'maxGuests': 2, 'roomName': 'Deluxe', 'meals': 'Breakfast'},
              {'id': 'r2', 'roomIndex': 2, 'pricePerNight': 2400, 'maxGuests': 4, 'roomName': 'Family Room', 'meals': 'AllMeals'},
            ]
          : [],
      'rules': {'checkInTime': '12:00', 'checkOutTime': '11:00', 'cancellationPolicy': 'Moderate', 'alcoholAllowed': true, 'unmarriedCouplesAllowed': true, 'idProofRequired': true},
    };

StayOwnerModel stayOf(Map<String, dynamic> j) => StayOwnerModel.fromJson(j);

FakeAuth base({bool canCorrect = false, bool gps = true}) {
  Get.reset();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async => call.method == 'create' ? 0 : null);
  for (var i = 0; i < 40; i++) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel('plugins.flutter.io/maplibre_gl_$i'), (call) async => null);
  }
  final loc = Get.put<LocationController>(FakeLoc()) as FakeLoc;
  if (gps) loc.userLocation.value = const LatLng(29.83812, 79.62044);
  final auth = Get.put<AuthController>(FakeAuth()) as FakeAuth;
  Get.put<TabConfigController>(JTabs());
  auth.user.value = UserModel.fromJson({'id': 'u', 'phoneNumber': '9876543210', 'createdAt': '2026-11-01T00:00:00Z', 'canCorrectRole': canCorrect});
  return auth;
}

FakeStayCtrl ctrl(Map<String, dynamic>? j, {LoadMode mode = LoadMode.ok, bool hold = false}) {
  final c = FakeStayCtrl(j == null ? null : stayOf(j), mode: mode, hold: hold);
  if (j != null && mode == LoadMode.ok) {
    c.stay.value = c.next;
    c.hasLoaded.value = true;
  }
  return Get.put<StaySetupController>(c) as FakeStayCtrl;
}

class Launch extends StatefulWidget {
  const Launch(this.screen, {super.key, this.args});
  final Widget screen;
  final Object? args;
  @override
  State<Launch> createState() => _LaunchState();
}

class _LaunchState extends State<Launch> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Get.to<void>(() => widget.screen, arguments: widget.args, transition: Transition.noTransition, duration: Duration.zero));
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

const sizes = <String, (double, double)>{'': (360, 800), '_13': (360, 800), '_300': (300, 800)};

Future<void> capture(WidgetTester t, Widget Function() screen, String name, {double height = 800, Future<void> Function()? after, bool variants = true, String? expectText}) async {
  for (final v in variants ? sizes.entries : sizes.entries.take(1)) {
    await t.pumpWidget(const SizedBox());
    await t.pump();
    debugDisableShadows = false;
    toastification.managers.clear();
    await pumpPhone(t, screen(), size: Size(v.value.$1, height), textScale: v.key == '_13' ? 1.3 : 1.0);
    await settlePhone(t);
    if (after != null) {
      await after();
      await toastFrames(t);
      await settlePhone(t);
    }
    if (expectText != null) expect(find.text(expectText), findsOneWidget, reason: '$name${v.key}');
    await shot(t, '$name${v.key}');
    await t.pump(const Duration(seconds: 5));
    debugDisableShadows = true;
    expect(t.takeException(), isNull, reason: '$name${v.key}');
  }
}

// Toasts animate on a ticker; one long pump leaves them at frame 0, so step the clock.
Future<void> toastFrames(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> clearToasts(WidgetTester t) async {
  toastification.dismissAll(delayForAnimation: false);
  await toastFrames(t);
}

Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = last ? find.text(text).last : find.text(text).first;
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 100));
  await t.tap(f, warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 400));
}

Widget basicScreen({Map<String, dynamic>? stay, int types = 0, int reg = 0, bool gps = true}) {
  base(gps: gps);
  ctrl(stay);
  Get.put<StayTypesController>(FakeTypes(state: types));
  Get.put<StayRegistrationTypesController>(FakeRegTypes(state: reg));
  return const StayBasicDetailsScreen();
}

Future<void> scrollTo(WidgetTester t, double dy) async {
  final s = find.byType(Scrollable).first;
  t.state<ScrollableState>(s).position.jumpTo(dy);
  await t.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(() => shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\stay-owner');
  tearDown(Get.reset);

  group('hub', () {
    final cases = <String, (Map<String, dynamic>?, LoadMode, bool, double)>{
      'hub_new': (null, LoadMode.ok, true, 800),
      'hub_progress': (stayJson(s1: true, s2: true), LoadMode.ok, false, 1350),
      'hub_ready': (stayJson(status: StayStatus.rejected, s1: true, s2: true, s3: true, advance: true), LoadMode.ok, false, 1350),
      'hub_reg': (stayJson(s1: true, s2: true, s3: true, reg: false), LoadMode.ok, false, 800),
      'hub_pending': (stayJson(status: StayStatus.pendingReview, s1: true, s2: true, s3: true), LoadMode.ok, false, 800),
      'hub_live': (stayJson(status: StayStatus.approved, s1: true, s2: true, s3: true, advance: true), LoadMode.ok, false, 800),
      'hub_rejected': (stayJson(status: StayStatus.rejected, s1: true, s2: true, s3: true, reason: 'Photos are not clear. Add brighter photos.'), LoadMode.ok, false, 800),
      'hub_loading': (null, LoadMode.loading, true, 800),
      'hub_error': (null, LoadMode.error, true, 800),
    };
    for (final e in cases.entries) {
      testWidgets(e.key, (t) async {
        await capture(t, () {
          base(canCorrect: e.value.$3);
          ctrl(e.value.$1, mode: e.value.$2);
          final draft = e.key != 'hub_progress' && (e.value.$1 == null || e.value.$1!['status'] == StayStatus.draft);
          return draft ? const StaySetupHubScreen() : const Launch(StaySetupHubScreen(), args: {'fromMyStays': true});
        }, e.key, height: e.value.$4, variants: e.key == 'hub_new' || e.key == 'hub_progress');
      });
    }

    testWidgets('hub_menu', (t) async {
      await capture(t, () {
        base();
        ctrl(null);
        return const StaySetupHubScreen();
      }, 'hub_menu', after: () async {
        await t.tap(find.byTooltip('Menu'));
        await t.pump(const Duration(milliseconds: 300));
      }, variants: false);
      expect(find.text('Change role'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('hub_pending toast', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(status: StayStatus.pendingReview, s1: true, s2: true, s3: true));
        return const Launch(StaySetupHubScreen(), args: {'fromMyStays': true});
      }, 'hub_pending_toast', after: () async {
        await t.tap(find.text('Basic details'));
        await t.pump(const Duration(milliseconds: 600));
      }, variants: false);
    });
  });

  group('basic details', () {
    testWidgets('bd_details', (t) async {
      await capture(t, () => basicScreen(stay: stayJson(s1: true)), 'bd_details', height: 1250);
    });
    testWidgets('bd_details2', (t) async {
      await capture(t, () => basicScreen(stay: stayJson(s1: true, gstin: true)), 'bd_details2', after: () => scrollTo(t, 900), height: 1250, variants: false);
    });
    testWidgets('bd_errors', (t) async {
      await capture(t, () => basicScreen(types: 2), 'bd_errors', after: () => tapText(t, 'Next: Location'), height: 1250, variants: false);
    });
    testWidgets('bd_reg_loading and retry', (t) async {
      await capture(t, () => basicScreen(stay: stayJson(s1: true), reg: 1), 'bd_reg_loading', after: () => scrollTo(t, 500), variants: false);
      await capture(t, () => basicScreen(stay: stayJson(s1: true), reg: 2), 'bd_reg_retry', after: () => scrollTo(t, 500), variants: false);
      expect(find.text("Couldn't load registration types. Tap to retry."), findsOneWidget);
    });
    testWidgets('bd_reg_other', (t) async {
      await capture(t, () => basicScreen(stay: stayJson(s1: true, gstin: true)), 'bd_reg_other', after: () async {
        await tapText(t, 'Udyam Registration');
        await t.pump(const Duration(seconds: 1));
        await tapText(t, 'Other', last: true);
        await t.pump(const Duration(milliseconds: 400));
        await tapText(t, 'Saved · Remove');
        await tapText(t, 'Next: Location');
        await scrollTo(t, 520);
      }, height: 1000, variants: false);
      expect(find.text('Enter the document name'), findsWidgets);
      expect(find.text('Will be removed · Undo'), findsOneWidget);
    });
    testWidgets('bd_location', (t) async {
      await capture(t, () => basicScreen(stay: stayJson(s1: true)), 'bd_location', after: () => tapText(t, 'Next: Location'), height: 1000);
      expect(find.text('Pinned — tap inside your district to adjust'), findsOneWidget);
    });
    testWidgets('bd_location_wait', (t) async {
      await capture(t, () => basicScreen(stay: stayJson(s1: true), gps: false), 'bd_location_wait', after: () => tapText(t, 'Next: Location'), variants: false);
      expect(find.text('Getting your location...'), findsOneWidget);
    });
    testWidgets('bd_address', (t) async {
      await capture(t, () => basicScreen(stay: stayJson(s1: true)..['address'] = 'Near Anasakti Ashram, Kausani'), 'bd_address', after: () async {
        await tapText(t, 'Next: Location');
        await tapText(t, 'Next: Address');
        await t.pump(const Duration(seconds: 1));
      }, variants: false);
      expect(find.text('Next: Photos'), findsOneWidget);
    });
    testWidgets('bd_discard', (t) async {
      await capture(t, () => basicScreen(stay: stayJson(s1: true)), 'bd_discard', after: () async {
        await tapText(t, 'Next: Location');
        await t.tap(find.byTooltip('Back'));
        await t.pump(const Duration(milliseconds: 400));
      }, variants: false);
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);
    });
  });

  group('rooms', () {
    testWidgets('rooms_first', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, rooms: false));
        return const StayRoomsScreen();
      }, 'rooms_first', height: 1000);
    });
    testWidgets('rooms_two', (t) async {
      await capture(t, () {
        base();
        final c = ctrl(stayJson(s1: true));
        c.stay.value = stayOf(stayJson(s1: true)..['rooms'] = [(stayJson()['rooms'] as List).first]);
        return const StayRoomsScreen();
      }, 'rooms_two', after: () async {
        await tapText(t, 'Select');
        await tapText(t, 'Family Room', last: true);
        await t.enterText(find.byType(TextField).first, '2400');
        await tapText(t, '4+');
        await tapText(t, 'All meals');
      }, height: 1150);
    });
    testWidgets('rooms_saved and sheet', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true));
        return const StayRoomsScreen();
      }, 'rooms_saved', variants: false);
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, rooms: false));
        return const StayRoomsScreen();
      }, 'rooms_sheet', after: () => tapText(t, 'Select'), variants: false);
      expect(find.text('Dormitory'), findsOneWidget);
    });
    testWidgets('rooms toasts', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, rooms: false));
        return const StayRoomsScreen();
      }, 'rooms_empty_err', after: () => tapText(t, 'Save'), variants: false);
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, rooms: false));
        return const StayRoomsScreen();
      }, 'rooms_error', after: () async {
        await tapText(t, 'Select');
        await tapText(t, 'Deluxe', last: true);
        await t.enterText(find.byType(TextField).first, '50');
        await tapText(t, '1');
        await tapText(t, 'Breakfast');
        await tapText(t, 'Save');
      }, variants: false);
    });
    testWidgets('rooms_discard', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, rooms: false));
        return const StayRoomsScreen();
      }, 'rooms_discard', after: () async {
        await tapText(t, '2');
        await t.tap(find.byTooltip('Back'));
        await t.pump(const Duration(milliseconds: 400));
      }, variants: false);
      expect(find.text('Discard changes?'), findsOneWidget);
    });
    testWidgets('rooms_busy', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true), hold: true);
        return const StayRoomsScreen();
      }, 'rooms_busy', after: () => tapText(t, 'Save'), variants: false);
      expect(find.text('Saving rooms...'), findsOneWidget);
    });
  });

  group('rules', () {
    testWidgets('rules', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, s2: true, s3: true));
        return const StayRulesScreen();
      }, 'rules', height: 1250);
    });
    testWidgets('rules_error and time', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, s2: true)..['rules'] = null);
        return const StayRulesScreen();
      }, 'rules_error', after: () => tapText(t, 'Save'), height: 1250, variants: false);
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, s2: true, s3: true));
        return const StayRulesScreen();
      }, 'rules_time', after: () => tapText(t, '12:00 PM'), variants: false);
    });
    testWidgets('rules_busy and discard', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, s2: true, s3: true), hold: true);
        return const StayRulesScreen();
      }, 'rules_busy', after: () => tapText(t, 'Save'), variants: false);
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, s2: true, s3: true));
        return const StayRulesScreen();
      }, 'rules_discard', after: () async {
        await tapText(t, 'Pets allowed');
        await t.tap(find.byTooltip('Back'));
        await t.pump(const Duration(milliseconds: 400));
      }, variants: false);
      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  group('submit', () {
    testWidgets('submit', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, s2: true, s3: true));
        return const StaySubmitScreen();
      }, 'submit');
    });
    testWidgets('submit_reg and busy', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, s2: true, s3: true, reg: false));
        return const StaySubmitScreen();
      }, 'submit_reg', after: () => tapText(t, 'Submit'), variants: false);
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, s2: true, s3: true), hold: true);
        return const StaySubmitScreen();
      }, 'submit_busy', after: () => tapText(t, 'Submit'), variants: false);
      expect(find.text('Submitting...'), findsOneWidget);
    });
  });

  group('advance', () {
    testWidgets('adv', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, advance: true));
        return const StayAdvanceDetailsScreen();
      }, 'adv', height: 900);
    });
    testWidgets('adv states', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true));
        return const StayAdvanceDetailsScreen();
      }, 'adv_error', after: () async {
        await t.enterText(find.byType(TextField).first, 'deodar.cottage');
        await t.enterText(find.byType(TextField).last, '98765');
        await tapText(t, 'Save');
      }, height: 900, variants: false);
      expect(find.text('Enter a UPI ID like name@bank'), findsOneWidget);
      await capture(t, () {
        base();
        ctrl(null, mode: LoadMode.loading);
        return const StayAdvanceDetailsScreen();
      }, 'adv_loading', variants: false);
      await capture(t, () {
        base();
        ctrl(null, mode: LoadMode.error);
        return const StayAdvanceDetailsScreen();
      }, 'adv_failed', variants: false);
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, advance: true), hold: true);
        return const StayAdvanceDetailsScreen();
      }, 'adv_saving', after: () => tapText(t, 'Save'), height: 900, variants: false);
    });
  });

  group('my stays', () {
    Widget my(Map<String, dynamic>? j, {LoadMode mode = LoadMode.ok, int paused = 0, bool hold = false}) {
      base();
      ctrl(j, mode: mode, hold: hold);
      final p = Get.put<PlanController>(FakePlan());
      p.myPlan.value = MyPlanModel.fromJson({'paymentEnabled': true, 'featureKey': 'stay', 'pausedByPlanCount': paused});
      Get.put<StayEnquiriesController>(FakeEnq());
      return const MyStaysScreen();
    }

    testWidgets('my_live', (t) async {
      await capture(t, () => my(stayJson(status: StayStatus.approved, s1: true, s2: true, s3: true)), 'my_live', height: 1150);
    });
    final more = <String, Map<String, dynamic>>{
      'my_plan_paused': stayJson(status: StayStatus.approved, s1: true, s2: true, s3: true, accepting: false),
      'my_draft': stayJson(s1: true),
      'my_pending': stayJson(status: StayStatus.pendingReview, s1: true, s2: true, s3: true),
      'my_rejected': stayJson(status: StayStatus.rejected, s1: true, s2: true, s3: true, reason: 'Photos are not clear', reports: 1),
    };
    for (final e in more.entries) {
      testWidgets(e.key, (t) async {
        await capture(t, () => my(e.value, paused: e.key == 'my_plan_paused' ? 1 : 0), e.key, height: 1150, variants: false);
      });
    }
    testWidgets('my_empty error loading', (t) async {
      await capture(t, () => my(null), 'my_empty', variants: true);
      await capture(t, () => my(null, mode: LoadMode.error), 'my_error', variants: false);
      await capture(t, () => my(null, mode: LoadMode.loading), 'my_loading', variants: false);
    });
    testWidgets('my_price, delete, busy', (t) async {
      final live = stayJson(status: StayStatus.approved, s1: true, s2: true, s3: true);
      await capture(t, () => my(live), 'my_price', after: () => tapText(t, 'Edit price'), variants: false);
      expect(find.text('Deluxe price'), findsOneWidget);
      await capture(t, () => my(live), 'my_delete', after: () => tapText(t, 'Delete'), variants: false);
      expect(find.text('Delete stay?'), findsOneWidget);
      await capture(t, () => my(live, hold: true), 'my_busy', after: () async {
        await t.tap(find.bySemanticsLabel('Accepting guests').first);
        await t.pump(const Duration(milliseconds: 300));
      }, variants: false);
      expect(find.text('Updating...'), findsOneWidget);
    });
  });
  group('extra states', () {
    Widget myLive() {
      base();
      ctrl(stayJson(status: StayStatus.approved, s1: true, s2: true, s3: true));
      final p = Get.put<PlanController>(FakePlan());
      p.myPlan.value = MyPlanModel.fromJson({'paymentEnabled': true, 'featureKey': 'stay', 'pausedByPlanCount': 0});
      Get.put<StayEnquiriesController>(FakeEnq());
      return const MyStaysScreen();
    }

    testWidgets('my_price_err and empty', (t) async {
      await capture(t, myLive, 'my_price_err', after: () async {
        await tapText(t, 'Edit price');
        await t.pump(const Duration(seconds: 1));
        await t.enterText(find.byType(TextField).first, '50');
        await tapText(t, 'Save', last: true);
      }, variants: false);
      await capture(t, myLive, 'my_price_empty', after: () async {
        await tapText(t, 'Edit price');
        await t.pump(const Duration(seconds: 1));
        await t.enterText(find.byType(TextField).first, '');
        await tapText(t, 'Save', last: true);
      }, variants: false);
    });

    testWidgets('rooms_sheet selected', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, rooms: false));
        return const StayRoomsScreen();
      }, 'rooms_sheet_selected', after: () async {
        await tapText(t, 'Select');
        await t.pump(const Duration(seconds: 1));
        await tapText(t, 'Deluxe', last: true);
        await t.pump(const Duration(seconds: 1));
        await tapText(t, 'Deluxe');
        await t.pump(const Duration(seconds: 1));
      }, variants: false);
    });

    testWidgets('rules_time_out and rooms_fill', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, s2: true, s3: true));
        return const StayRulesScreen();
      }, 'rules_time_out', after: () => tapText(t, 'Check-out'), variants: false);
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, rooms: false));
        return const StayRoomsScreen();
      }, 'rooms_fill', after: () => tapText(t, 'Add another room'), height: 1300, variants: false);
    });

    testWidgets('submit_closed shots base', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true, s2: true, s3: true), hold: true);
        return const StaySubmitScreen();
      }, 'submit_busy2', after: () => tapText(t, 'Submit'), variants: false);
    });
  });

  group('photos step', () {
    setUpAll(() {
      ImagePickerPlatform.instance = FakePicker();
      PermissionHandlerPlatform.instance = FakePermissions();
    });

    Widget photosScreen({bool hold = false, bool basicOk = false, int? uploadAt}) {
      base();
      ctrl(stayJson(s1: true, photos: 0), hold: hold)
        ..basicOk = basicOk
        ..uploadAt = uploadAt;
      Get.put<StayTypesController>(FakeTypes());
      Get.put<StayRegistrationTypesController>(FakeRegTypes());
      return const StayBasicDetailsScreen();
    }

    Future<void> toPhotos(WidgetTester t) async {
      await tapText(t, 'Next: Location');
      await tapText(t, 'Next: Address');
      await t.pump(const Duration(seconds: 1));
      await tapText(t, 'Next: Photos');
      await t.pump(const Duration(milliseconds: 600));
    }

    Future<void> addThree(WidgetTester t) async {
      final ctx = t.element(find.byType(StayBasicDetailsScreen));
      await t.runAsync(() async {
        for (final f in await FakePicker().getMultiImageWithOptions()) {
          await precacheImage(FileImage(File(f.path)), ctx);
        }
      });
      await toPhotos(t);
      await tapText(t, 'Add Stay Photos');
      await t.pump(const Duration(milliseconds: 600));
      await tapText(t, 'Choose from Gallery');
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 100));
    }

    testWidgets('bd_photos', (t) async {
      await capture(t, () => photosScreen(), 'bd_photos', after: () => addThree(t));
      expect(find.text('3/5 photos added'), findsOneWidget);
    });
    testWidgets('bd_photos_empty', (t) async {
      await capture(t, () => photosScreen(), 'bd_photos_empty', after: () async {
        await toPhotos(t);
        await tapText(t, 'Save');
      }, variants: false);
      expect(find.text('0/5 photos added'), findsOneWidget);
    });
    testWidgets('bd_photo_sheet', (t) async {
      await capture(t, () => photosScreen(), 'bd_photo_sheet', after: () async {
        await toPhotos(t);
        await tapText(t, 'Add Stay Photos');
        await t.pump(const Duration(milliseconds: 600));
      });
      expect(find.text('Choose from Gallery'), findsOneWidget);
    });
    testWidgets('bd_perm', (t) async {
      await capture(t, () => photosScreen(), 'bd_perm', after: () async {
        await toPhotos(t);
        await tapText(t, 'Add Stay Photos');
        await t.pump(const Duration(milliseconds: 600));
        await tapText(t, 'Take Photo');
        await t.pump(const Duration(milliseconds: 600));
      }, variants: false);
      expect(find.text('Camera Permission Required'), findsOneWidget);
    });
    final uploads = <String, int?>{'bd_upload': 90, 'bd_upload_almost': 144, 'bd_upload_failed': null};
    for (final e in uploads.entries) {
      testWidgets(e.key, (t) async {
        await capture(t, () => photosScreen(basicOk: true, uploadAt: e.value), e.key, after: () async {
          await addThree(t);
          await tapText(t, 'Save');
          await t.pump(const Duration(milliseconds: 600));
        }, variants: e.key == 'bd_upload');
      });
    }
    testWidgets('bd_saving', (t) async {
      await capture(t, () => photosScreen(hold: true), 'bd_saving', after: () async {
        await addThree(t);
        await tapText(t, 'Save');
        await t.pump(const Duration(milliseconds: 600));
      }, variants: false);
      expect(find.text('Saving your stay...'), findsOneWidget);
    });
  });

  group('toasts and coverage', () {
    testWidgets('hub_bd_saved', (t) async {
      await capture(t, () {
        base();
        ctrl(stayJson(s1: true));
        return const StaySetupHubScreen();
      }, 'hub_bd_saved', after: () async => AppToast.success('Basic details saved'), height: 1350, variants: false, expectText: 'Basic details saved');
    });

    final bdToasts = <String, (Map<String, dynamic>, String, double)>{
      'bd_t_name': (stayJson(s1: true)..['name'] = 'D', 'Stay name must be 2 to 80 characters', 0),
      'bd_t_type': (stayJson(s1: true)..['stayTypeId'] = null, 'Please select a stay type', 0),
      'bd_t_vehicle': (stayJson(s1: true)..['vehicleAccess'] = null, 'Please select vehicle access', -1),
      'bd_t_host': (stayJson(s1: true)..['hostLivesHere'] = null, 'Please tell us if the host lives here', -1),
    };
    for (final e in bdToasts.entries) {
      testWidgets(e.key, (t) async {
        await capture(t, () => basicScreen(stay: e.value.$1), e.key, after: () async {
          await tapText(t, 'Next: Location');
          if (e.value.$3 < 0) await t.ensureVisible(find.text(e.key == 'bd_t_host' ? 'Host Lives Here' : 'Vehicle Access').first);
        }, variants: false, expectText: e.value.$2);
      });
    }

    testWidgets('bd_reg_empty', (t) async {
      await capture(t, () => basicScreen(stay: stayJson(s1: true, reg: false)), 'bd_reg_empty', after: () async {
        await tapText(t, 'Next: Location');
        await clearToasts(t);
        await scrollTo(t, 500);
      }, variants: false);
      expect(find.text('Pick a registration type'), findsWidgets);
    });

    testWidgets('bd_reg_other2', (t) async {
      await capture(t, () => basicScreen(stay: stayJson(s1: true, gstin: true)), 'bd_reg_other2', after: () async {
        await tapText(t, 'Udyam Registration');
        await t.pump(const Duration(seconds: 1));
        await tapText(t, 'Other', last: true);
        await t.pump(const Duration(milliseconds: 400));
        await t.enterText(find.ancestor(of: find.text('e.g. Gram Panchayat NOC'), matching: find.byType(TextField)), 'NO');
        await tapText(t, 'Next: Location');
        await clearToasts(t);
        await scrollTo(t, 520);
      }, height: 1000, variants: false);
      expect(find.text('Document name must be 3 to 40 characters'), findsWidgets);
      expect(find.text('Enter your registration number'), findsWidgets);
    });

    testWidgets('bd_stale', (t) async {
      await capture(t, () => basicScreen(stay: stayJson(s1: true)..['address'] = 'Near Anasakti Ashram, Kausani'), 'bd_stale', after: () async {
        await tapText(t, 'Next: Location');
        await tapText(t, 'Next: Address');
        await t.pump(const Duration(seconds: 1));
        Get.find<LocationController>().resumeLocationRefreshedTrigger.value++;
        await t.pump(const Duration(milliseconds: 400));
      }, height: 1000, variants: false, expectText: 'Your location may have changed — please recheck your pin.');
    });

    testWidgets('bd_closed', (t) async {
      await capture(t, () {
        final w = basicScreen(stay: stayJson(s1: true)..['address'] = 'Near Anasakti Ashram, Kausani');
        (Get.find<LocationController>() as FakeLoc).closed = true;
        return w;
      }, 'bd_closed', after: () async {
        await tapText(t, 'Next: Location');
        await tapText(t, 'Next: Address');
        await t.pump(const Duration(seconds: 1));
      }, height: 1000, variants: false);
      expect(find.text('Not open here yet'), findsOneWidget);
    });

    Widget roomsFirst() {
      base();
      ctrl(stayJson(s1: true, rooms: false));
      return const StayRoomsScreen();
    }

    final roomToasts = <String, (List<String>, String)>{
      'rooms_t_type': (['price', '1', 'Breakfast'], 'Please select a room type'),
      'rooms_t_price': (['type', '1', 'Breakfast'], 'Please enter the price per night'),
      'rooms_t_guests': (['type', 'price', 'Breakfast'], 'Please select max guests'),
      'rooms_t_meals': (['type', 'price', '1'], 'Please select meals'),
    };
    for (final e in roomToasts.entries) {
      testWidgets(e.key, (t) async {
        await capture(t, roomsFirst, e.key, after: () async {
          for (final step in e.value.$1) {
            if (step == 'type') {
              await tapText(t, 'Select');
              await tapText(t, 'Deluxe', last: true);
              await t.pump(const Duration(milliseconds: 400));
            } else if (step == 'price') {
              await t.enterText(find.byType(TextField).first, '1500');
            } else {
              await tapText(t, step);
            }
          }
          await tapText(t, 'Save');
        }, variants: false, expectText: e.value.$2);
      });
    }
  });
}
