// Render shots of every social screen, one PNG per mock frame (F:/Dhasu/Mode/bakhli_social_mock.html, frames A1-E15).
// 360x800, approved scale, real fonts. Output: F:\Dhasu\Buddy_resume\social_design\render_shots\<frame>.png
// (scrolling screens also write <frame>_full.png on a tall phone).
import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/controllers/chat_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/buddy/notices/models/notice_models.dart';
import 'package:bakhli/features/buddy/notices/widgets/notice_row.dart';
import 'package:bakhli/features/buddy/shared/buddy_result.dart';
import 'package:bakhli/features/social/a/edit/edit_profile_screen.dart';
import 'package:bakhli/features/social/a/onboarding/onboarding_steps.dart';
import 'package:bakhli/features/social/a/people/add_buddies_screen.dart';
import 'package:bakhli/features/social/a/people/people_screen.dart';
import 'package:bakhli/features/social/a/profile/seeker_profile_screen.dart';
import 'package:bakhli/features/social/a/profile/traveller_profile_screen.dart';
import 'package:bakhli/features/social/a/settings/settings_screen.dart';
import 'package:bakhli/features/social/a/social_strings_a.dart';
import 'package:bakhli/features/social/b/feed/feed_filter_sheet.dart';
import 'package:bakhli/features/social/b/feed/travel_buddies_screen.dart';
import 'package:bakhli/features/social/b/join/join_requests_screen.dart';
import 'package:bakhli/features/social/b/post/trip_post_screen.dart';
import 'package:bakhli/features/social/b/rail/trips_rail_controller.dart';
import 'package:bakhli/features/social/b/rail/trips_to_join_rail.dart';
import 'package:bakhli/features/social/b/post/own_post_menu.dart';
import 'package:bakhli/features/social/b/social_strings_b.dart';
import 'package:bakhli/features/social/b/widgets/find_buddies_post_card.dart';
import 'package:bakhli/features/social/b/wizard/post_about_step.dart';
import 'package:bakhli/features/social/b/wizard/post_trip_controller.dart';
import 'package:bakhli/features/social/b/wizard/post_trip_screen.dart';
import 'package:bakhli/features/social/b/wizard/post_when_step.dart';
import 'package:bakhli/features/social/b/wizard/post_wizard_parts.dart';
import 'package:bakhli/features/social/c/chat/dm_room_screen.dart';
import 'package:bakhli/features/social/c/chat/models/chat_models.dart';
import 'package:bakhli/features/social/c/chat/room_controller.dart';
import 'package:bakhli/features/social/c/chat/rooms_controller.dart';
import 'package:bakhli/features/social/c/plus/seeker_plus_screen.dart';
import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/features/social/shared/widgets/trip_join_card.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/models/conversation_model.dart';
import 'package:bakhli/screens/chats_list_screen.dart';
import 'package:bakhli/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import '../../../support/onboarding_walk.dart';
import '../../../support/real_phone.dart';
import '../../buddy/sharing/sharing_fixtures.dart' as sf;
import '../b/social_b_test_kit.dart';
import '../c/chat_fakes.dart' as cf;
import '../c/plus_fakes.dart' as pf;
import '../shared/social_test_support.dart';

const String _out = r'F:\Dhasu\Buddy_resume\social_design\render_shots';
const Size _phone = Size(360, 800);
const double _dpr = 3;

// Every named route a screen may push; a render never needs the real page.
final List<GetPage<dynamic>> _stubs = [
  for (final r in [
    AppRoutes.main,
    AppRoutes.people,
    AppRoutes.addBuddies,
    AppRoutes.settings,
    AppRoutes.editProfile,
    AppRoutes.traveller,
    AppRoutes.dmRoom,
    AppRoutes.seekerPlus,
    AppRoutes.buddiesBlocked,
    AppRoutes.myTrips,
    AppRoutes.tripPost,
    AppRoutes.postTrip,
    AppRoutes.joinRequests,
    AppRoutes.travelBuddies,
    AppRoutes.notifications,
  ])
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

// The same tree on a tall phone, so a scrolling screen is seen whole like the mock frame.
Future<void> _snapFull(WidgetTester t, String frame, double height) async {
  t.view.physicalSize = Size(_phone.width * _dpr, height * _dpr);
  await t.pump();
  await _snap(t, '${frame}_full');
  t.view.physicalSize = Size(_phone.width * _dpr, _phone.height * _dpr);
  await t.pump();
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first, warnIfMissed: false);
  await settle(t);
}

// Lets snack and toast timers finish, then drops the tree.
Future<void> _end(WidgetTester t) async {
  await t.pump(const Duration(seconds: 6));
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 6));
}

Map<String, dynamic> _mutuals(int count, String name) => {'count': count, 'names': [name], 'photoUrls': <String>[]};

Map<String, dynamic> _person(String id, String name, {String? city, String gender = ''}) => {...personJson(id, name, city: city), 'gender': gender};

