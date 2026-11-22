import 'package:bakhli/features/buddy/buddies/models/buddy_models.dart';
import 'package:bakhli/features/buddy/shared/buddy_json.dart';
import 'package:bakhli/features/buddy/shared/models/person_models.dart';
import 'package:bakhli/features/buddy/sharing/models/sharing_models.dart';
import 'package:bakhli/features/buddy/viewer/models/viewer_models.dart';
import 'package:bakhli/models/conversation_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://res.cloudinary.com/x/image/upload/c_thumb,g_face,w_160/u/1.jpg';

// raw value -> expected photoUrl; the null key means the field is missing.
const _cases = <String, (bool, Object?, String?)>{
  'missing': (false, null, null),
  'null': (true, null, null),
  'blank': (true, '   ', null),
  'number': (true, 42, null),
  'map': (true, {'url': _url}, null),
  'present': (true, _url, _url),
  'padded': (true, '  $_url  ', _url),
};

Map<String, dynamic> _with(Map<String, dynamic> base, (bool, Object?, String?) c) => {...base, if (c.$1) 'photoUrl': c.$2};

void _each(String name, Map<String, dynamic> base, String? Function(Map<String, dynamic>) parse, {Map<String, dynamic> Function(Map<String, dynamic>)? roundTrip}) {
  group(name, () {
    for (final e in _cases.entries) {
      test(e.key, () {
        final j = _with(base, e.value);
        expect(parse(j), e.value.$3);
        if (roundTrip != null) {
          final back = roundTrip(j);
          expect(back['photoUrl'], e.value.$3);
          expect(parse(back), e.value.$3);
        }
      });
    }
  });
}

void main() {
  test('BuddyJson.photo', () {
    expect(BuddyJson.photo(null), isNull);
    expect(BuddyJson.photo(''), isNull);
    expect(BuddyJson.photo(' '), isNull);
    expect(BuddyJson.photo(1), isNull);
    expect(BuddyJson.photo(true), isNull);
    expect(BuddyJson.photo(' a '), 'a');
  });

  const person = {'userId': 'u1', 'name': 'Aman', 'username': 'Bakhli#1', 'initial': 'A'};
  _each('BuddyPerson', person, (j) => BuddyPerson.fromJson(j).photoUrl, roundTrip: (j) => BuddyPerson.fromJson(j).toJson());
  _each('MoneyPerson', {...person, 'last4': '1234', 'isMe': false, 'status': 'Joined'}, (j) => MoneyPerson.fromJson(j).photoUrl,
      roundTrip: (j) => MoneyPerson.fromJson(j).toJson());
  _each('FoundPerson', {...person, 'relation': 'None'}, (j) => FoundPerson.fromJson(j).photoUrl);
  _each('BuddyItem', {...person, 'isNew': true}, (j) => BuddyItem.fromJson(j).photoUrl);
  _each('BuddyItem.person', {...person, 'isNew': true}, (j) => BuddyItem.fromJson(j).person.photoUrl);
  _each('BlockedPerson', person, (j) => BlockedPerson.fromJson(j).photoUrl);
  _each('JoinedMember', {...person, 'last4': '1234', 'role': 'Viewer', 'isMe': false}, (j) => JoinedMember.fromJson(j).photoUrl);
  _each('InvitedMember', {...person, 'memberId': 'm1'}, (j) => InvitedMember.fromJson(j).photoUrl);
  _each('TravellerDot', const {'userId': 'u1', 'initial': 'A', 'name': 'Aman'}, (j) => TravellerDot.fromJson(j).photoUrl,
      roundTrip: (j) => TravellerDot.fromJson(j).toJson());
  _each('TripOwnerRef', const {'name': 'Rahul', 'username': 'Bakhli#2'}, (j) => TripOwnerRef.fromJson(j).photoUrl,
      roundTrip: (j) => TripOwnerRef.fromJson(j).toJson());

  test('FoundPerson.copyWith keeps the photo', () {
    final p = FoundPerson.fromJson({...person, 'relation': 'None', 'photoUrl': _url});
    expect(p.copyWith(relation: BuddyRelation.requestedByMe).photoUrl, _url);
  });

  test('nested shapes parse the photo of each person', () {
    final r = ReceivedRequest.fromJson({'requestId': 'r', 'person': {...person, 'photoUrl': _url}});
    expect(r.person.photoUrl, _url);
    final s = TripSharingBlock.fromJson({
      'firstTravellers': [
        {'userId': 'u1', 'initial': 'A', 'name': 'Aman', 'photoUrl': _url},
        {'userId': 'u2', 'initial': 'B', 'name': 'Bina'},
      ],
    });
    expect(s.firstTravellers.map((t) => t.photoUrl), [_url, null]);
    final back = TripSharingBlock.fromJson(s.toJson());
    expect(back.firstTravellers.map((t) => t.photoUrl), [_url, null]);
    expect(TripSharingBlock.ownerAlone(userId: 'u', ownerName: 'Me').firstTravellers.single.photoUrl, isNull);
  });

  group('ConversationModel.otherPartyPhotoUrl', () {
    const base = {'id': 'c', 'listingType': 'Stay', 'listingId': 'l', 'otherPartyId': 'o', 'lastMessageAt': '2026-11-22T10:00:00Z'};
    for (final e in _cases.entries) {
      test(e.key, () {
        final j = {...base, if (e.value.$1) 'otherPartyPhotoUrl': e.value.$2};
        expect(ConversationModel.fromJson(j).otherPartyPhotoUrl, e.value.$3);
      });
    }
  });
}
