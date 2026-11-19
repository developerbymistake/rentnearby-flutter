import 'dart:convert';
import 'dart:typed_data';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _blocked(List<String> codes) => {
      'status': '409',
      'error': {'type': 'AccountHasActiveItems', 'message': 'blocked'},
      'data': {
        'reasons': [for (final c in codes) {'code': c, 'message': 'server $c'}],
      },
    };

void main() {
  late AuthController auth;

  setUp(() async {
    Get.testMode = true;
    ApiService.init();
    auth = AuthController();
  });

  tearDown(Get.reset);

  void respond(int status, Map<String, dynamic> body) => ApiService.dio.httpClientAdapter = _Adapter(status, body);

  test('409 AccountHasActiveItems returns every mapped reason and shows no toast', () async {
    respond(409, _blocked(['ActiveTaxiBooking', 'SelectedTaxiOffer', 'LiveListing']));
    final lines = await auth.deleteAccount();
    expect(lines, [
      'You have an active taxi booking. You can delete your account after it ends.',
      'A traveller has chosen you. Confirm or decline the trip first.',
      'Take your listing offline first.',
    ]);
    expect(auth.isLoading.value, false);
  });

  for (final c in const ['ActiveTaxiBooking', 'ActiveStayBooking', 'SelectedTaxiOffer', 'OpenTaxiRequest', 'OpenStayEnquiry', 'LiveListing']) {
    test('delete flow returns one line for $c', () async {
      respond(409, _blocked([c]));
      final lines = await auth.deleteAccount();
      expect(lines, hasLength(1));
      expect(lines!.single, isNot('server $c'));
    });
  }

  test('other errors return null and keep the old toast path', () async {
    respond(500, {'status': '500', 'error': {'type': 'Server', 'message': 'x'}});
    expect(await auth.deleteAccount(), isNull);
    respond(409, {'status': '409', 'error': {'type': 'Other', 'message': 'x'}});
    expect(await auth.deleteAccount(), isNull);
  });

  testWidgets('blocked dialog shows every reason in full, no ellipsis', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const reasons = [
      'You have an active taxi booking. You can delete your account after it ends.',
      'You have an active stay booking. You can delete your account after it ends.',
      'A traveller has chosen you. Confirm or decline the trip first.',
      'Take your listing offline first.',
    ];
    var closed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AccountDeleteBlockedDialog(reasons: reasons, onClose: () => closed++)),
    ));
    await tester.pumpAndSettle();
    for (final r in reasons) {
      final f = find.text(r, skipOffstage: false);
      expect(f, findsOneWidget);
      expect((tester.widget<Text>(f)).maxLines, isNull);
      expect((tester.widget<Text>(f)).overflow, isNot(TextOverflow.ellipsis));
    }
    await tester.tap(find.text('OK'));
    expect(closed, 1);
  });
}
