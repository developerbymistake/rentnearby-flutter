import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/models/user_model.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../support/real_phone.dart';

Future<void> initSocialTestStorage() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.createTempSync('social_test').path,
  );
  await GetStorage.init();
}

class SocialFakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RequestOptions> seen = [];

  void on(String method, String path, Object? data, {int status = 200}) => routes['$method $path'] = (status, data);

  void refuse(String method, String path, {required int status, required String type, String message = 'Refused', Map<String, dynamic>? data}) =>
      routes['$method $path'] = (status, {'error': {'type': type, 'message': message}, 'data': ?data});

  List<RequestOptions> calls(String method, String path) => [for (final o in seen) if (o.method == method && o.path == path) o];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    final hit = routes['${options.method} ${options.path}'];
    final status = hit?.$1 ?? 404;
    final Object? payload = hit == null
        ? {'error': {'type': 'NotFound', 'message': 'Not found'}}
        : (status >= 400 ? hit.$2 : {'data': hit.$2, 'status': '$status', 'code': status});
    return ResponseBody.fromString(jsonEncode(payload), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

SocialFakeServer installServer() {
  ApiService.init();
  final s = SocialFakeServer();
  ApiService.dio.httpClientAdapter = s;
  return s;
}

class FakeTabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool isActive(String tabKey) {
    version.value;
    return true;
  }
}

class FakeAuth extends AuthController {
  int refreshed = 0;

  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> refreshProfile() async => refreshed++;
}

FakeAuth putSeeker({String role = UserRoleKeys.seeker, bool profileCompleted = true, String? gender = 'Male'}) {
  Get.put<TabConfigController>(FakeTabs());
  final a = Get.put<AuthController>(FakeAuth()) as FakeAuth;
  a.roleKey.value = role;
  final caps = RoleCapabilities.of(role);
  a.canListStays.value = caps.canListStays;
  a.canListTaxis.value = caps.canListTaxis;
  a.shellKind.value = role == UserRoleKeys.seeker ? ShellKind.seeker : ShellKind.stayOwner;
  a.profileName.value = 'Rahul Verma';
  a.profilePhone.value = '9897012345';
  a.user.value = UserModel(
    id: 'me',
    phoneNumber: '9897012345',
    name: 'Rahul Verma',
    username: 'Bakhli#48291736',
    createdAt: DateTime(2026),
    role: role,
    roleConfirmed: true,
    profileCompleted: profileCompleted,
    gender: gender,
  );
  return a;
}

Map<String, dynamic> personJson(String id, String name, {String? city}) =>
    {'userId': id, 'name': name, 'username': 'Bakhli#${id.hashCode.abs()}', 'photoUrl': null, 'initial': name.substring(0, 1), 'homeCity': city};

Map<String, dynamic> rowJson(String id, String name,
        {bool followsMe = true, bool iFollow = false, bool requested = false, bool isBuddy = false, int mutualCount = 0, String? mutualName}) =>
    {
      ...personJson(id, name),
      'followsMe': followsMe,
      'iFollow': iFollow,
      'followRequested': requested,
      'isBuddy': isBuddy,
      'mutualCount': mutualCount,
      'mutualName': mutualName,
    };

Map<String, dynamic> myProfileJson({bool isPrivate = false, String policy = 'Everyone'}) => {
      ...personJson('me', 'Rahul Verma', city: 'Dehradun'),
      'gender': 'Male',
      'birthMonth': 8,
      'birthYear': 1998,
      'homeCity': 'Dehradun',
      'homeState': 'Uttarakhand',
      'about': 'Hills over beaches. Chai at every stop.',
      'interests': ['Mountains', 'Treks', 'Food', 'Photography'],
      'skills': ['Photographer', 'Driver'],
      'places': ['Rishikesh', 'Nainital', 'Jaipur', 'Manali'],
      'isPrivate': isPrivate,
      'messagePolicy': policy,
      'notifyMessages': true,
      'notifyFollows': true,
      'notifyFollowedTrips': true,
      'counters': {'trips': 4, 'followers': 128, 'following': 41, 'buddies': 6},
      'publicTrips': [],
    };

Map<String, dynamic> socialMeJson({Map<String, dynamic>? profile, bool isPlus = false, bool? guidelinesAccepted}) => {
      'profile': profile,
      'guidelinesAccepted': ?guidelinesAccepted,
      'limits': {
        'isPlus': isPlus,
        'canUpgrade': true,
        'resetsAt': '2026-12-01T00:00:00Z',
        'activeTrips': {'limit': 1, 'used': 0},
        'publicTrips': {'limit': 1, 'used': 0},
        'joinRequests': {'limit': 1, 'used': 0},
        'newChats': {'limit': 3, 'used': 1},
        'genderOnlyTrips': false,
        'nearMe': false,
      },
      'counts': {
        'followRequests': 2,
        'chatUnread': {'people': 1, 'trips': 0, 'requests': 2, 'total': 3},
      },
      'catalog': {
        'interests': ['Mountains', 'Treks', 'Beaches', 'Adventure', 'Food', 'Culture', 'Photography', 'Spiritual', 'Road trips', 'Camping'],
        'skills': ['Photographer', 'Driver', 'Cook', 'Tour guide', 'Content creator', 'First aid'],
        'aboutExamples': ['Hills over beaches. Chai at every stop.', 'Weekend trekker. Happy to share a cab.', 'Slow travel, local food, early mornings.'],
        'postChips': ['Budget trip'],
      },
    };

Map<String, dynamic> travellerJson({
  bool iFollow = false,
  bool requested = false,
  bool followsMe = false,
  bool isBuddy = false,
  bool privateLocked = false,
  int mutualCount = 4,
}) =>
    {
      'person': personJson('kavya', 'Kavya Sharma', city: 'Dehradun'),
      'gender': 'Female',
      'about': privateLocked ? '' : 'Mountains, chai and long walks.',
      'interests': privateLocked ? [] : ['Treks', 'Mountains'],
      'skills': privateLocked ? [] : ['First aid'],
      'places': privateLocked ? [] : ['Rishikesh', 'Auli'],
      'counters': {'trips': 6, 'followers': 86, 'following': 40},
      'relation': {
        'iFollow': iFollow,
        'followRequested': requested,
        'followsMe': followsMe,
        'isBuddy': isBuddy,
        'canAddBuddy': followsMe && !isBuddy,
        'canMessage': true,
      },
      'mutuals': mutualCount == 0 ? null : {'count': mutualCount, 'names': ['Aman'], 'photoUrls': []},
      'privateLocked': privateLocked,
      'publicTrips': [],
    };

const List<Size> socialSizes = [Size(360, 1400), Size(411, 1400)];
const List<double> socialScales = [1.0, 1.3];

Future<void> settle(WidgetTester t, {int rounds = 3}) async {
  for (var i = 0; i < rounds; i++) {
    await settlePhone(t);
  }
}

Future<void> pumpSocial(WidgetTester t, Widget w, {Size size = const Size(392, 1400), double textScale = 1.0, List<GetPage<dynamic>>? pages}) async {
  await pumpPhone(t, w, size: size, textScale: textScale, toastHost: true, pages: pages);
  await settle(t);
}

Future<void> drain(WidgetTester t) async {
  await t.pump(const Duration(seconds: 5));
  await t.pump(const Duration(seconds: 1));
}