Map<String, dynamic> _minePost({int? waiting = 0}) => {
      ...publicTripJson(
        id: 'mine-1',
        ownerId: 'me',
        ownerName: 'Rahul Verma',
        cities: ['Manali'],
        state: 'Himachal Pradesh',
        when: {'kind': 'within', 'months': 2},
        days: 4,
        seats: 3,
        seatsLeft: 3,
        text: 'Heading to Manali for 4 days in the next 2 months. Looking for a travel buddy, open to anyone. Happy to split a cab. Up for treks.',
        isMine: true,
        waitingRequests: waiting,
      ),
      'owner': _person('me', 'Rahul Verma', city: 'Dehradun', gender: 'Male'),
    };

Map<String, dynamic> _kavyaPost({String myJoin = 'none'}) => {
      ...publicTripJson(
        id: 'trip-1',
        text: 'Heading to Rishikesh for 5 days in December. Rafting and cafes. Looking for 2 easy-going buddies.',
        myJoin: myJoin,
      ),
      'owner': _person('kavya', 'Kavya Sharma', city: 'Dehradun', gender: 'Female'),
    };

Map<String, dynamic> _amanPost() => {
      ...publicTripJson(
        id: 'trip-2',
        ownerId: 'aman',
        ownerName: 'Aman Kumar',
        cities: ['Spiti'],
        state: 'Himachal Pradesh',
        when: {'kind': 'within', 'months': 1},
        days: 6,
        joinGender: 'M',
        seats: 2,
        seatsLeft: 2,
        text: 'Bike loop through Spiti in 6 days. Looking for 2 riders, happy to split fuel.',
      ),
      'owner': _person('aman', 'Aman Kumar', city: 'Delhi', gender: 'Male'),
    };

// The post a traveller opens in frame 11 (Rahul's Manali trip seen by someone else).
Map<String, dynamic> _rahulPost({String myJoin = 'none'}) => {
      ...publicTripJson(
        id: 'trip-1',
        ownerId: 'rahul',
        ownerName: 'Rahul Verma',
        cities: ['Manali'],
        state: 'Himachal Pradesh',
        when: {'kind': 'within', 'months': 2},
        days: 4,
        seats: 3,
        seatsLeft: 3,
        text: 'Heading to Manali for 4 days in the next 2 months. Looking for a travel buddy, open to anyone. Happy to split a cab. Up for treks.',
        myJoin: myJoin,
        mutuals: _mutuals(1, 'Aman'),
      ),
      'owner': {..._person('rahul', 'Rahul Verma', city: 'Dehradun', gender: 'Male'), 'username': 'Bakhli#48291736'},
    };

void _groups(SocialFakeServer server, {List<Map<String, dynamic>> mine = const [], List<Map<String, dynamic>> items = const []}) =>
    stubGroups(server, feed: items, mine: mine);

Map<String, dynamic> _peoplePage(List<Map<String, dynamic>> items, {int? total, int buddies = 0}) =>
    {'items': items, 'nextCursor': null, 'total': total ?? items.length, 'buddies': buddies};

Map<String, dynamic> _row(String id, String name, {String gender = '', bool followsMe = true, bool iFollow = false, bool isBuddy = false, int mutualCount = 0, String? mutualName}) =>
    {...rowJson(id, name, followsMe: followsMe, iFollow: iFollow, isBuddy: isBuddy, mutualCount: mutualCount, mutualName: mutualName), 'gender': gender};

SocialFakeServer _peopleServer() {
  final s = installServer();
  s.on('GET', '/social/followers', _peoplePage([
    _row('kavya', 'Kavya Sharma', gender: 'Female', mutualCount: 1, mutualName: 'Aman'),
    _row('rohan', 'Rohan Mehta', gender: 'Male', iFollow: true, mutualCount: 4, isBuddy: true),
    _row('aman', 'Aman Kumar', gender: 'Male'),
    _row('neha', 'Neha Pant', gender: 'Female', iFollow: true, isBuddy: true),
    _row('meera', 'Meera Joshi', gender: 'Female'),
    _row('sanjay', 'Sanjay Rawat', gender: 'Male'),
  ], total: 128, buddies: 3));
  s.on('GET', '/social/following', _peoplePage([_row('rohan', 'Rohan Mehta', gender: 'Male', iFollow: true)], total: 41));
  s.on('GET', '/social/follow-requests', _peoplePage([
    _row('meera', 'Meera Joshi', gender: 'Female', followsMe: false, mutualCount: 2),
    _row('sana', 'Sana Khan', gender: 'Female', followsMe: false),
  ]));
  s.on('GET', '/buddies', {
    'items': [
      {'userId': 'rohan', 'name': 'Rohan Mehta', 'username': 'Bakhli#52190466', 'initial': 'R', 'isNew': false, 'gender': 'Male', 'tripsTogether': 2, 'mutualCount': 5},
      {'userId': 'neha', 'name': 'Neha Pant', 'username': 'Bakhli#63320918', 'initial': 'N', 'isNew': false, 'gender': 'Female', 'tripsTogether': 1},
      {'userId': 'aman', 'name': 'Aman Kumar', 'username': 'Bakhli#71835204', 'initial': 'A', 'isNew': false, 'gender': 'Male'},
    ],
    'count': 6,
    'nextCursor': null,
  });
  return s;
}

