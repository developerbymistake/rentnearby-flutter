import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:get/get.dart';

import '../shared/social_test_support.dart';

Map<String, dynamic> publicTripJson({
  String id = 'trip-1',
  String ownerId = 'kavya',
  String ownerName = 'Kavya Sharma',
  List<String> cities = const ['Rishikesh'],
  String? state = 'Uttarakhand',
  Map<String, dynamic> when = const {'kind': 'month', 'month': 202612},
  int days = 5,
  String joinGender = 'A',
  int seats = 3,
  int seatsLeft = 2,
  String text = 'Heading to Rishikesh for 5 days in December. Rafting and cafes.',
  String myJoin = 'none',
  bool isMine = false,
  int? waitingRequests,
  bool notOpen = false,
  bool sample = false,
  Map<String, dynamic>? mutuals,
  String? travelMode,
  int ownerTrips = 0,
  int ownerLevel = 0,
}) =>
    {
      'tripId': id,
      'owner': personJson(ownerId, ownerName, city: 'Dehradun', completedTrips: ownerTrips, level: ownerLevel),
      'ownerInterests': ['Mountains', 'Treks'],
      'isMine': isMine,
      'cityKey': 0,
      'cityNames': cities,
      'stateName': state,
      'when': when,
      'days': days,
      'joinGender': joinGender,
      'seats': seats,
      'seatsLeft': seatsLeft,
      'text': text,
      'publishedAt': '2026-11-20T10:00:00Z',
      'myJoin': myJoin,
      'waitingRequests': waitingRequests,
      'iFollowOwner': false,
      'mutuals': mutuals,
      'sample': sample,
      'notOpen': notOpen,
      'travelMode': travelMode,
    };

Map<String, dynamic> socialMeWith({bool isPlus = false, bool genderOnly = false, bool nearMe = false, int joinUsed = 0, int publicUsed = 0, String gender = 'Male'}) {
  final me = socialMeJson(profile: {...myProfileJson(), 'gender': gender}, isPlus: isPlus);
  final limits = Map<String, dynamic>.from(me['limits'] as Map);
  limits['genderOnlyTrips'] = genderOnly;
  limits['nearMe'] = nearMe;
  limits['joinRequests'] = {'limit': isPlus ? 5 : 1, 'used': joinUsed};
  limits['publicTrips'] = {'limit': isPlus ? 3 : 1, 'used': publicUsed};
  me['limits'] = limits;
  return me;
}

/// Puts a session [SocialMeController] that loads [me] from the fake server.
SocialMeController putSocialMe(SocialFakeServer server, Map<String, dynamic> me) {
  server.on('GET', '/social/me', me);
  return Get.put(SocialMeController(), permanent: true);
}

const manali = TripCityModel(cityKey: 101, name: 'Manali', stateName: 'Himachal Pradesh', latitude: 32.2, longitude: 77.2, spotCount: 22);
const kasol = TripCityModel(cityKey: 102, name: 'Kasol', stateName: 'Himachal Pradesh', latitude: 32.0, longitude: 77.3, spotCount: 9);
const shimla = TripCityModel(cityKey: 103, name: 'Shimla', stateName: 'Himachal Pradesh', latitude: 31.1, longitude: 77.2, spotCount: 18);
const dharamshala = TripCityModel(cityKey: 104, name: 'Dharamshala', stateName: 'Himachal Pradesh', latitude: 32.2, longitude: 76.3, spotCount: 12);
const tosh = TripCityModel(cityKey: 105, name: 'Tosh', stateName: 'Himachal Pradesh', latitude: 32.0, longitude: 77.4, spotCount: 4);
const rishikesh = TripCityModel(cityKey: 201, name: 'Rishikesh', stateName: 'Uttarakhand', latitude: 30.1, longitude: 78.3, spotCount: 20);
const notReady = TripCityModel(cityKey: 202, name: 'Chopta', stateName: 'Uttarakhand', latitude: 30.4, longitude: 79.2, status: TripCityStatus.notReady);

void seedCities() => TripCityCatalog.to.seedForTest(const [manali, kasol, shimla, dharamshala, tosh, rishikesh, notReady]);
