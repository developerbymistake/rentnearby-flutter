import 'package:bakhli/features/trip/data/trip_enquiry_repository.dart';
import 'package:bakhli/features/trip/enquiries/my_enquiries_controller.dart';
import 'package:bakhli/features/trip/enquiries/my_enquiry_count_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

Map<String, dynamic> _row(String id, String status, {String? checkOut}) => {
      'id': id,
      'tripId': 't1',
      'kind': 'Stay',
      'listingId': 'l-$id',
      'listingName': 'Stay $id',
      'status': status,
      'displayStatus': 'asked',
      'checkOut': ?checkOut,
    };

class _Repo extends TripEnquiryRepository {
  final calls = <String>[];
  final pages = <String, MyEnquiryPage>{};

  @override
  Future<MyEnquiryPage> mine({required String bucket, String? cursor, bool counts = true, int pageSize = 20}) async {
    calls.add('$bucket|${cursor ?? '-'}|$counts');
    return pages[cursor == null ? bucket : '$bucket+'] ?? const MyEnquiryPage(items: [], hasMore: false);
  }

  @override
  Future<TripEnquiryModel> get(String enquiryId) async => TripEnquiryModel.fromJson(_row(enquiryId, 'Offered'));
}

class _Count extends MyEnquiryCountController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test('bucket of mirrors the server by raw status', () {
    final now = DateTime.utc(2026, 11, 25, 6);
    TripEnquiryModel e(String s, {String? out}) => TripEnquiryModel.fromJson(_row('x', s, checkOut: out));
    expect(MyEnquiryBucket.of(e('Asked'), now: now), MyEnquiryBucket.waiting);
    expect(MyEnquiryBucket.of(e('Countered'), now: now), MyEnquiryBucket.waiting);
    expect(MyEnquiryBucket.of(e('Offered'), now: now), MyEnquiryBucket.offers);
    expect(MyEnquiryBucket.of(e('ConfirmedByBoth', out: '2026-11-25'), now: now), MyEnquiryBucket.booked);
    expect(MyEnquiryBucket.of(e('ConfirmedByBoth'), now: now), MyEnquiryBucket.booked);
    expect(MyEnquiryBucket.of(e('ConfirmedByBoth', out: '2026-11-24'), now: now), MyEnquiryBucket.past);
    expect(MyEnquiryBucket.of(e('Expired'), now: now), MyEnquiryBucket.past);
    expect(MyEnquiryBucket.parse('Offers'), MyEnquiryBucket.offers);
    expect(MyEnquiryBucket.parse('nope'), isNull);
  });

  test('first page applies counts to the header badge; load more sends the cursor without counts', () async {
    final count = Get.put<MyEnquiryCountController>(_Count());
    final repo = _Repo()
      ..pages['offers'] = MyEnquiryPage.fromJson({
        'items': [_row('a', 'Offered')],
        'hasMore': true,
        'nextCursor': 'c1',
        'counts': {'waiting': 2, 'offers': 1, 'booked': 3, 'past': 4},
      })
      ..pages['offers+'] = MyEnquiryPage.fromJson({
        'items': [_row('a', 'Offered'), _row('b', 'Offered')],
        'hasMore': false,
        'nextCursor': null,
        'counts': null,
      });
    final c = MyEnquiriesController(repo: repo);
    await c.selectBucket(MyEnquiryBucket.offers);
    expect(c.countOf(MyEnquiryBucket.booked), 3);
    expect(count.offers.value, 1);
    await c.loadMore();
    expect(repo.calls.last, 'offers|c1|false');
    expect([for (final e in c.items) e.id], ['a', 'b']);
    expect(c.hasMore.value, isFalse);
    expect(c.countOf(MyEnquiryBucket.waiting), 2);
  });

  test('bucketFor reads the row and a changed row leaves its old box', () async {
    final repo = _Repo()
      ..pages['waiting'] = MyEnquiryPage.fromJson({
        'items': [_row('a', 'Asked')],
        'hasMore': false,
      });
    final c = MyEnquiriesController(repo: repo);
    await c.selectBucket(MyEnquiryBucket.waiting);
    expect(await c.bucketFor('a'), MyEnquiryBucket.waiting);
    expect(await c.bucketFor('zz'), MyEnquiryBucket.offers);
    c.onRowChanged(TripEnquiryModel.fromJson(_row('a', 'Withdrawn')));
    expect(c.items.where((e) => e.id == 'a'), isEmpty);
  });
}
