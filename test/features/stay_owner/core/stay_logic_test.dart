import 'package:bakhli/features/owner_core/home/owner_home_models.dart';
import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/stay_owner/home/stay_attention_copy.dart';
import 'package:bakhli/features/stay_owner/home/stay_home_compose.dart';
import 'package:bakhli/features/stay_owner/strings/stay_format.dart';
import 'package:bakhli/features/stay_owner/strings/stay_home_strings.dart';
import 'package:bakhli/features/stay_owner/strings/stay_setup_strings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import 'stay_fixtures.dart';

StayAttentionActions _noop() => StayAttentionActions(
      reply: () {},
      openEnquiry: (_) {},
      fixPayment: () {},
      openNotificationSettings: () {},
      choose: () {},
      viewReports: () {},
      viewEditRejected: () {},
      setPrice: ({dateFrom, dateTo, festivalId}) {},
      addShare: () {},
      share: () {},
    );

OwnerHomeDto _dto(Map<String, dynamic> j) => OwnerHomeDto.fromJson(j);

void main() {
  group('StayOwnerModel', () {
    test('parses every variant of the /stays/me sample without throwing', () {
      var n = 0;
      final sample = stayJson(
        hiddenRooms: 1,
        hiddenPhotos: 1,
        pendingEdit: {
          'fields': {'name': 'x'},
          'at': '2026-11-21T10:00:00Z',
        },
        lastEditResult: {'result': 'Rejected', 'reason': 'r', 'at': '2026-11-21T10:00:00Z', 'fieldsChanged': ['name']},
      );
      for (final v in jsonVariants(sample)) {
        StayOwnerModel.fromJson(v);
        n++;
      }
      expect(n, greaterThan(50));
    });

    test('old server without the new fields still parses to safe defaults', () {
      final m = StayOwnerModel.fromJson({
        'id': 's',
        'status': 'Approved',
        'rooms': [
          {'id': 'r', 'roomIndex': 1, 'roomName': 'Deluxe', 'pricePerNight': 3000, 'maxGuests': 3, 'meals': 'x'},
        ],
      });
      expect(m.hiddenRooms, isEmpty);
      expect(m.meters, isEmpty);
      expect(m.pendingEdit, isNull);
      expect(m.confirmedBookingCount, 0);
      expect(m.calendarRow, isNull);
    });

    test('percent: 100 after a submitted rejection, 90 for a never submitted draft', () {
      final rejected = StayOwnerModel.fromJson({'id': 's', 'status': 'Rejected', 'step1Done': true, 'roomsDone': true, 'rulesDone': true, 'submittedAt': '2026-11-18T10:00:00Z'});
      expect(rejected.setupPercent, 100);
      final draft = StayOwnerModel.fromJson({'id': 's', 'status': 'Draft', 'step1Done': true, 'roomsDone': true, 'rulesDone': true});
      expect(draft.setupPercent, 90);
      expect(StayOwnerModel.fromJson({'id': 's', 'status': 'Draft', 'step1Done': true}).setupPercent, 40);
      expect(StayOwnerModel.fromJson({'id': 's', 'status': 'Draft', 'step1Done': true, 'roomsDone': true}).setupPercent, 70);
    });

    test('reportCount wins over pendingReportCount; edit rules per status', () {
      expect(StayOwnerModel.fromJson({'id': 's', 'reportCount': 2, 'pendingReportCount': 5}).reportCount, 2);
      expect(StayOwnerModel.fromJson({'id': 's', 'pendingReportCount': 5}).reportCount, 5);
      final a = StayOwnerModel.fromJson({'id': 's', 'status': 'Approved'});
      expect(a.canEditLive, isTrue);
      expect(a.canEditRoomsAndRules, isTrue);
      expect(StayOwnerModel.fromJson({'id': 's', 'status': 'PendingReview'}).canEditRoomsAndRules, isFalse);
    });

    test('result strip needs a known result word', () {
      expect(StayEditResult.maybe({'result': 'Maybe'}), isNull);
      expect(StayEditResult.maybe({'result': 'Approved'})?.approved, isTrue);
    });
  });

  group('Home states', () {
    test('state rules', () {
      expect(StayHomeCompose.stateOf(_dto(homeJson()).listing), StayHomeState.live);
      expect(StayHomeCompose.stateOf(_dto(homeJson(switchOn: false)).listing), StayHomeState.paused);
      expect(StayHomeCompose.stateOf(_dto(homeJson(areaPaused: true)).listing), StayHomeState.areaPaused);
      expect(StayHomeCompose.stateOf(_dto(homeJson(status: 'PendingReview')).listing), StayHomeState.review);
      expect(StayHomeCompose.stateOf(_dto(homeJson(status: 'Rejected', everApproved: false)).listing), StayHomeState.rejected);
      expect(StayHomeCompose.stateOf(_dto(homeJson(status: 'Rejected', takenDown: true)).listing), StayHomeState.takenDown);
    });

    test('status lines from codes, with a safe fallback', () {
      String? line(Map<String, dynamic>? sl, {String? city = 'Mukteshwar'}) {
        final d = _dto(homeJson(statusLine: sl, city: city));
        return StayHomeCompose.line(StayHomeCompose.stateOf(d.listing), d.listing);
      }

      expect(
        line({
          'code': 'NewNeedReply',
          'args': {'count': 2},
        }),
        '2 enquiries need a reply.',
      );
      expect(
        line({
          'code': 'NewNeedReply',
          'args': {'count': 1},
        }),
        '1 enquiry needs a reply.',
      );
      expect(
        line({
          'code': 'CheckInsThisWeek',
          'args': {'count': 2},
        }),
        '2 check-ins this week.',
      );
      expect(
        line({
          'code': 'Featured',
          'args': {'city': 'Mukteshwar'},
        }),
        'First in trip plans for Mukteshwar.',
      );
      expect(line({'code': 'Featured', 'args': {}}, city: null), StayHomeStrings.lineLive);
      expect(line({'code': 'PlansStarted'}), 'Plans started today.');
      expect(line({'code': 'Weird'}), StayHomeStrings.lineLive);
      expect(line(null), 'Guests can find and ask you now.');
    });

    test('rejected and taken down use the server reason, generic when missing', () {
      expect(StayHomeStrings.rejectedLine('photos are not clear.'), 'Rejected: photos are not clear.');
      expect(StayHomeStrings.rejectedLine(null), 'Rejected');
      expect(StayHomeStrings.takenDownLine('guests reported a wrong location.'), 'Taken down by Bakhli: guests reported a wrong location.');
    });
  });

  group('Attention rows', () {
    final h = _noop();

    test('order follows priority; share above UPI as drawn; notifications at row 5', () {
      final d = _dto(
        homeJson(
          attention: [
            att('AddShareDetails', 11),
            att('ShareListing', 10),
            att('Reports', 7, {'count': 1, 'firstReason': 'x'}),
            att('EnquiriesWaiting', 1, {'count': 2}),
          ],
        ),
      );
      final rows = StayHomeCompose.attention(d, denied: true, hasShareDetails: false);
      expect(rows.map((r) => r.code).toList(), ['EnquiriesWaiting', 'NotificationsOff', 'Reports', 'ShareListing', 'AddShareDetails']);
    });

    test('notifications row only while denied', () {
      final d = _dto(homeJson());
      expect(StayHomeCompose.attention(d, denied: false, hasShareDetails: true), isEmpty);
      expect(StayHomeCompose.attention(d, denied: true, hasShareDetails: true).single.code, 'NotificationsOff');
    });

    test('under review: no UPI row, notifications only while denied', () {
      final d = _dto(homeJson(status: 'PendingReview', everApproved: false));
      expect(StayHomeCompose.attention(d, denied: true, hasShareDetails: false).map((r) => r.code), ['NotificationsOff']);
      expect(StayHomeCompose.attention(d, denied: false, hasShareDetails: true), isEmpty);
    });

    test('rejected keeps only the notifications row; taken down has none', () {
      expect(StayHomeCompose.attention(_dto(homeJson(status: 'Rejected', everApproved: false, attention: [att('ShareListing', 10)])), denied: true, hasShareDetails: false).map((r) => r.code), ['NotificationsOff']);
      expect(StayHomeCompose.attention(_dto(homeJson(status: 'Rejected', takenDown: true)), denied: true, hasShareDetails: false), isEmpty);
    });

    test('words of every code and an unknown code is skipped', () {
      String? title(String code, [Map<String, dynamic> args = const {}]) => StayAttentionCopy.of(OwnerAttention(code: code, args: args), h)?.title;
      expect(title('EnquiriesWaiting', {'count': 2}), '2 enquiries waiting');
      expect(title('EnquiriesWaiting', {'count': 1}), '1 enquiry waiting');
      expect(title('ChangeOrCounter', {'travellerName': 'Rohit', 'kind': 'Change'}), 'Rohit asked to change his booking.');
      expect(title('ChangeOrCounter', {'travellerName': 'Rohit', 'kind': 'Counter'}), 'Rohit sent a new price.');
      const accepted = {'travellerName': 'Rohit', 'checkIn': '2026-11-27', 'checkOut': '2026-11-29'};
      expect(title('OfferAccepted', accepted), 'Rohit accepted your offer');
      expect(StayAttentionCopy.of(const OwnerAttention(code: 'OfferAccepted', args: accepted), h)?.sub, 'Booking confirmed for 27 – 29 Nov');
      expect(title('PaymentIssue'), 'Payment issue');
      expect(title('PlanHidden', {'photos': 4, 'roomTypes': 2, 'reason': 'PlusEnded'}), 'Plus ended. 4 photos and 2 room types are hidden.');
      expect(title('PlanHidden', {'photos': 4, 'roomTypes': 2, 'reason': 'PlansStarted'}), 'Plans have started. 4 photos and 2 room types are hidden.');
      expect(title('PlanHidden', {'photos': 1}), 'Plus ended. 1 photo is hidden.');
      expect(title('Reports', {'count': 1}), '1 report on this stay');
      expect(title('EditRejected', {'reason': 'wrong', 'fields': ['name']}), 'Your name change was not approved: wrong');
      expect(title('EditRejected', {'reason': 'wrong', 'fields': ['location']}), 'Change not approved: wrong');
      expect(title('Festival', {'name': 'Diwali week', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12'}), 'Diwali week starts 6 Nov');
      expect(title('AddShareDetails'), 'Add UPI and WhatsApp');
      expect(title('ShareListing'), 'Share your stay');
      expect(title('SomethingNew'), isNull);
      expect(title('EnquiriesWaiting', {'count': 'x'}), isNull);
      expect(title('OfferAccepted', {}), isNull);
    });

    test('reply-by is a local clock time, am and pm lower case', () {
      expect(StayFormat.clock(DateTime(2026, 11, 21, 18, 40).toUtc()), '6:40 pm');
      expect(StayFormat.clock(DateTime(2026, 11, 21, 0, 5).toUtc()), '12:05 am');
      expect(StayFormat.clock(DateTime(2026, 11, 21, 12, 0).toUtc()), '12:00 pm');
    });

    test('date ranges', () {
      expect(StayFormat.range(DateTime(2026, 11, 22), DateTime(2026, 11, 23)), '22 – 23 Nov');
      expect(StayFormat.range(DateTime(2026, 11, 30), DateTime(2026, 12, 2)), '30 Nov – 2 Dec');
      expect(StayFormat.rangeTo(DateTime(2026, 11, 6), DateTime(2026, 11, 12)), '6 to 12 Nov');
    });
  });

  group('Setup strings', () {
    test('o_st_65_c_outsideDistrict uses its own server text, closed area keeps the frame text', () {
      expect(StaySetupStrings.notOpenBodyFor('OnboardingClosed', 'x'), 'We are not taking new stays in this area yet. We will tell you when it opens.');
      expect(StaySetupStrings.notOpenBodyFor(null, null), StaySetupStrings.notOpenBody);
      expect(StaySetupStrings.notOpenBodyFor('StayOutsideDistrict', 'Pin your stay inside the selected district'), 'Pin your stay inside the selected district');
      expect(StaySetupStrings.notOpenBodyFor('StayOutsideDistrict', '  '), 'Pin your stay inside the selected district.');
      expect(StaySetupStrings.notOpenBodyFor('StayOutsideDistrict', null), 'Pin your stay inside the selected district.');
    });
  });
}