Map<String, dynamic> _kavyaProfile({required bool isBuddy}) => {
      ...travellerJson(followsMe: true, iFollow: isBuddy, isBuddy: isBuddy),
      'person': _person('kavya', 'Kavya Sharma', city: 'Dehradun', gender: 'Female'),
      'about': 'Mountains, chai and long walks. Always up for a sunrise trek.',
      'interests': ['Treks', 'Mountains', 'Photography', 'Culture'],
      'skills': ['Photographer', 'First aid'],
      'places': ['Rishikesh', 'Auli', 'Manali', 'Kasol'],
      'publicTrips': [_kavyaPost()],
    };

Future<PostTripController> _wizard(WidgetTester t, {int step = PostTripController.stepWhere}) async {
  final server = installServer();
  putSocialMe(server, {
    ...socialMeWith(gender: 'Male'),
    'catalog': {
      ...(socialMeJson()['catalog'] as Map<String, dynamic>),
      'postChips': SocialStringsB.defaultPostChips,
    },
  });
  final c = PostTripController(persist: false);
  await _open(t, PostTripScreen(controller: c));
  if (step == PostTripController.stepWhere) return c;
  await _tap(t, find.byKey(const ValueKey('post_city_101')));
  await _tap(t, find.byKey(WizardBottomBar.nextKey));
  if (step == PostTripController.stepAbout) await _tap(t, find.byKey(WizardBottomBar.nextKey));
  return c;
}

Notice _notice(String kind, String actor, {String? tripId, String city = 'Manali', String? refId, String? preview, required DateTime at}) => Notice.fromJson({
      'id': 'n-$kind-$actor',
      'kind': kind,
      'tripId': tripId,
      'tripTitle': '$city trip',
      'tripCity': city,
      'actorUserId': actor.toLowerCase(),
      'actorName': actor,
      'refId': refId,
      'actorPhotoUrl': null,
      'actorUsername': 'Bakhli#52190466',
      'preview': preview,
      'count': 1,
      'createdAt': at.toIso8601String(),
      'updatedAt': at.toIso8601String(),
      'isRead': false,
    });

class _Chat extends ChatController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> loadConversations({bool forceRefresh = false}) async {
    conversations.value = <ConversationModel>[];
  }
}

Map<String, dynamic> _tripRoom(String roomId, String tripId, String title, {int unread = 0, String? preview}) =>
    cf.roomJson(roomId: roomId, kind: 'T', unread: unread, preview: preview, trip: {'tripId': tripId, 'title': title, 'memberCount': 4, 'photoUrls': <String>[], 'memberInitials': ['R', 'M', 'A']});

RoomsController _rooms() {
  final people = [
    ChatRoomModel.fromJson({...cf.roomJson(roomId: 'p1', unread: 2, preview: 'See you at 7 near ISBT'), 'peer': _person('rohan', 'Rohan Mehta', gender: 'Male'), 'peerFollowsMe': true, 'iFollowPeer': true}),
    ChatRoomModel.fromJson({...cf.roomJson(roomId: 'p2', preview: 'Hi! Yes, from 12 Dec.'), 'peer': _person('kavya', 'Kavya Sharma', gender: 'Female'), 'subtitle': 'Rishikesh and Mussoorie'}),
    ChatRoomModel.fromJson({...cf.roomJson(roomId: 'p3', preview: 'Bus leaves at 6 from ISBT'), 'peer': _person('neha', 'Neha Pant', gender: 'Female'), 'subtitle': 'Kasol and Tosh'}),
  ];
  final trips = [
    ChatRoomModel.fromJson(_tripRoom('t1', 'x1', 'Manali', unread: 3, preview: 'Rohan: Booked the cab for 6 AM')),
    ChatRoomModel.fromJson(_tripRoom('t2', 'x2', 'Rishikesh', preview: 'Kavya: Rafting slot is 10 AM')),
  ];
  final requests = [
    cf.roomOf(roomId: 'q1', status: 'Request', iStarted: false, preview: 'Hi Rahul, are you also going to Auli in January?'),
    cf.roomOf(roomId: 'q2', status: 'Request', iStarted: false, preview: 'Saw your Manali post. Is there a seat left?'),
  ];
  final api = cf.FakeChatApi()
    ..pages[RoomBucket.people] = BuddyOk(RoomsPage(items: people))
    ..pages[RoomBucket.trips] = BuddyOk(RoomsPage(items: trips))
    ..pages[RoomBucket.requests] = BuddyOk(RoomsPage(items: requests));
  return Get.put(RoomsController(api: api, transport: cf.FakeTransport(), myId: () => cf.myId), permanent: true);
}

