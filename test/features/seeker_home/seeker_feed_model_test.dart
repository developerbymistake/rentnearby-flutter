import 'dart:convert';
import 'dart:io';

import 'package:bakhli/features/seeker_home/seeker_feed_model.dart';
import 'package:bakhli/features/seeker_home/seeker_status_rule.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/owner_fakes.dart';

Map<String, dynamic> _sample(String name) =>
    jsonDecode(File('test/features/seeker_home/samples/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('SeekerFeed.fromJson', () {
    test('o_sk_2_modelVariants: every variant parses without a throw', () {
      for (final name in ['seeker_feed', 'seeker_feed_on_trip']) {
        for (final v in jsonVariants(_sample(name))) {
          expect(() => SeekerFeed.fromJson(v), returnsNormally);
          expect(() => SeekerFeed.fromJson(v).toJson(), returnsNormally);
        }
      }
    });

    test('wrong root types give the empty feed', () {
      for (final raw in <Object?>[null, 'x', 7, <Object?>[], true]) {
        final f = SeekerFeed.fromJson(raw);
        expect(f.tripCard.hasTrip, isFalse);
        expect(f.status, isNull);
        expect(f.slots, isNull);
      }
    });

    test('in progress sample reads every field', () {
      final f = SeekerFeed.fromJson(_sample('seeker_feed'));
      expect(f.tripCard.state, SeekerTripState.inProgress);
      expect(f.tripCard.tripId, 'trip-1');
      expect(f.tripCard.done, 3);
      expect(f.tripCard.total, 5);
      expect(f.tripCard.nextStep?.kind, SeekerStepKind.taxi);
      expect(f.tripCard.startDate, DateTime(2026, 11, 26));
      expect(f.status?.kind, SeekerStatusKind.confirmed);
      expect(f.slots?.full, isFalse);
    });

    test('round trip through toJson keeps the card', () {
      final f = SeekerFeed.fromJson(_sample('seeker_feed_on_trip'));
      final back = SeekerFeed.fromJson(jsonDecode(jsonEncode(f.toJson())));
      expect(back.tripCard.state, SeekerTripState.onTrip);
      expect(back.tripCard.today?.cityName, 'Mukteshwar');
      expect(back.tripCard.today?.placesSeen, isNull);
    });

    test('unknown state is None, unknown status kind is no line, unknown step kind is no Next line', () {
      final j = _sample('seeker_feed');
      final f = SeekerFeed.fromJson({
        ...j,
        'tripCard': {...j['tripCard'] as Map<String, dynamic>, 'state': 'Paused'},
        'status': {...j['status'] as Map<String, dynamic>, 'kind': 'Waiting'},
      });
      expect(f.tripCard.hasTrip, isFalse);
      expect(f.status, isNull);
      final g = SeekerFeed.fromJson({
        ...j,
        'tripCard': {...j['tripCard'] as Map<String, dynamic>, 'nextStep': {'key': 'x', 'kind': 'Boat'}},
      });
      expect(SeekerTripWords.step(g.tripCard.nextStep), isNull);
    });

    test('OnTrip without today falls back to in progress', () {
      final j = _sample('seeker_feed_on_trip');
      final f = SeekerFeed.fromJson({...j, 'tripCard': {...j['tripCard'] as Map<String, dynamic>, 'today': null}});
      expect(f.tripCard.state, SeekerTripState.inProgress);
    });

    test('o_sk_4_fullFlagMissing_usesCountVsLimit', () {
      final j = _sample('seeker_feed');
      expect(SeekerFeed.fromJson({...j, 'slots': {'count': 3, 'limit': 3}}).plansFull, isTrue);
      expect(SeekerFeed.fromJson({...j, 'slots': {'count': 2, 'limit': 3}}).plansFull, isFalse);
    });

    test('o_sk_4_slotsMissing_noLine', () {
      final j = _sample('seeker_feed');
      expect(SeekerFeed.fromJson({...j}..remove('slots')).slots, isNull);
      expect(SeekerFeed.fromJson({...j, 'slots': {'count': 3}}).slots, isNull);
    });
  });

  group('SeekerStatusRule', () {
    const confirmed = SeekerStatus(kind: SeekerStatusKind.confirmed, listingName: 'Deodar Heights', key: 'k1');
    const reply = SeekerStatus(kind: SeekerStatusKind.reply, count: 2, key: 'k2');

    test('SeekerStatusRule_replyOverConfirmed_sample: the server picks Reply and the line is the reply copy', () {
      final j = _sample('seeker_feed');
      final f = SeekerFeed.fromJson({...j, 'status': {'kind': 'Reply', 'count': 2, 'listingName': '', 'tripId': 'trip-1', 'key': 'Reply:2:e:1'}});
      expect(SeekerStatusRule.line(f.status), '2 stays replied. Pick one.');
    });

    test('o_sk_2_statusHiddenAfterOpened_sameKey / o_sk_2_statusShownAgain_newKey', () {
      expect(SeekerStatusRule.visible(confirmed, null), isTrue);
      expect(SeekerStatusRule.visible(confirmed, 'k1'), isFalse);
      expect(SeekerStatusRule.visible(reply, 'k1'), isTrue);
      expect(SeekerStatusRule.visible(null, null), isFalse);
    });

    test('lines', () {
      expect(SeekerStatusRule.line(confirmed), 'Deodar Heights confirmed your stay');
      expect(SeekerStatusRule.line(const SeekerStatus(kind: SeekerStatusKind.reply, count: 1, key: 'x')), '1 stay replied. Pick one.');
    });
  });

  group('SeekerTripWords', () {
    test('dates: same month and across months', () {
      expect(SeekerTripWords.dates(DateTime(2026, 11, 26), DateTime(2026, 11, 29)), '26 to 29 Nov');
      expect(SeekerTripWords.dates(DateTime(2026, 11, 29), DateTime(2026, 12, 2)), '29 Nov to 2 Dec');
      expect(SeekerTripWords.dates(null, DateTime(2026, 12, 2)), isNull);
    });

    test('o_sk_2_headerSubtitleFollowsTrip and o_sk_3_subtitleDayNInCity', () {
      expect(SeekerTripWords.headerSubtitle(null), 'Where to next?');
      expect(SeekerTripWords.headerSubtitle(SeekerFeed.fromJson(_sample('seeker_feed'))), 'Nainital trip, 26 to 29 Nov');
      expect(SeekerTripWords.headerSubtitle(SeekerFeed.fromJson(_sample('seeker_feed_on_trip'))), 'Day 2 in Nainital');
    });

    test('o_sk_2 variant f: trip without dates shows the title only', () {
      final j = _sample('seeker_feed');
      final f = SeekerFeed.fromJson({...j, 'tripCard': {...j['tripCard'] as Map<String, dynamic>, 'startDate': null, 'endDate': null}});
      expect(SeekerTripWords.headerSubtitle(f), 'Nainital trip');
      expect(SeekerTripWords.eyebrow(f.tripCard), 'Nainital trip');
    });

    test('o_sk_3_cityNameMissing_fallsBackToTripDestination', () {
      final j = _sample('seeker_feed_on_trip');
      final card = j['tripCard'] as Map<String, dynamic>;
      final f = SeekerFeed.fromJson({...j, 'tripCard': {...card, 'today': {...card['today'] as Map<String, dynamic>, 'cityName': null}}});
      expect(SeekerTripWords.todayCity(f.tripCard), 'Nainital');
    });

    test('next step words', () {
      expect(SeekerTripWords.step(const SeekerNextStep(key: 'taxi', kind: SeekerStepKind.taxi)), 'book a taxi');
      expect(SeekerTripWords.step(const SeekerNextStep(key: 'stay:1', kind: SeekerStepKind.stay, cityName: 'Nainital')), 'find a stay in Nainital');
      expect(SeekerTripWords.step(const SeekerNextStep(key: '', kind: SeekerStepKind.taxi)), isNull);
    });
  });
}
