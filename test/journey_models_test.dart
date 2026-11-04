import 'dart:convert';

import 'package:bakhli/features/taxi/journeys/journey_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> contact(String id) => {
      'taxiId': id,
      'driverName': 'Ravi',
      'vehicleTypeName': 'Innova',
      'seats': 7,
      'plateDisplay': 'UK07 AB 1234',
      'cityName': 'Haridwar',
      'tripReplyLabel': 'app',
      'phone': '9876543210',
      'whatsApp': '9876543210',
      'available': true,
    };

Map<String, dynamic> leg(int i, {String status = 'Unknown', String? asked}) => {
      'legIndex': i,
      'legKey': 'l1~a$i~a${i + 1}',
      'fromName': 'A$i',
      'fromLat': 28.6,
      'fromLng': 77.2,
      'toName': 'A${i + 1}',
      'toLat': 29.9,
      'toLng': 78.1,
      'meetingPlace': null,
      'driver': contact('d$i'),
      'backups': [contact('b$i')],
      'listedFare': 4200,
      'partial': false,
      'lastEnquiryId': null,
      'lastKnownStatus': status,
      'lastQuotedFare': null,
      'lastKnownAt': asked,
      'driverAvailable': true,
      'fareChanged': false,
    };

Map<String, dynamic> journey({String status = 'Ready'}) => {
      'id': 'j1',
      'fromName': 'Delhi',
      'fromLat': 28.6,
      'fromLng': 77.2,
      'toName': 'Badrinath',
      'toLat': 30.7,
      'toLng': 79.4,
      'date': '2026-11-20',
      'people': 4,
      'planKey': 'p1~a1~a2~a3',
      'cars': 2,
      'status': status,
      'listedTotal': 14000,
      'createdAt': '2026-11-04T10:00:00Z',
      'updatedAt': '2026-11-04T10:00:00Z',
      'lastRefreshedAt': null,
      'legs': [leg(1), leg(2)],
    };

void main() {
  test('status parse', () {
    expect(JourneyStatus.parse('Ready'), JourneyStatus.ready);
    expect(JourneyStatus.parse('DriverUnavailable'), JourneyStatus.driverUnavailable);
    expect(JourneyStatus.parse('NotAsked'), JourneyStatus.notAsked);
    expect(JourneyStatus.parse('Completed'), JourneyStatus.completed);
  });

  test('leg status parse with unknown fallback', () {
    expect(LegStatus.parse('Free'), LegStatus.free);
    expect(LegStatus.parse('NotFree'), LegStatus.notFree);
    expect(LegStatus.parse('NoAnswer'), LegStatus.noAnswer);
    expect(LegStatus.parse('Unknown'), LegStatus.unknown);
    expect(LegStatus.parse('weird'), LegStatus.unknown);
  });

  test('fromJson reads the server shape', () {
    final j = SavedJourney.fromJson(journey());
    expect(j.legs.length, 2);
    expect(j.cars, 2);
    expect(j.people, 4);
    expect(j.listedTotal, 14000);
    expect(j.legs.first.backups.single.taxiId, 'b1');
    expect(j.legs.first.driver.phone, '9876543210');
    expect(j.date.year, 2026);
  });

  test('toJson round trip keeps the plan', () {
    final a = SavedJourney.fromJson(journey(status: 'NotAsked'));
    final b = SavedJourney.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
    expect(b.id, a.id);
    expect(b.status, JourneyStatus.notAsked);
    expect(b.legs.length, a.legs.length);
    expect(b.legs.last.driver.taxiId, 'd2');
    expect(b.legs.last.listedFare, 4200);
  });

  test('statusLine wording', () {
    final now = DateTime.utc(2026, 11, 4, 12);
    final asked = now.subtract(const Duration(hours: 3)).toIso8601String();
    String line(String s, {String? at}) =>
        JourneyFormat.statusLine(SavedJourneyLeg.fromJson(leg(1, status: s, asked: at)), now);
    expect(line('Unknown'), 'Not asked yet');
    expect(line('NotFree', at: asked), 'Not free');
    expect(line('Free', at: asked), 'Free · asked 3 h ago');
    expect(line('NoAnswer', at: asked), 'No answer yet · asked 3 h ago');
  });
}