RoomController _room(cf.FakeChatApi api) => RoomController(roomId: 'r1', api: api, transport: cf.FakeTransport(), myId: () => cf.myId);

void main() {
  useBuddyRenderScale();
  setUpAll(initSocialTestStorage);
  setUp(Get.reset);
  tearDown(Get.reset);

  group('A onboarding', () {
    Future<void> start(WidgetTester t) async {
      putSeeker(profileCompleted: false, gender: null);
      TripCityCatalog.to.seedForTest(const [
        TripCityModel(cityKey: 1, name: 'Rishikesh', districtName: 'Dehradun', stateName: 'Uttarakhand', latitude: 30.1, longitude: 78.3),
      ]);
      installServer();
      await _open(t, const OnboardingScreen());
    }

    Future<void> fillYou(WidgetTester t) async {
      final c = OnboardingWalk.controllerOf(t);
      c.gender.value = SocialStringsA.male;
      c.birthMonth.value = 8;
      c.birthYear.value = 1998;
      await settle(t);
    }

    Future<void> fillStyle(WidgetTester t) async {
      final c = OnboardingWalk.controllerOf(t);
      await _tap(t, find.byKey(OnboardingBottom.buttonKey));
      c.interests.assignAll(const ['Mountains', 'Treks', 'Food']);
      c.skills.assignAll(const ['Photographer', 'Driver']);
      c.places.assignAll(const ['Rishikesh', 'Nainital', 'Manali']);
      await settle(t);
    }

    testWidgets('A1 You', (t) async {
      await start(t);
      await _snap(t, 'A1_onboarding_you');
      await _snapFull(t, 'A1_onboarding_you', 1100);
      await fillYou(t);
      await _snap(t, 'A1_onboarding_you_filled');
      await _end(t);
    });

    testWidgets('A2 Travel style', (t) async {
      await start(t);
      final c = OnboardingWalk.controllerOf(t);
      await fillYou(t);
      await fillStyle(t);
      expect(c.step.value, 1);
      await _snap(t, 'A2_onboarding_travel_style');
      await _snapFull(t, 'A2_onboarding_travel_style', 1300);
      await _end(t);
    });

    testWidgets('A3 About you', (t) async {
      await start(t);
      final c = OnboardingWalk.controllerOf(t);
      await fillYou(t);
      await fillStyle(t);
      await _tap(t, find.byKey(OnboardingBottom.buttonKey));
      c.about.value = 'Hills over beaches. Chai at every stop.';
      await settle(t);
      expect(c.step.value, 2);
      await _snap(t, 'A3_onboarding_about');
      await _snapFull(t, 'A3_onboarding_about', 1300);
      await _end(t);
    });
  });

  group('B my profile', () {
    SocialFakeServer me() {
      final server = installServer();
      server.on('GET', '/social/me', socialMeJson(profile: {...myProfileJson(), 'publicTrips': [_minePost()]}));
      putSeeker();
      Get.put(SocialMeController(), permanent: true);
      return server;
    }

    testWidgets('B4 My profile', (t) async {
      me();
      await _open(t, const SeekerProfileScreen());
      await _snap(t, 'B4_my_profile');
      await _snapFull(t, 'B4_my_profile', 1700);
      await _end(t);
    });

    testWidgets('B5 Edit profile', (t) async {
      me();
      await _open(t, const EditProfileScreen());
      await _snap(t, 'B5_edit_profile');
      await _snapFull(t, 'B5_edit_profile', 2000);
      await _end(t);
    });

    testWidgets('B6 Settings', (t) async {
      me();
      await _open(t, const SettingsScreen());
      await _snap(t, 'B6_settings');
      await _snapFull(t, 'B6_settings', 2600);
      await _end(t);
    });
  });

  group('C other people', () {
    testWidgets('C7 Other traveller (follows me)', (t) async {
      putSeeker();
      installServer().on('GET', '/social/travellers/kavya', _kavyaProfile(isBuddy: false));
      await _open(t, const TravellerProfileScreen(userId: 'kavya'));
      await _snap(t, 'C7_other_traveller');
      await _snapFull(t, 'C7_other_traveller', 1700);
      await _end(t);
    });

    testWidgets('C7b Buddy', (t) async {
      putSeeker();
      installServer().on('GET', '/social/travellers/kavya', _kavyaProfile(isBuddy: true));
      await _open(t, const TravellerProfileScreen(userId: 'kavya'));
      await _snap(t, 'C7b_other_traveller_buddy');
      await _end(t);
    });

    testWidgets('C8 People: Followers', (t) async {
      putSeeker();
      _peopleServer();
      await _open(t, const PeopleScreen(tab: 'followers'));
      await _snap(t, 'C8_people_followers');
      await _end(t);
    });

    testWidgets('C8b Requests', (t) async {
      putSeeker();
      _peopleServer();
      await _open(t, const PeopleScreen(tab: 'requests'));
      await _snap(t, 'C8b_people_requests');
      await _end(t);
    });

    testWidgets('C8c My Buddies', (t) async {
      putSeeker();
      _peopleServer();
      await _open(t, const PeopleScreen(tab: 'buddies'));
      await _snap(t, 'C8c_people_my_buddies');
      await _end(t);
    });

    testWidgets('C8d Add from followers', (t) async {
      putSeeker();
      _peopleServer();
      await _open(t, const AddBuddiesScreen());
      await _snap(t, 'C8d_add_from_followers');
      await _end(t);
    });
  });

  group('D public trips and joining', () {
    testWidgets('D9 Home rail: Trips to join', (t) async {
      putSeeker();
      installServer().on('GET', '/social/trips/rail', {
        'items': [_minePost(), _kavyaPost(), _amanPost()],
      });
      Get.put(TripsRailController(), permanent: true);
      await _open(t, const Scaffold(body: SafeArea(child: SingleChildScrollView(child: TripsToJoinRail()))));
      await _snap(t, 'D9_home_trips_to_join_rail');
      await _end(t);
    });

    testWidgets('D9b Travel buddies, D9c Filters', (t) async {
      putSeeker();
      final server = installServer();
      putSocialMe(server, socialMeWith(gender: 'Male'));
      Get.put<PlanController>(pf.FakePlanController());
      _groups(server, items: [_kavyaPost(), _amanPost()]);
      await _open(t, const TravelBuddiesScreen());
      await _snap(t, 'D9b_travel_buddies');
      await _snapFull(t, 'D9b_travel_buddies', 1700);
      await _tap(t, find.byKey(TravelBuddiesScreen.filterKey));
      expect(find.byKey(FeedFilterSheet.showKey, skipOffstage: false), findsOneWidget);
      await _snap(t, 'D9c_filters');
      await _end(t);
    });

    testWidgets('D10 Trip menu: Post to find buddies', (t) async {
      putSeeker();
      final server = installServer();
      putSocialMe(server, socialMeWith(gender: 'Male'));
      await _open(t, sf.overview(sf.trip(sharing: sf.aloneBlock()), sf.aloneBlock()));
      await _tap(t, find.byKey(const ValueKey('overview_menu')));
      expect(find.text(SocialStringsB.postToFindBuddies), findsOneWidget);
      expect(find.text(SocialStringsB.postToFindBuddiesLine), findsOneWidget);
      await _snap(t, 'D10_trip_menu_post_to_find_buddies');
      await _end(t);
    });

    testWidgets('D10b Wizard: Where', (t) async {
      putSeeker();
      seedCities();
      await _wizard(t);
      await _tap(t, find.byKey(const ValueKey('post_city_101')));
      await _snap(t, 'D10b_wizard_where');
      await _end(t);
    });

    testWidgets('D10c When: Roughly, D10d Exact date, D10e Women tapped (Plus box)', (t) async {
      putSeeker();
      seedCities();
      await _wizard(t, step: PostTripController.stepWhen);
      await _snap(t, 'D10c_wizard_when_roughly');
      await _snapFull(t, 'D10c_wizard_when_roughly', 1200);
      await _tap(t, find.text(SocialStringsB.exactDate));
      await _tap(t, find.byKey(const ValueKey('post_date_2')));
      await _snap(t, 'D10d_wizard_when_exact');
      await _snapFull(t, 'D10d_wizard_when_exact', 1200);
      await _tap(t, find.descendant(of: find.byKey(PostWhenStep.whoKey), matching: find.text(SocialStringsB.women)));
      await _snap(t, 'D10e_wizard_when_men_only_plus');
      await _snapFull(t, 'D10e_wizard_when_men_only_plus', 1300);
      await _end(t);
    });

    testWidgets('D10f About', (t) async {
      putSeeker();
      seedCities();
      await _wizard(t, step: PostTripController.stepAbout);
      await _tap(t, find.byKey(const ValueKey('post_chip_Happy to split a cab')));
      await _tap(t, find.byKey(const ValueKey('post_chip_Up for treks')));
      await _snap(t, 'D10f_wizard_about');
      await _snapFull(t, 'D10f_wizard_about', 1300);
      await _end(t);
    });

    testWidgets('D10g Live: My posts tab with the live card', (t) async {
      putSeeker();
      final server = installServer();
      putSocialMe(server, socialMeWith(gender: 'Male', publicUsed: 1));
      _groups(server, mine: [_minePost()], items: [_kavyaPost()]);
      await _open(t, const TravelBuddiesScreen(posted: true));
      await _snap(t, 'D10g_feed_live');
      await _snapFull(t, 'D10g_feed_live', 1700);
      await _end(t);
    });

    testWidgets('D11 Trip post, D11c Request to join', (t) async {
      putSeeker();
      final server = installServer();
      putSocialMe(server, socialMeWith(gender: 'Male'));
      server.on('GET', '/social/trips/trip-1', _rahulPost());
      await _open(t, const TripPostScreen(tripId: 'trip-1'));
      await _snap(t, 'D11_trip_post');
      await _snapFull(t, 'D11_trip_post', 1200);
      await _tap(t, find.byKey(TripPostScreen.requestKey));
      await _snap(t, 'D11c_request_to_join_sheet');
      await _end(t);
    });

    testWidgets('D11b Women-only trip seen by a man (This trip is for women only)', (t) async {
      putSeeker();
      final server = installServer();
      putSocialMe(server, socialMeWith(gender: 'Male'));
      server.on('GET', '/social/trips/trip-1', {
        ...publicTripJson(
          ownerId: 'neha',
          ownerName: 'Neha Pant',
          cities: ['Kasol'],
          state: 'Himachal Pradesh',
          joinGender: 'F',
          notOpen: true,
          text: 'Kasol and Tosh in 4 days in January. Cafes, river walks and the Tosh trail. Looking for 2 women to share a stay and a cab.',
          seats: 3,
          seatsLeft: 2,
        ),
        'owner': {..._person('neha', 'Neha Pant', city: 'Delhi', gender: 'Female'), 'username': 'Bakhli#63320918'},
      });
      await _open(t, const TripPostScreen(tripId: 'trip-1'));
      await _snap(t, 'D11b_trip_not_open');
      await _end(t);
    });

    testWidgets('D11d Requested', (t) async {
      putSeeker();
      final server = installServer();
      putSocialMe(server, socialMeWith(gender: 'Male', joinUsed: 1));
      server.on('GET', '/social/trips/trip-1', _rahulPost(myJoin: 'requested'));
      await _open(t, const TripPostScreen(tripId: 'trip-1'));
      await _snap(t, 'D11d_trip_post_requested');
      await _end(t);
    });

    testWidgets('D12 Bell rows', (t) async {
      final now = DateTime.utc(2026, 11, 26, 10);
      final rows = [
        _notice(NoticeKinds.joinRequest, 'Rohan M.', tripId: 'trip-1', refId: 'jr-1', preview: 'Same plan here, happy to split the cab from Delhi...', at: now.subtract(const Duration(minutes: 2))),
        _notice(NoticeKinds.joinRequest, 'Meera J.', tripId: 'trip-1', refId: 'jr-2', preview: 'First time in Himachal, would love company.', at: now.subtract(const Duration(hours: 1))),
        _notice(NoticeKinds.joinAccepted, 'Kavya S.', tripId: 'trip-2', city: 'Rishikesh', at: now.subtract(const Duration(hours: 3))),
        _notice(NoticeKinds.followRequest, 'Sana K.', at: now.subtract(const Duration(hours: 5))),
        _notice(NoticeKinds.followedPosted, 'Aman K.', tripId: 'trip-4', city: 'Spiti', at: now.subtract(const Duration(days: 1))),
      ];
      await _open(
        t,
        Scaffold(
          body: SafeArea(child: ListView(children: [for (final n in rows) NoticeRow(notice: n, now: now, onTap: () {})])),
        ),
      );
      await _snap(t, 'D12_bell_rows');
      await _end(t);
    });

    testWidgets('D12b Join requests', (t) async {
      putSeeker();
      Map<String, dynamic> item(String id, String userId, String name, int tier, String gender, {String? note, int mutualCount = 0, String? mutualName}) => {
            'id': id,
            'person': _row(userId, name, gender: gender, followsMe: tier == 1, mutualCount: mutualCount, mutualName: mutualName),
            'tier': tier,
            'note': note,
            'interests': ['Treks', 'Food'],
            'createdAt': '2026-11-26T09:00:00Z',
          };
      installServer().on('GET', '/social/trips/trip-1/join-requests', {
        'trip': _minePost(waiting: 2),
        'items': [
          item('jr-r', 'rohan', 'Rohan Mehta', 1, 'Male', note: 'Same plan here, happy to split the cab from Delhi. Done Hampta Pass last year.', mutualCount: 3),
          item('jr-m', 'meera', 'Meera Joshi', 2, 'Female', note: 'First time in Himachal, would love company.', mutualCount: 1, mutualName: 'Aman'),
        ],
      });
      await _open(t, const JoinRequestsScreen(tripId: 'trip-1'));
      await _snap(t, 'D12b_join_requests');
      await _snapFull(t, 'D12b_join_requests', 1200);
      await _end(t);
    });

    testWidgets('D12c My trip with members: chat icon with unread', (t) async {
      putSeeker();
      final api = cf.FakeChatApi()
        ..pages[RoomBucket.trips] = BuddyOk(RoomsPage(items: [ChatRoomModel.fromJson(_tripRoom('t1', sf.tripId, 'Uttarakhand Hills Trip', unread: 3))]));
      Get.put(RoomsController(api: api, transport: cf.FakeTransport(), myId: () => cf.myId), permanent: true);
      await _open(t, sf.overview(sf.trip(sharing: sf.sharedBlock()), sf.sharedBlock()));
      expect(find.byKey(const ValueKey('overview_trip_chat')), findsOneWidget);
      await _snap(t, 'D12c_trip_overview_chat_icon');
      await _end(t);
    });
  });

  group('E chat and Plus', () {
    Future<void> chats(WidgetTester t) async {
      final auth = putSeeker();
      auth.shellKind.value = ShellKind.seeker;
      Get.put<ChatController>(_Chat());
      _rooms();
      await _open(t, const ChatsListScreen());
    }

    testWidgets('E13 Chats: People, E13b Trips, Requests', (t) async {
      await chats(t);
      await _snap(t, 'E13_chats_people');
      await t.tap(find.text(SocialStringsC.trips).first);
      await settle(t);
      await _snap(t, 'E13b_chats_trips');
      await t.tap(find.text(SocialStringsC.requests).first);
      await settle(t);
      await _snap(t, 'E13x_chats_requests');
      await _end(t);
    });

    testWidgets('E13c Trip chat', (t) async {
      final api = cf.FakeChatApi()
        ..roomResult = BuddyOk(ChatRoomModel.fromJson(_tripRoom('r1', 't1', 'Manali')))
        ..messagesResult = BuddyOk(MessagesPage(items: [
          cf.msgOf(1, system: 'joined', text: 'Meera joined the trip'),
          cf.msgOf(2, sender: 'u-rohan', senderName: 'Rohan M.', text: 'Booked the cab for 6 AM from Delhi.'),
          cf.msgOf(3, sender: 'u-meera', senderName: 'Meera J.', text: 'Hi all! I will bring snacks for the drive.'),
          cf.msgOf(4, sender: cf.myId, masked: true, text: 'Great. Day 2 is Solang, keep warm clothes. Call me on •••• hidden'),
        ], lastSeq: 4));
      await _open(t, DmRoomScreen(controller: _room(api)));
      await _snap(t, 'E13c_trip_chat');
      await _end(t);
    });

    testWidgets('E14 Chat, sender locked after the first message', (t) async {
      Get.put<SocialMeController>(pf.FakeSocialMeController(pf.freeLimits()));
      final api = cf.FakeChatApi()
        ..roomResult = BuddyOk(ChatRoomModel.fromJson({
          ...cf.roomJson(status: 'Request', iStarted: true, lock: 'plus', canSend: false),
          'peer': _person(cf.peerId, 'Kavya Sharma', gender: 'Female'),
          'subtitle': 'Rishikesh and Mussoorie',
        }))
        ..messagesResult = BuddyOk(MessagesPage(items: [cf.msgOf(1, sender: cf.myId, text: 'Hi Kavya, I saw your Rishikesh plan. Are you going in mid Dec too?')], lastSeq: 1));
      await _open(t, DmRoomScreen(controller: _room(api)));
      expect(find.byKey(const ValueKey('dm_chat_more_plus')), findsOneWidget);
      await _snap(t, 'E14_chat_sender_locked');
      await _end(t);
    });

    testWidgets('E14b Chat, receiver replies free', (t) async {
      final api = cf.FakeChatApi()
        ..roomResult = BuddyOk(ChatRoomModel.fromJson({
          ...cf.roomJson(status: 'Request', iStarted: false),
          'peer': _person(cf.peerId, 'Rahul Verma', gender: 'Male'),
        }))
        ..messagesResult = BuddyOk(MessagesPage(items: [cf.msgOf(1, text: 'Hi Kavya, I saw your Rishikesh plan. Are you going in mid Dec too?')], lastSeq: 1));
      await _open(t, DmRoomScreen(controller: _room(api)));
      expect(find.text(SocialStringsC.replyFree), findsOneWidget);
      await _snap(t, 'E14b_chat_receiver');
      await _end(t);
    });

    testWidgets('E15 Bakhli Plus', (t) async {
      Get.put<PlanController>(pf.FakePlanController());
      Get.put<SocialMeController>(pf.FakeSocialMeController(pf.freeLimits()));
      await _open(t, const SeekerPlusScreen(from: 'chat'));
      await _snap(t, 'E15_bakhli_plus');
      await _snapFull(t, 'E15_bakhli_plus', 1500);
      await _end(t);
    });
  });

  group('N post notify (follow-post-push)', () {
    Map<String, dynamic> withLimits(Map<String, dynamic> me, Map<String, dynamic> extra) => {...me, 'limits': {...me['limits'] as Map<String, dynamic>, ...extra}};

    testWidgets('N1 About with Notify travellers near me ON', (t) async {
      putSeeker();
      seedCities();
      final c = await _wizard(t, step: PostTripController.stepAbout);
      c.setNotifyNearby(true);
      await t.ensureVisible(find.byKey(PostAboutStep.notifyKey));
      await settle(t);
      await _snap(t, 'N1_wizard_notify_nearby');
      await _snapFull(t, 'N1_wizard_notify_nearby', 1400);
      await _end(t);
    });

    testWidgets('N2 About: an older answer with the week used still shows a live switch (no weekly limit)', (t) async {
      putSeeker();
      seedCities();
      await _wizard(t, step: PostTripController.stepAbout);
      SocialMeController.to.me.value = SocialMe.fromJson(withLimits(socialMeWith(gender: 'Male'), {
        'notifyPosts': {'limit': 2, 'used': 2},
        'notifyNextAt': '2026-12-02T04:00:00Z',
      }));
      await settle(t);
      await t.ensureVisible(find.byKey(PostAboutStep.notifyKey));
      await settle(t);
      expect(find.text(SocialStringsB.notifyNearbyLine), findsOneWidget);
      await _snap(t, 'N2_wizard_notify_used');
      await _end(t);
    });

    testWidgets('N3 Feed: a Full post and a removed member', (t) async {
      putSeeker();
      final server = installServer();
      putSocialMe(server, socialMeWith(gender: 'Male'));
      _groups(server, items: [{..._kavyaPost(), 'requestsFull': true}, _amanPost()..['myJoin'] = 'removed']);
      await _open(t, const TravelBuddiesScreen());
      await _snapFull(t, 'N3_feed_full_removed', 1700);
      await _end(t);
    });

    testWidgets('N4 Free limit reached: Home and My Trips cards, feed Post button', (t) async {
      putSeeker();
      final server = installServer();
      final me = putSocialMe(server, socialMeWith(gender: 'Male', publicUsed: 1));
      await t.runAsync(me.load);
      await _open(
        t,
        const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(children: [FindBuddiesPostCard(place: FindBuddiesPostPlace.home), FindBuddiesPostCard(place: FindBuddiesPostPlace.myTrips)]),
            ),
          ),
        ),
      );
      expect(find.text(SocialStringsB.freeLimitHint), findsNWidgets(2));
      await _snap(t, 'N4_post_cards_free_limit');
      await _end(t);
    });

    testWidgets('N5 Trip chat for a Free member: the composer shows before his first message', (t) async {
      Get.put<SocialMeController>(pf.FakeSocialMeController(SocialLimits.fromJson({...socialMeJson()['limits'] as Map<String, dynamic>, 'groupChat': false})));
      final api = cf.FakeChatApi()
        ..roomResult = BuddyOk(ChatRoomModel.fromJson(_tripRoom('r1', 't1', 'Manali')))
        ..messagesResult = BuddyOk(MessagesPage(items: [
          cf.msgOf(1, system: 'joined', text: 'Meera joined the trip'),
          cf.msgOf(2, sender: 'u-rohan', senderName: 'Rohan M.', text: 'Booked the cab for 6 AM from Delhi.'),
        ], lastSeq: 2));
      await _open(t, DmRoomScreen(controller: _room(api)));
      expect(find.byKey(const ValueKey('dm_composer')), findsOneWidget);
      await _snap(t, 'N5_trip_chat_free_member');
      await _end(t);
    });

    testWidgets('N6 Settings: Trips of people I follow and Trips near me', (t) async {
      putSeeker();
      final server = installServer();
      server.on('GET', '/social/me', socialMeJson(profile: myProfileJson()));
      Get.put(SocialMeController(), permanent: true);
      await _open(t, const SettingsScreen());
      await t.ensureVisible(find.byKey(SettingsScreen.nearbyKey));
      await settle(t);
      await _snap(t, 'N6_settings_notifications');
      await _end(t);
    });

    testWidgets('N7 Own post on My posts: the own-post menu (Edit, Members, Delete), no Remove, no 72-hour lock', (t) async {
      putSeeker();
      final server = installServer();
      putSocialMe(server, socialMeWith(gender: 'Male', publicUsed: 1));
      _groups(server, mine: [_minePost()], items: [_kavyaPost()]);
      await _open(t, const TravelBuddiesScreen(myPosts: true));
      final menu = find.descendant(of: find.byKey(TripJoinCard.cardKey('mine-1')), matching: find.byKey(TripJoinCard.menuKey));
      expect(menu, findsOneWidget);
      expect(find.textContaining('remove this post'), findsNothing);
      await _tap(t, menu);
      expect(find.byKey(OwnPostMenu.editKey), findsOneWidget);
      expect(find.byKey(OwnPostMenu.membersKey), findsOneWidget);
      expect(find.byKey(OwnPostMenu.deleteKey), findsOneWidget);
      expect(find.textContaining('Remove from'), findsNothing);
      await _snap(t, 'N7_own_post_menu');
      await _end(t);
    });
  });
}
