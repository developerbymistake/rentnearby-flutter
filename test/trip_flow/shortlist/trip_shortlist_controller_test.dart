import 'package:bakhli/features/taxi/ways/models/ask_models.dart';
import 'package:bakhli/features/trip/controllers/trip_enquiry_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/data/trip_shortlist_repository.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/trip_strings_shortlist.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;

class _FakeRepo implements TripShortlistRepository {
  _FakeRepo({this.server = const [], this.failWith});

  List<ShortlistItem> server;
  Object? failWith;
  final calls = <String>[];
  final stored = <ShortlistItem>[];

  @override
  Future<TripShortlist> list(String tripId) async {
    calls.add('list');
    return TripShortlist(items: server);
  }

  @override
  Future<List<ShortlistItem>> add(String tripId, String stepKey, String listingId, ShortlistItem item) async {
    calls.add('add:$stepKey:$listingId');
    if (failWith != null) throw failWith!;
    stored.removeWhere((i) => i.stepKey == stepKey && i.listingId == listingId);
    stored.add(ShortlistItem(stepKey: stepKey, kind: item.kind, listingId: listingId, name: item.name));
    return [for (final i in stored) if (i.stepKey == stepKey) i];
  }

  @override
  Future<void> remove(String tripId, String stepKey, String listingId) async {
    calls.add('remove:$listingId');
    if (failWith != null) throw failWith!;
    stored.removeWhere((i) => i.listingId == listingId);
  }

  @override
  Future<void> close(String tripId, String stepKey, {required String reason}) async => calls.add('close:$reason');

  @override
  Future<MarkBookedResult> markBooked(String tripId, String stepKey, {String? listingId}) async {
    calls.add('booked');
    return const MarkBookedResult(closedEnquiries: 1, closedShortlist: 2);
  }
}

class _FakeEnquiry extends TripEnquiryController {
  final ids = <String>[];
  final stepKeys = <String?>[];
  TripEnquiryBatch? reply;

  @override
  Future<TripEnquiryBatch?> sendEnquiry({
    required int day,
    required List<String> stayIds,
    required int nights,
    String? clientRequestId,
    String? stepKey,
  }) async {
    ids.add(clientRequestId ?? '');
    stepKeys.add(stepKey);
    return reply;
  }
}

DioException _http(int status, String type) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: {
          'error': {'type': type, 'message': 'm'},
        },
      ),
      type: DioExceptionType.badResponse,
    );

