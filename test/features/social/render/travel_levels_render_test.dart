// Render shots of the travel levels frames L1-L5 (F:/Dhasu/Mode/travel_levels_mock.html).
// 360x800, approved scale, real fonts. Output: F:\Dhasu\Buddy_resume\primary_blue_levels\render_shots\<frame>.png
import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/social/a/profile/seeker_profile_screen.dart';
import 'package:bakhli/features/social/a/profile/travel_levels_screen.dart';
import 'package:bakhli/features/social/a/profile/traveller_profile_screen.dart';
import 'package:bakhli/features/social/b/join/join_requests_screen.dart';
import 'package:bakhli/features/social/b/post/trip_post_screen.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/widgets/level_up_host.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../../../support/real_phone.dart';
import '../b/social_b_test_kit.dart';
import '../shared/social_test_support.dart';

const String _out = r'F:\Dhasu\Buddy_resume\primary_blue_levels\render_shots';
const Size _phone = Size(360, 800);
const double _dpr = 3;

final List<GetPage<dynamic>> _stubs = [
  for (final r in [AppRoutes.main, AppRoutes.people, AppRoutes.settings, AppRoutes.editProfile, AppRoutes.traveller, AppRoutes.joinRequests, AppRoutes.travelBuddies, AppRoutes.dmRoom, AppRoutes.travelLevels])
    GetPage(name: r, page: () => Scaffold(body: Center(child: Text(r)))),
];

Future<void> _open(WidgetTester t, Widget screen) async {
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, screen, size: _phone, devicePixelRatio: _dpr, toastHost: true, pages: _stubs);
  await settle(t);
}

Future<void> _snap(WidgetTester t, String frame) async {
  shotsDir = _out;
  await settle(t, rounds: 2);
  await shot(t, frame);
}

Future<void> _end(WidgetTester t) async {
  await t.pump(const Duration(seconds: 6));
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 6));
}

SocialFakeServer _me(int trips, int level) {
  final server = installServer();
  server.on('GET', '/social/me', socialMeJson(profile: myProfileJson(completedTrips: trips, level: level)));
  putSeeker();
  Get.put(SocialMeController(), permanent: true);
  return server;
}

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(Get.reset);
  tearDown(Get.reset);

  testWidgets('L1 My profile with the level', (t) async {
    _me(124, 4);
    await _open(t, const SeekerProfileScreen());
    await _snap(t, 'L1_my_profile_level');
    await _end(t);
  });

  for (final (trips, level) in [(124, 4), (0, 0), (612, 6)]) {
    testWidgets('L2 Travel levels page at level $level', (t) async {
      _me(trips, level);
      await _open(t, const TravelLevelsScreen());
      await _snap(t, 'L2_travel_levels_$level');
      await _end(t);
    });
  }

  testWidgets('L3 Another traveller', (t) async {
    final server = installServer();
    putSeeker();
    server.on('GET', '/social/travellers/kavya', {
      ...travellerJson(followsMe: true, completedTrips: 46, level: 3),
      'person': {...personJson('kavya', 'Kavya S.', city: 'Dehradun', completedTrips: 46, level: 3), 'gender': 'Female'},
    });
    await _open(t, const TravellerProfileScreen(userId: 'kavya'));
    await _snap(t, 'L3_traveller_level');
    await _end(t);
  });

  testWidgets('L4a Trip post owner row', (t) async {
    final server = installServer();
    putSeeker();
    server.on('GET', '/social/trips/trip-1', {
      ...publicTripJson(cities: ['Manali'], state: 'Himachal Pradesh', when: {'kind': 'within', 'months': 2}, days: 4, seats: 3, seatsLeft: 3),
      'owner': {...personJson('rahul', 'Rahul Verma', city: 'Dehradun', completedTrips: 124, level: 4), 'gender': 'Male'},
    });
    await _open(t, const TripPostScreen(tripId: 'trip-1'));
    await _snap(t, 'L4a_trip_post_level');
    await _end(t);
  });

  testWidgets('L4b Join requests', (t) async {
    final server = installServer();
    putSeeker();
    Map<String, dynamic> item(String id, String user, String name, int tier, int trips, int level, String gender, String note) => {
          'id': id,
          'person': {...rowJson(user, name, followsMe: tier == 1), 'completedTrips': trips, 'level': level, 'gender': gender},
          'tier': tier,
          'note': note,
          'interests': ['Treks', 'Food'],
          'createdAt': '2026-11-26T09:00:00Z',
        };
    server.on('GET', '/social/trips/trip-1/join-requests', {
      'trip': publicTripJson(isMine: true, cities: ['Manali'], when: {'kind': 'within', 'months': 2}, seats: 3, seatsLeft: 3),
      'items': [
        item('jr-r', 'rohan', 'Rohan Mehta', 1, 18, 2, 'Male', 'Same plan here, happy to split the cab from Delhi.'),
        item('jr-m', 'meera', 'Meera Joshi', 2, 0, 0, 'Female', 'First time in Himachal, would love company.'),
      ],
    });
    await _open(t, const JoinRequestsScreen(tripId: 'trip-1'));
    await _snap(t, 'L4b_join_requests_level');
    await _end(t);
  });

  testWidgets('L5 Level-up sheet over My profile', (t) async {
    StorageService.saveSeenTravelLevel('me', 3);
    _me(80, 4);
    await _open(t, const Stack(children: [SeekerProfileScreen(), LevelUpHost()]));
    await _snap(t, 'L5_level_up');
    await _end(t);
  });
}
