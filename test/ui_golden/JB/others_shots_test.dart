import 'dart:io';
import 'dart:ui' as ui;
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/controllers/location_controller.dart';
import 'package:bakhli/controllers/notification_controller.dart';
import 'package:bakhli/models/conversation_model.dart';
import 'package:bakhli/models/notification_model.dart';
import 'package:bakhli/repositories/notification_repository.dart';
import 'package:bakhli/screens/chats_list_screen.dart';
import 'package:bakhli/screens/notifications_screen.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/jobs/models/job_lookups_model.dart';
import 'package:bakhli/features/jobs/v2/jobs_feed_controller.dart';
import 'package:bakhli/features/jobs/v2/jobs_feed_repository.dart';
import 'package:bakhli/features/jobs/v2/jobs_landing_screen_v2.dart';
import 'package:bakhli/features/nearby/models/nearby_models.dart';
import 'package:bakhli/models/role_model.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:bakhli/screens/role_change_screen.dart';
import 'package:bakhli/screens/role_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../golden_support.dart';

const _out = 'F:/Dhasu/UI_Template_resume/Repair/shots';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Loc extends LocationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _FakeChat extends ChatController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> loadConversations({bool forceRefresh = false}) async {
    conversations.value = [
      for (var i = 0; i < 4; i++)
        ConversationModel(id: '$i', listingType: i.isEven ? 'Stay' : 'Taxi', listingId: 'l$i', listingTitle: 'Hillview Homestay $i', otherPartyId: 'o', otherPartyName: 'Ramesh Kumar $i', isOwner: i == 1, status: 'Active', lastMessageAt: DateTime.now(), lastMessagePreview: 'Is the room available this weekend?', unreadCount: i),
    ];
  }
}

class _NRepo extends NotificationRepository {
  @override
  Future<({List<NotificationModel> items, bool hasMore, String? nextCursor})> getNotifications({String? cursor, int page = 1, int pageSize = 20}) async => (
        items: List.generate(6, (i) => NotificationModel(id: '$i', type: 'x', title: 'New enquiry for your stay $i', body: 'A traveller asked about dates for next week', actionRoute: null, actionArguments: null, isRead: i > 2, createdAt: DateTime.now())),
        hasMore: false,
        nextCursor: null
      );
  @override
  Future<int> getUnreadCount() async => 3;
  @override
  Future<void> markRead(String id) async {}
}

class _FakeAuth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> refreshProfile() async {}
  @override
  Future<List<RoleModel>> fetchRoles() async => [
        RoleModel(key: 'SEEKER', name: 'Seeker', description: 'Plan trips and find stays', sortOrder: 1),
        RoleModel(key: 'STAY_OWNER', name: 'Stay Owner', description: 'List your stay', sortOrder: 2),
        RoleModel(key: 'TAXI_DRIVER', name: 'Taxi Driver', description: 'Offer rides', sortOrder: 3),
      ];
}

Future<void> _shot(WidgetTester t, String name) async {
  await t.runAsync(() async {
    final b = t.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot_root')));
    final img = await b.toImage(pixelRatio: 1);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/others_$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget _host(Widget child, double scale) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'WorkSans'),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(360, 760), textScaler: TextScaler.linear(scale), padding: const EdgeInsets.only(top: 24, bottom: 20), viewPadding: const EdgeInsets.only(top: 24, bottom: 20)),
        child: RepaintBoundary(key: const ValueKey('shot_root'), child: child),
      ),
    );

void main() {
  setUpAll(loadGoldenFonts);
  setUp(() {
    Get.reset();
    Get.put<AuthController>(_FakeAuth());
    Get.put<TabConfigController>(_Tabs());
    Get.put<LocationController>(_Loc());
  });

  final screens = <String, Widget Function()>{
    'profile': () => const ProfileScreen(),
    'role_change': () => const RoleChangeScreen(),
    'role_select': () => const RoleSelectScreen(),
  };
  Map<String, dynamic> job(String id, double km, String label, String city) => {
        'id': id, 'stayName': 'Hillview Homestay', 'title': 'Front desk executive $id', 'roleName': 'Reception',
        'jobTypeName': 'Full time', 'salaryTypeName': 'Monthly', 'minSalary': 18000, 'maxSalary': 25000,
        'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'distanceKm': km, 'labelKey': label, 'cityName': city, 'stateName': 'Uttarakhand',
      };
  testWidgets('shot chats_list', (t) async {
    Get.put<ChatController>(_FakeChat());
    setGoldenView(t, const Size(360, 760));
    await t.pumpWidget(_host(const ChatsListScreen(), 1.3));
    await settleGolden(t);
    await _shot(t, 'chats_list');
  });
  testWidgets('shot notifications', (t) async {
    Get.put<NotificationRepository>(_NRepo());
    Get.put(NotificationController());
    setGoldenView(t, const Size(360, 760));
    await t.pumpWidget(_host(const NotificationsScreen(), 1.3));
    await settleGolden(t);
    await _shot(t, 'notifications');
  });
  testWidgets('shot jobs_landing', (t) async {
    final c = JobsFeedController(
      fetch: ({cityKey, lat, lng, departmentId, minExperience, maxExperience, minSalary, pageToken, int pageSize = 20}) async =>
          NearbyPage<JobFeedItem>(items: [
            JobFeedItem.fromJson(job('a', 3, 'near', 'Nainital')),
            JobFeedItem.fromJson(job('b', 12, 'near', 'Bhimtal')),
            JobFeedItem.fromJson(job('c', 30, 'near', 'Almora')),
          ]),
      gps: () => (lat: 29.4, lng: 79.4),
      lookupsLoader: () async => JobLookups.fromJson(const {}),
    );
    Get.put(c, tag: JobsFeedController.tag);
    setGoldenView(t, const Size(360, 760));
    await t.pumpWidget(_host(const JobsLandingScreenV2(), 1.3));
    await t.pump(const Duration(milliseconds: 900));
    await _shot(t, 'jobs_landing');
  });

  for (final e in screens.entries) {
    testWidgets('shot ${e.key}', (t) async {
      setGoldenView(t, const Size(360, 760));
      await t.pumpWidget(_host(e.value(), 1.3));
      await settleGolden(t);
      await _shot(t, e.key);
      final ex = t.takeException();
      if (ex != null && !'$ex'.contains('MissingPlugin')) fail('$ex');
    });
  }
}