void main() {
  late List<String> toasts;
  late int idSeq;

  TripShortlistController make(_FakeRepo repo, {bool offline = false}) => TripShortlistController(
        repo: repo,
        tripId: () async => 't1',
        offline: () => offline,
        warn: toasts.add,
        newId: () => 'req-${idSeq++}',
      );

  setUp(() {
    Get.testMode = true;
    toasts = [];
    idSeq = 1;
  });

  tearDown(Get.reset);

  Future<bool> add(TripShortlistController c, String id, {String step = 'stay:1'}) =>
      c.toggle(step: step, kind: 'Stay', listingId: id, name: 'Name $id');

  test('adds up to three and shows the full toast on the fourth without a server call', () async {
    final repo = _FakeRepo();
    final c = make(repo);
    await add(c, 'a');
    await add(c, 'b');
    await add(c, 'c');
    await add(c, 'd');
    expect(c.countOf('stay:1'), 3);
    expect(toasts, [TripStringsShortlist.full]);
    expect(repo.calls.where((x) => x.startsWith('add:stay:1:d')), isEmpty);
  });

  test('cap is per step', () async {
    final c = make(_FakeRepo());
    for (final id in ['a', 'b', 'c']) {
      await add(c, id);
    }
    await add(c, 'z', step: 'taxi');
    expect(c.countOf('taxi'), 1);
    expect(toasts, isEmpty);
  });

  test('server 409 ShortlistFull rolls back the optimistic add and shows the full toast', () async {
    final repo = _FakeRepo(failWith: _http(409, TripShortlistErrorTypes.full));
    final c = make(repo);
    final ok = await add(c, 'a');
    expect(ok, isFalse);
    expect(c.has('stay:1', 'a'), isFalse);
    expect(toasts, contains(TripStringsShortlist.full));
  });

  test('toggle off removes and calls remove; failure restores the row', () async {
    final repo = _FakeRepo();
    final c = make(repo);
    await add(c, 'a');
    expect(c.has('stay:1', 'a'), isTrue);
    repo.failWith = _http(500, 'X');
    await add(c, 'a');
    expect(c.has('stay:1', 'a'), isTrue);
    repo.failWith = null;
    await add(c, 'a');
    expect(c.has('stay:1', 'a'), isFalse);
    expect(repo.calls, contains('remove:a'));
  });

  test('offline blocks the add with a toast and no call', () async {
    final repo = _FakeRepo();
    final c = make(repo, offline: true);
    expect(await add(c, 'a'), isFalse);
    expect(repo.calls, isEmpty);
    expect(toasts, hasLength(1));
  });

  test('load keeps closed no-reply rows out of the active count and exposes their ids', () async {
    final repo = _FakeRepo(server: const [
      ShortlistItem(stepKey: 'stay:1', kind: 'Stay', listingId: 'n1', name: 'Old', state: 'Closed', closedReason: 'NoReply'),
      ShortlistItem(stepKey: 'stay:1', kind: 'Stay', listingId: 'a1', name: 'Live'),
    ]);
    final c = make(repo);
    expect(await c.load(), isTrue);
    expect(c.countOf('stay:1'), 1);
    expect(c.noReplyIds('stay:1'), {'n1'});
  });

  test('requestIdFor is stable for the same ids in any order until completed', () {
    final c = make(_FakeRepo());
    final first = c.requestIdFor('stay:1', ['b', 'a']);
    expect(c.requestIdFor('stay:1', ['a', 'b']), first);
    c.completeRequest('stay:1', ['a', 'b']);
    expect(c.requestIdFor('stay:1', ['a', 'b']), isNot(first));
  });

  test('retry after a failed send reuses the same clientRequestId, then a new one after success', () async {
    final fake = _FakeEnquiry();
    Get.put<TripEnquiryController>(fake);
    final c = make(_FakeRepo());
    await add(c, 'a');
    await add(c, 'b');
    fake.reply = null;
    expect(await c.sendStays(step: 'stay:1', day: 1, nights: 2), isNull);
    expect(await c.sendStays(step: 'stay:1', day: 1, nights: 2), isNull);
    expect(fake.ids[0], fake.ids[1]);
    expect(fake.stepKeys, ['stay:1', 'stay:1']);
    fake.reply = const TripEnquiryBatch(items: [], skipped: [], veryShortNotice: false, results: [
      TripSendResult(listingId: 'a', status: 'Sent'),
      TripSendResult(listingId: 'b', status: 'Failed'),
    ]);
    await c.sendStays(step: 'stay:1', day: 1, nights: 2);
    expect(fake.ids[2], fake.ids[0]);
    await c.sendStays(step: 'stay:1', day: 1, nights: 2);
    expect(fake.ids[3], isNot(fake.ids[0]));
  });

  test('failed recipients stay shortlisted, delivered ones leave the list', () {
    final c = make(_FakeRepo());
    c.items.addAll(const [
      ShortlistItem(stepKey: 'stay:1', kind: 'Stay', listingId: 'a', name: 'A'),
      ShortlistItem(stepKey: 'stay:1', kind: 'Stay', listingId: 'b', name: 'B'),
      ShortlistItem(stepKey: 'stay:1', kind: 'Stay', listingId: 'c', name: 'C'),
    ]);
    c.applyResults('stay:1', const [
      TripSendResult(listingId: 'a', status: 'Sent'),
      TripSendResult(listingId: 'b', status: 'Failed'),
      TripSendResult(listingId: 'c', status: 'AlreadyOpen'),
    ]);
    expect(c.activeOf('stay:1').map((i) => i.listingId), ['b']);
  });

  test('markBooked clears the step and returns the counts', () async {
    final c = make(_FakeRepo());
    await add(c, 'a');
    final res = await c.markBooked('stay:1');
    expect(res?.closedEnquiries, 1);
    expect(c.countOf('stay:1'), 0);
  });

  group('carBatch', () {
    test('uses server results and adds NotAvailable for ids the server never mentioned', () {
      const res = AskResult(items: [], skipped: [], veryShortNotice: false, results: [
        TripSendResult(listingId: 'x', status: 'Sent'),
      ]);
      final batch = TripShortlistController.carBatch(res, ['x', 'y']);
      expect(batch.perRecipient.map((r) => '${r.listingId}:${r.status}'), ['x:Sent', 'y:NotAvailable']);
    });

    test('falls back to items and skipped when the server sends no results', () {
      const res = AskResult(
        items: [AskItem(legIndex: 1, taxiId: 'x', enquiryId: 'e1', status: 'Asked')],
        skipped: [AskSkipped(legIndex: 1, taxiId: 'y', reason: 'AlreadyOpen')],
        veryShortNotice: false,
      );
      final batch = TripShortlistController.carBatch(res, ['x', 'y']);
      expect(batch.perRecipient.map((r) => r.status), ['Sent', 'AlreadyOpen']);
    });
  });

  group('ShortlistOrder', () {
    test('no-reply hosts go last, others keep their order', () {
      final out = ShortlistOrder.noReplyLast(['a', 'b', 'c', 'd'], (s) => s, {'a', 'c'});
      expect(out, ['b', 'd', 'a', 'c']);
    });

    test('empty no-reply set returns the same list', () {
      final rows = ['a', 'b'];
      expect(identical(ShortlistOrder.noReplyLast(rows, (s) => s, {}), rows), isTrue);
    });
  });

  test('status labels cover every contract status', () {
    expect(TripStringsShortlist.statusLabel('Sent'), 'Sent');
    expect(TripStringsShortlist.statusLabel('AlreadyOpen'), 'Already sent earlier');
    expect(TripStringsShortlist.statusLabel('Replayed'), 'Already sent');
    expect(TripStringsShortlist.statusLabel('NotAvailable'), 'Not available');
    expect(TripStringsShortlist.statusLabel('Blocked'), "Can't be reached");
    expect(TripStringsShortlist.statusLabel('LimitReached'), 'Limit reached');
    expect(TripStringsShortlist.statusLabel('Failed'), 'Try again');
  });
}
