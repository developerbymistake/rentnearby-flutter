import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/stay/setup/stay_repository.dart';
import 'package:bakhli/features/stay/setup/stay_setup_controller.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import 'stay_fixtures.dart';

class FakeLocation extends LocationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class FakeStayRepo extends StayRepository {
  FakeStayRepo(this.model);

  static FakeStayRepo? last;

  StayOwnerModel? model;
  final List<String> calls = [];
  Object? error;
  Object? loadError;

  @override
  Future<StayOwnerModel?> getMine() async {
    if (loadError != null) throw loadError!;
    return model;
  }

  @override
  Future<StayOwnerModel?> saveBasic(Map<String, dynamic> body) async {
    calls.add('basic');
    if (error != null) throw error!;
    return model;
  }

  @override
  Future<StayOwnerModel?> saveRooms(List<Map<String, dynamic>> rooms) async {
    calls.add('rooms');
    if (error != null) throw error!;
    return model;
  }

  @override
  Future<StayOwnerModel?> submit() async {
    calls.add('submit');
    if (error != null) throw error!;
    return model;
  }
}

StaySetupController setupFor(StayOwnerModel? model, {MyPlanModel plan = OwnerPlans.free, bool canCorrect = true, String stayStatus = 'Draft', Object? loadError}) {
  Get.reset();
  Get.testMode = true;
  Get.put<TabConfigController>(FakeTabs());
  Get.put<LocationController>(FakeLocation());
  final auth = StayFakeAuth();
  Get.put<AuthController>(auth);
  auth.signIn(role: 'STAY_OWNER', stayStatus: stayStatus);
  auth.user.value = UserModel(
    id: 'user-a',
    phoneNumber: '9000000000',
    createdAt: DateTime(2026),
    role: 'STAY_OWNER',
    roleConfirmed: true,
    stayStatus: stayStatus,
    canCorrectRole: canCorrect,
  );
  PlanGate.debugPlan = plan;
  final repo = FakeStayRepo(model)..loadError = loadError;
  FakeStayRepo.last = repo;
  final c = StaySetupController(repo: repo);
  Get.put<StaySetupController>(c);
  c.stay.value = model;
  c.hasLoaded.value = loadError == null;
  return c;
}

StayOwnerModel stayModel(Map<String, dynamic> json) => StayOwnerModel.fromJson(json);

Map<String, dynamic> draftJson({bool step1 = false, bool rooms = false, bool rules = false, int photos = 2, String status = 'Draft', bool reg = true}) => {
      'id': 's1',
      'status': status,
      'step1Done': step1,
      'roomsDone': rooms,
      'rulesDone': rules,
      'name': 'Deodar Heights Homestay',
      'stayTypeName': 'Homestay',
      'registrationTypeId': reg ? 'rt1' : null,
      'hasRegistrationNumber': reg,
      'photos': [for (var i = 0; i < photos; i++) {'id': 'p$i', 'url': '', 'photoOrder': i}],
      'rooms': [
        {'id': 'r0', 'roomIndex': 1, 'roomName': 'Deluxe', 'pricePerNight': 3000, 'maxGuests': 3, 'meals': 'Breakfast'},
        {'id': 'r1', 'roomIndex': 2, 'roomName': 'Family Room', 'pricePerNight': 4500, 'maxGuests': 5, 'meals': 'AllMeals'},
      ],
      'rules': {'checkInTime': '12:00:00', 'checkOutTime': '11:00:00', 'cancellationPolicy': 'Flexible'},
      'submittedAt': '2026-11-18T10:00:00Z',
      'createdAt': '2026-11-01T10:00:00Z',
    };
