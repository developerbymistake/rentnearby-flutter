import 'package:bakhli/features/trip/data/trip_enquiry_repository.dart';
import 'package:bakhli/features/trip/enquiries/similar_stays.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/trip_strings_enquiry_simple.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Repo extends TripEnquiryRepository {
  _Repo(this.reply);

  SimilarStays reply;
  final calls = <String>[];

  @override
  Future<SimilarStays> similar({required String tripId, required String stepKey, String? likeListingId, int limit = 3}) async {
    calls.add('$tripId|$stepKey|$likeListingId');
    return reply;
  }
}

Map<String, dynamic> _stay(String id, {int? dates, int? quote, int? min, bool fast = false}) => {
      'id': id,
      'name': 'Stay $id',
      'stayTypeName': 'Homestay',
      'cityName': 'Nainital',
      'distanceKm': 1.2,
      'datesPerNight': ?dates,
      'quotePerNight': ?quote,
      'minPricePerNight': ?min,
      if (fast) 'repliesFast': true,
    };

final _ref = TripEnquiryModel.fromJson({
  'id': 'e1',
  'tripId': 't1',
  'kind': 'Stay',
  'listingId': 'like',
  'listingName': 'Old',
  'day': 2,
  'cityLeg': 1,
  'checkIn': '2026-12-02',
  'checkOut': '2026-12-04',
  'status': 'Closed',
  'displayStatus': 'closed',
});

Future<void> _pump(WidgetTester t, _Repo repo) async {
  await t.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: SimilarStaysBody(reference: _ref, repo: repo))),
  ));
  await t.pump();
  await t.pump();
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test('price falls back dates -> quote -> min and fast host flag is read', () {
    final s = SimilarStays.fromJson({
      'free': 2,
      'items': [_stay('a', dates: 2800, quote: 3000, min: 2000, fast: true), _stay('b', quote: 3000, min: 2000), _stay('c', min: 2000), {'name': 'no id'}],
    });
    expect([for (final x in s.items) x.pricePerNight], [2800, 3000, 2000]);
    expect(s.items.first.repliesFast, isTrue);
    expect(s.items[1].repliesFast, isFalse);
  });

  test('pre-ticks only as many as free places', () {
    final items = {'items': [_stay('a'), _stay('b'), _stay('c')]};
    expect(SimilarStays.fromJson({...items, 'free': 2}).preTicked(), {'a', 'b'});
    expect(SimilarStays.fromJson({...items, 'free': 0}).preTicked(), isEmpty);
    expect(SimilarStays.fromJson({...items, 'free': 5}).preTicked(), {'a', 'b', 'c'});
  });

  testWidgets('shows Ask these N for the pre-ticked rows and sends nothing on its own', (t) async {
    final repo = _Repo(SimilarStays.fromJson({'free': 2, 'items': [_stay('a', fast: true), _stay('b'), _stay('c')]}));
    await _pump(t, repo);
    expect(repo.calls, ['t1|stay:1|like']);
    expect(find.text(TripStringsEnq.askThese(2)), findsOneWidget);
    expect(find.textContaining(TripStringsEnq.repliesInDay), findsOneWidget);
    await t.tap(find.text('Stay c'));
    await t.pump();
    expect(find.text(TripStringsEnq.askThese(2)), findsOneWidget, reason: 'never more ticks than free places');
    await t.tap(find.text('Stay a'));
    await t.pump();
    expect(find.text(TripStringsEnq.askThese(1)), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('empty list shows the plain line and Try again reloads', (t) async {
    final repo = _Repo(const SimilarStays(free: 2));
    await _pump(t, repo);
    expect(find.text(TripStringsEnq.noMoreStays), findsOneWidget);
    await t.tap(find.text(TripStringsEnq.tryAgain));
    await t.pump();
    await t.pump();
    expect(repo.calls, hasLength(2));
  });
}
