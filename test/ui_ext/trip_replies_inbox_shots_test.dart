import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiries_controller.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiries_screen.dart';
import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../journeys/fake_api.dart';
import '../support/real_phone.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

bool _staysOn = true;

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool get staysEnabled {
    canListStays.value;
    return _staysOn;
  }
}

Map<String, List<TripEnquiryModel>> _data = {};
bool _loading = false;
bool _failed = false;
bool _moreFailed = false;

class _Inbox extends StayEnquiriesController {
  @override
  Future<void> load() async {
    items.assignAll(_data[bucket.value] ?? const []);
    loading.value = _loading;
    failed.value = _failed;
    loadMoreFailed.value = _moreFailed;
    counts.value = TripOwnerCounts(newCount: (_data['new'] ?? const []).length, offered: 1, confirmed: 2, closed: 1);
  }

  @override
  Future<void> refreshList() async {}
  @override
  Future<void> loadMore() async {}
  @override
  Future<void> loadBadge() async {}
  @override
  Future<String?> bucketFor(String enquiryId) async => null;
  @override
  Future<StayOwnerModel?> ensureStay() async => stay.value;
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, Object?> _offer(int perNight, int nights, {String kind = 'Offer', String id = 'of'}) => {
      'id': id,
      'kind': kind,
      'nights': nights,
      'lines': [
        {'roomName': 'Deluxe room', 'units': 1, 'guests': 2, 'pricePerNight': perNight},
      ],
      'total': perNight * nights,
      'validUntil': _iso(DateTime.now().add(const Duration(hours: 23))),
      'status': 'Pending',
    };

TripEnquiryModel _e(String id, String guest, String display,
    {String status = 'Asked', bool urgent = false, int? agreed, Map<String, Object?>? openOffer, Map<String, Object?>? counter, Map<String, Object?>? change, Map<String, Object?>? advance, List<String> spots = const []}) {
  final j = enquiryJson(id: id, kind: 'Stay', status: status, start: journeyStart(), nights: 2, displayStatus: display, agreedTotal: agreed, contextSpots: spots);
  return TripEnquiryModel.fromJson({
    ...j,
    'listingName': 'Deodar Cottage',
    'isUrgent': urgent,
    'conversationId': 'c$id',
    'createdAt': _iso(DateTime.now().subtract(const Duration(hours: 2))),
    'expiresAt': _iso(DateTime.now().add(const Duration(hours: 22))),
    'traveller': {'id': 't$id', 'name': guest, 'phone': '9876543211'},
    'context': {...(j['context'] as Map<String, Object?>), 'adults': 2, 'rooms': 1},
    'openOffer': ?openOffer,
    'pendingCounter': ?counter,
    'pendingChange': ?change,
    'advance': ?advance,
  });
}

final _configs = <(String, double, double)>[('', 360, 1.0), ('_13', 360, 1.3), ('_300', 300, 1.0)];

void main() {
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
  });
  setUp(() {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\trip-replies';
    Get.testMode = true;
    installFakeApi([]);
    _staysOn = true;
    _loading = false;
    _failed = false;
    _moreFailed = false;
    Get.put<TabConfigController>(_Tabs());
    Get.put<AuthController>(_Auth());
    final inbox = Get.put<StayEnquiriesController>(_Inbox());
    inbox.stay.value = StayOwnerModel.fromJson({'id': 's1', 'status': 'Approved', 'name': 'Deodar Cottage'});
  });
  tearDown(Get.reset);

  final scenes = <String, (String, Map<String, List<TripEnquiryModel>>)>{
    'hi_new': (
      'new',
      {
        'new': [
          _e('a', 'Rahul Sharma', 'asked', urgent: true, spots: ['Naini Lake', 'Mall Road']),
          _e('b', 'Priya Verma', 'asked', counter: {..._offer(2200, 2, kind: 'Counter', id: 'k1'), 'pricePerNight': 2200}),
        ],
      }
    ),
    'hi_offered': (
      'offered',
      {
        'offered': [_e('c', 'Amit Joshi', 'offered', status: 'Offered', openOffer: _offer(3600, 2))],
      }
    ),
    'hi_conf': (
      'confirmed',
      {
        'confirmed': [
          _e('d', 'Rahul Sharma', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 7200, advance: {
            'status': 'ProofSent',
            'amount': 2000,
            'holdUntil': _iso(DateTime.now().add(const Duration(hours: 4))),
          }),
          _e('e', 'Neha Rawat', 'confirmedByBoth', status: 'ConfirmedByBoth', agreed: 5200),
        ],
      }
    ),
    'hi_closed': (
      'closed',
      {
        'closed': [
          _e('f', 'Rahul Sharma', 'holdExpired', status: 'ConfirmedByBoth', agreed: 7200, advance: {
            'status': 'HoldExpired',
            'amount': 2000,
            'holdUntil': _iso(DateTime.now().subtract(const Duration(hours: 1))),
          }),
          _e('g', 'Kavita Bisht', 'declined', status: 'Declined'),
        ],
      }
    ),
    'hi_empty': ('new', {}),
    'hi_empty2': ('confirmed', {}),
    'hi_empty3': ('offered', {}),
    'hi_empty4': ('closed', {}),
  };

  Future<void> run(WidgetTester t, String name, String bucket, Map<String, List<TripEnquiryModel>> data, {double w = 360, double s = 1.0}) async {
    _data = data;
    debugDisableShadows = false;
    await pumpPhone(
      t,
      Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const StayEnquiriesScreen())),
          child: const Text('go'),
        ),
      ),
      size: Size(w, 800),
      devicePixelRatio: 1.5,
      textScale: s,
    );
    await t.tap(find.text('go'));
    await t.pump();
    await settlePhone(t);
    if (bucket != 'new') {
      await Get.find<StayEnquiriesController>().selectBucket(bucket);
      await settlePhone(t);
    }
    await shot(t, name);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
    debugDisableShadows = true;
  }

  for (final e in scenes.entries) {
    final cfgs = e.key.startsWith('hi_empty') ? _configs.take(1) : _configs;
    for (final (tag, w, s) in cfgs) {
      testWidgets('${e.key}$tag', (t) async {
        if (e.key == 'hi_empty') _staysOn = false;
        await run(t, '${e.key}$tag', e.value.$1, e.value.$2, w: w, s: s);
      });
    }
  }

  testWidgets('hi_loading', (t) async {
    _loading = true;
    await run(t, 'hi_loading', 'new', {});
  });

  testWidgets('hi_error', (t) async {
    _failed = true;
    await run(t, 'hi_error', 'new', {});
  });

  testWidgets('hi_more_failed', (t) async {
    _moreFailed = true;
    await run(t, 'hi_more_failed', 'offered', {
      'offered': [_e('c', 'Amit Joshi', 'offered', status: 'Offered', openOffer: _offer(3600, 2))],
    });
  });
}
