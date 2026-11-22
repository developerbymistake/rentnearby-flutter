import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bakhli/config/app_tabs.dart';
import 'package:bakhli/config/user_roles.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/extra/buttons_kit.dart';
import 'package:bakhli/features/owner_core/data/owner_api.dart';
import 'package:bakhli/features/owner_core/session/owner_session_hooks.dart';
import 'package:bakhli/services/api_service.dart';
import 'package:bakhli/utils/account_delete_message.dart';
import 'package:bakhli/widgets/account_blockers_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import '../../../support/owner_sizes.dart';

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

List<AccountDeleteBlock> _blocks() {
  ApiService.init();
  ApiService.dio.httpClientAdapter = _Adapter(409, loadSample('account_blocked'));
  return const [];
}

List<AccountDeleteBlock> _parsed() {
  final raw = loadSample('account_blocked');
  final reasons = ((raw['data'] as Map)['reasons'] as List);
  return [for (final r in reasons) AccountDeleteBlock.fromJson(r)!];
}

Widget _host(List<AccountDeleteBlock> blocks) => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(onPressed: () => AccountBlockersSheet.show(context, blocks), child: const Text('delete')),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('delete'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initTestStorage('account_blockers_sheet_test'));
  late FakeAuth auth;

  setUp(() {
    Get.testMode = true;
    Get.put<TabConfigController>(FakeTabs());
    auth = FakeAuth();
    Get.put<AuthController>(auth);
    auth.signIn(role: UserRoleKeys.stayOwner, stayStatus: 'Approved');
  });
  tearDown(() {
    OwnerApi.debugReset();
    Get.reset();
  });

  test('blocks() reads the AU-1 shape and keeps server order', () async {
    _blocks();
    try {
      await ApiService.delete('/account');
      fail('expected a 409');
    } catch (e) {
      final b = AccountDeleteMessage.blocks(e)!;
      expect(b.map((x) => x.code), ['ActiveStayBooking', 'OpenStayEnquiry', 'LiveListing', 'SharedTripOpenBalance']);
      expect(b.first.args['enquiryId'], 'q1');
      expect(b.first.side, 'Host');
      expect(b[3].title, 'Nainital trip');
    }
  });

  test('old server shape (code and message only) still gives rows with no button', () {
    final b = AccountDeleteBlock.fromJson(const {'code': 'ActiveStayBooking', 'message': 'old'})!;
    expect(b.action, isNull);
    expect(AccountBlockerActions.buttonOf(b), isNull);
  });

  test('button words and row titles follow the frames', () {
    final b = _parsed();
    expect(b.map(AccountBlockerActions.buttonOf), ['Open enquiry', 'Open enquiry', 'Turn off', 'Settle up']);
    expect(b.map(AccountBlockerActions.titleOf).take(3), ['Confirmed booking', 'New enquiry', 'Accepting guests is on']);
    const taxi = AccountDeleteBlock(code: 'ActiveTaxiBooking', message: 'm', action: 'OpenTaxiStatus', side: 'Traveller');
    expect(AccountBlockerActions.buttonOf(taxi), 'Open booking');
    const req = AccountDeleteBlock(code: 'OpenTaxiRequest', message: 'm', action: 'OpenTaxiStatus', side: 'Traveller');
    expect(AccountBlockerActions.buttonOf(req), 'Open request');
    const offer = AccountDeleteBlock(code: 'SelectedTaxiOffer', message: 'm', action: 'OpenTaxiOffer', side: 'Driver');
    expect(AccountBlockerActions.titleOf(offer), 'Traveller chose you');
    expect(AccountBlockerActions.subOf(offer), 'Confirm or decline the trip first.');
    const live = AccountDeleteBlock(code: 'LiveListing', message: 'm', action: 'GoOffline', args: {'listingKind': 'Taxi'});
    expect(AccountBlockerActions.titleOf(live), 'Available now is on');
    const unknown = AccountDeleteBlock(code: 'X', message: 'Server words', action: 'Teleport');
    expect(AccountBlockerActions.buttonOf(unknown), isNull);
    expect(AccountBlockerActions.titleOf(unknown), 'Server words');
  });

  testWidgets('Open enquiry closes the sheet and switches to the Enquiries tab with the enquiry', (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: _host(_parsed())));
    await _open(tester);
    expect(find.text('Cannot delete yet'), findsOneWidget);
    await tester.tap(find.text('Open enquiry').first);
    await tester.pumpAndSettle();
    expect(find.text('Cannot delete yet'), findsNothing);
    expect(auth.tabIndex.value, AppTabs.centre);
    expect(auth.tabIntent.value?.args['enquiryId'], 'q1');
  });

  testWidgets('Turn off calls the switch, removes the row and refreshes Home', (tester) async {
    final t = FakeTransport((m, p, b) async => {'data': {}});
    OwnerApi.transport = t;
    var refreshed = 0;
    OwnerSessionHooks.refreshHome = () async => refreshed++;
    await tester.pumpWidget(GetMaterialApp(home: _host(_parsed())));
    await _open(tester);
    await tester.ensureVisible(find.text('Turn off'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn off'));
    await tester.pumpAndSettle();
    expect(t.calls, ['PUT /stays/me/accepting']);
    expect(find.text('Accepting guests is on'), findsNothing);
    expect(find.text('Cannot delete yet'), findsOneWidget);
    expect(refreshed, 1);
  });

  testWidgets('FX-27 the busy spinner follows its row when another row is removed', (tester) async {
    final hang = Completer<Map<String, dynamic>>();
    OwnerApi.transport = FakeTransport((m, p, b) => p == '/taxis/me/availability' ? hang.future : Future.value({'data': {}}));
    OwnerSessionHooks.refreshHome = () async {};
    const rows = [
      AccountDeleteBlock(code: 'LiveListing', message: 'm', action: 'GoOffline', targetId: 's1', args: {'listingKind': 'Stay'}),
      AccountDeleteBlock(code: 'LiveListing', message: 'm', action: 'GoOffline', targetId: 't1', args: {'listingKind': 'Taxi'}),
    ];
    await tester.pumpWidget(GetMaterialApp(home: _host(rows)));
    await _open(tester);
    await tester.tap(find.text('Turn off').last);
    await tester.pump();
    bool loading(PrimaryButton b) => b.loading;
    expect(find.byWidgetPredicate((w) => w is PrimaryButton && loading(w)), findsOneWidget);
    await tester.tap(find.text('Turn off').first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Accepting guests is on'), findsNothing);
    expect(find.text('Available now is on'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is PrimaryButton && loading(w)), findsOneWidget, reason: 'the taxi row is still busy');
    hang.complete({'data': {}});
    await tester.pumpAndSettle();
  });

  testWidgets('Close only closes', (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: _host(_parsed())));
    await _open(tester);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Cannot delete yet'), findsNothing);
    expect(auth.tabIndex.value, AppTabs.home);
  });

  for (final count in [1, 4]) {
    testOwnerSizes('sheet with $count rows', () => _host(_parsed().take(count).toList()), arrange: _open, check: (tester, size, scale) async {
      expect(find.text('Cannot delete yet'), findsOneWidget);
    });
  }

  testWidgets('render o_st_63 C', (tester) async {
    final file = await renderOwnerFrame(tester, 'o_st_63', _host(_parsed().take(3).toList()), part: 'C', arrange: _open);
    expect(file.existsSync(), isTrue);
  });
}
