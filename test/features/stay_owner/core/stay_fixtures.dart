import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/home/owner_home_api.dart';
import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay_owner/hub/stay_hub_controller.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/features/stay_owner/home/stay_owner_home_controller.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';

class FakeHomeApi implements OwnerHomeApi {
  FakeHomeApi(this.result);

  Future<OwnerResult<OwnerHomeDto>> Function() result;
  int calls = 0;

  @override
  Future<OwnerResult<OwnerHomeDto>> load() {
    calls++;
    return result();
  }
}

Map<String, dynamic> upcomingJson({int more = 3, int days = 15, bool three = true}) => {
      'rows': [
        {'id': 'e1', 'kind': 'Auto', 'dateFrom': '2026-11-22', 'dateTo': '2026-11-23', 'label': 'Neha Joshi', 'detail': 'Family Room'},
        {'id': 'e2', 'kind': 'Manual', 'dateFrom': '2026-11-24', 'dateTo': '2026-11-25', 'label': 'Kapoor couple'},
        if (three) {'id': 'e3', 'kind': 'Auto', 'dateFrom': '2026-11-27', 'dateTo': '2026-11-29', 'label': 'Rohit Verma'},
      ],
      'moreInWindowCount': more,
      'windowLabelDays': days,
    };

Map<String, dynamic> homeJson({
  String status = 'Approved',
  bool switchOn = true,
  bool takenDown = false,
  bool everApproved = true,
  bool areaPaused = false,
  bool featured = false,
  String? reason,
  Map<String, dynamic>? statusLine,
  List<Map<String, dynamic>> attention = const [],
  Map<String, dynamic>? stay,
  int badge = 0,
  String name = 'Deodar Heights',
  String? city = 'Mukteshwar',
}) =>
    {
      'role': 'STAY_OWNER',
      'today': '2026-11-21',
      'paymentEnabled': true,
      'listing': {
        'id': 's1',
        'kind': 'Stay',
        'status': status,
        'everApproved': everApproved,
        'name': name,
        'sub': 'Mukteshwar',
        'cityName': city,
        'switchOn': switchOn,
        'isFeatured': featured,
        'takenDown': takenDown,
        'rejectedReason': reason,
        'areaPaused': areaPaused,
        'statusLine': statusLine,
      },
      'attention': attention,
      'attentionCount': attention.length,
      'numbers': {'stay': stay ?? {'newEnquiries': 0, 'offersWaiting': 0, 'confirmed': 0}, 'centreBadge': badge},
      'upcoming': upcomingJson(),
    };

Map<String, dynamic> att(String code, int priority, [Map<String, dynamic> args = const {}]) => {'code': code, 'priority': priority, 'args': args};

Map<String, dynamic> stayJson({
  String status = 'Approved',
  int rooms = 2,
  int photos = 2,
  int hiddenRooms = 0,
  int hiddenPhotos = 0,
  bool accepting = true,
  bool featured = false,
  int reports = 0,
  int confirmed = 0,
  Map<String, dynamic>? pendingEdit,
  Map<String, dynamic>? lastEditResult,
  String name = 'Deodar Heights Homestay',
  Map<String, dynamic>? specialPricesRow,
  Map<String, dynamic>? calendarRow,
  List<Map<String, dynamic>>? meters,
}) {
  const names = ['Deluxe Room', 'Family Room', 'Suite', 'Dormitory', 'Premium Room', 'Standard Room', 'Executive Room'];
  const prices = [3000, 4500, 3200, 600, 3500, 2500, 5000];
  const guests = [3, 5, 4, 1, 2, 2, 3];
  Map<String, dynamic> room(int i, {bool hidden = false}) => {
        'id': 'r$i',
        'roomIndex': hidden ? 101 + i : i + 1,
        'roomName': names[i % names.length],
        'pricePerNight': prices[i % prices.length],
        'maxGuests': guests[i % guests.length],
        'meals': 'Breakfast',
        'priceToday': prices[i % prices.length],
      };
  return {
    'id': 's1',
    'status': status,
    'step1Done': true,
    'roomsDone': true,
    'rulesDone': true,
    'name': name,
    'stayTypeName': 'Homestay',
    'registrationTypeId': 'rt1',
    'registrationNumber': 'UDYAM-UK-05-0001234',
    'hasRegistrationNumber': true,
    'facilities': ['Wi-Fi', 'Parking', 'Hot water', 'Garden'],
    'cityName': 'Mukteshwar',
    'districtName': 'Nainital',
    'photos': [for (var i = 0; i < photos; i++) {'id': 'p$i', 'url': '', 'photoOrder': i}],
    'rooms': [for (var i = 0; i < rooms; i++) room(i)],
    'hiddenPhotos': [for (var i = 0; i < hiddenPhotos; i++) {'id': 'hp$i', 'url': '', 'photoOrder': 50 + i}],
    'hiddenRooms': [for (var i = 0; i < hiddenRooms; i++) room(i + rooms, hidden: true)],
    'meters': meters ?? [{'key': 'Photos', 'used': photos, 'limit': 2}, {'key': 'RoomTypes', 'used': rooms, 'limit': 2}],
    'acceptingGuests': accepting,
    'minPricePerNight': 3000,
    'slug': 'deodar-heights',
    'submittedAt': '2026-11-18T10:00:00Z',
    'createdAt': '2026-11-01T10:00:00Z',
    'reportCount': reports,
    'everApproved': true,
    'isFeatured': featured,
    'confirmedBookingCount': confirmed,
    'pendingEdit': pendingEdit,
    'lastEditResult': lastEditResult,
    'specialPricesRow': specialPricesRow ??
        {
          'count': 1,
          'limit': 1,
          'first': {'label': 'Diwali week', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12', 'direction': 'Higher', 'percent': 20},
        },
    'calendarRow': calendarRow ??
        {
          'thisMonthCount': 3,
          'next': {'date': '2026-11-22', 'label': 'Neha Joshi'},
        },
  };
}

class StayFakeAuth extends FakeAuth {
  @override
  Future<void> refreshProfile() async {}
}

class StayHarness {
  StayHarness._(this.auth, this.home, this.api);

  final FakeAuth auth;
  final StayOwnerHomeController home;
  final FakeHomeApi api;

  static StayHarness setUp(Map<String, dynamic> json, {bool denied = false, String name = 'Meena Bisht', bool registerHome = true, bool offline = false}) {
    Get.reset();
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
    final auth = StayFakeAuth();
    Get.put<AuthController>(auth);
    auth.signIn(role: 'STAY_OWNER', stayStatus: 'Approved');
    auth.profileName.value = name;
    final api = FakeHomeApi(() async => offline ? OwnerOffline<OwnerHomeDto>() : OwnerOk<OwnerHomeDto>(OwnerHomeDto.fromJson(json)));
    final home = StayOwnerHomeController(api: api, deniedProbe: () async => denied, userId: () => 'user-a');
    if (registerHome) Get.put<StayOwnerHomeController>(home);
    return StayHarness._(auth, home, api);
  }
}

StayHubController hubHarness(Map<String, dynamic>? stay, {MyPlanModel plan = OwnerPlans.free, Future<Map<String, dynamic>> Function()? fetch}) {
  Get.reset();
  Get.testMode = true;
  Get.put<TabConfigController>(FakeTabs());
  final auth = StayFakeAuth();
  Get.put<AuthController>(auth);
  auth.signIn(role: 'STAY_OWNER', stayStatus: 'Approved');
  PlanGate.debugPlan = plan;
  return Get.put(StayHubController(userId: () => 'user-a', fetch: fetch ?? () async => {'data': stay}), tag: StayHubController.tag);
}
