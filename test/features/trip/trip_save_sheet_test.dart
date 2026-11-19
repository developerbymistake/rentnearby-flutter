import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/screens/trip_dates_sheet.dart';
import 'package:bakhli/features/trip/trip_strings_name.dart';
import 'package:bakhli/features/trip/trip_strings_save_trip.dart';
import 'package:bakhli/features/trip/trip_strings_v2_find.dart';
import 'package:bakhli/services/storage_service.dart';
import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../journeys/fake_api.dart';
import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';
import 'support/engine_rig.dart';

const _nainital = TripCityModel(cityKey: 1, name: 'Nainital', stateName: 'Uttarakhand', latitude: 29.4, longitude: 79.4);
const _open = ValueKey('open-save-sheet');
const _field = ValueKey('save-trip-name');
const _cta = ValueKey('save-trip-cta');

TripSpotModel _spot(String id) => TripSpotModel.fromJson({
      'id': id,
      'name': id,
      'latitude': 29.4,
      'longitude': 79.4,
      'category': 'attraction',
      'visitMinutes': 60,
    });

FakeRoute _planRoute() => FakeRoute('POST', '/trips/plan', (o) {
      final body = o.data as Map;
      final ids = [for (final s in body['spots'] as List) (s as Map)['id'] as String];
      return {
        'days': [
          {'day': 1, 'spotIds': ids, 'visitMinutes': 120, 'totalMinutes': 150},
        ],
        'osrmAvailable': true,
        'dayLimitMinutes': 300,
      };
    });

Map<String, dynamic> _echo(RequestOptions o) {
  final body = o.data as Map;
  return engineTripJson(
    TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)),
    extra: {'title': body['name'], 'nameChosen': true},
  );
}

bool? _result;

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

Future<TripPlanController> _openSheet(WidgetTester t, {Size size = phoneSize, double keyboard = 0}) async {
  _result = null;
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  Get.put<TripPlanController>(c, permanent: true);
  await t.runAsync(() => c.startFromSelection(_nainital, [_spot('a'), _spot('b')]));
  await pumpPhone(
    t,
    Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: TextButton(
            key: _open,
            onPressed: () async => _result = await TripDatesSheet.saveTrip(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    size: size,
  );
  if (keyboard > 0) {
    t.view.viewInsets = FakeViewPadding(bottom: keyboard * t.view.devicePixelRatio);
    addTearDown(t.view.resetViewInsets);
  }
  await t.tap(find.byKey(_open));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  return c;
}

GradientPillButton _button(WidgetTester t) => t.widget<GradientPillButton>(find.byKey(_cta));

String _fieldText(WidgetTester t) =>
    t.widget<EditableText>(find.descendant(of: find.byKey(_field), matching: find.byType(EditableText))).controller.text;

Future<void> _type(WidgetTester t, String text) async {
  await t.enterText(find.descendant(of: find.byKey(_field), matching: find.byType(EditableText)), text);
  await t.pump();
}

Future<void> _tapCta(WidgetTester t) async {
  await t.tap(find.byKey(_cta));
  await t.pump();
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _drain(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(minutes: 2));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('save_sheet_gs').path);
    await GetStorage.init();
  });
  setUp(StorageService.clearTripNewDraft);
  tearDown(Get.reset);

  testWidgets('name_empty_button_disabled_no_prefill', (t) async {
    installFakeApi([_planRoute(), FakeRoute('POST', '/trips', _echo)]);
    await _openSheet(t);
    expect(find.text(TripStringsSaveTrip.title), findsOneWidget);
    expect(find.text(TripStringsSaveTrip.cta), findsOneWidget);
    expect(find.text(TripStringsV2Find.datesNote), findsOneWidget);
    expect(_fieldText(t), '');
    expect(find.text(TripStringsName.counter(0)), findsOneWidget);
    expect(_button(t).onTap, isNull);
    expect(find.text(TripStringsName.empty), findsNothing);
    await _drain(t);
  });

  testWidgets('no_show_drivers_text', (t) async {
    installFakeApi([_planRoute()]);
    await _openSheet(t);
    expect(find.text('Show drivers'), findsNothing);
    await _drain(t);
  });

  testWidgets('sixty_first_character_refused', (t) async {
    installFakeApi([_planRoute()]);
    await _openSheet(t);
    await _type(t, 'a' * 61);
    expect(_fieldText(t).length, 60);
    expect(find.text(TripStringsName.counter(60)), findsOneWidget);
    expect(_button(t).onTap, isNotNull);
    await _drain(t);
  });

  testWidgets('emoji_refused', (t) async {
    installFakeApi([_planRoute()]);
    await _openSheet(t);
    await _type(t, 'Hills \u{1F600}');
    expect(_fieldText(t).contains('\u{1F600}'), isFalse);
    await _drain(t);
  });

  testWidgets('link_shows_invalid_line', (t) async {
    installFakeApi([_planRoute()]);
    await _openSheet(t);
    await _type(t, 'www.trip.com');
    expect(find.text(TripStringsName.invalid), findsOneWidget);
    expect(_button(t).onTap, isNull);
    await _type(t, 'Lake Days');
    expect(find.text(TripStringsName.invalid), findsNothing);
    expect(_button(t).onTap, isNotNull);
    await _drain(t);
  });

  testWidgets('save_creates_once_with_name_and_travellers_date_optional', (t) async {
    final api = installFakeApi([_planRoute(), FakeRoute('POST', '/trips', _echo)]);
    final c = await _openSheet(t);
    await _type(t, '  Family   Hills ');
    await _tapCta(t);
    expect(api.calls('POST', '/trips'), hasLength(1));
    final body = Map<String, dynamic>.from(api.calls('POST', '/trips').single.data as Map);
    expect(body['name'], 'Family Hills');
    final s = TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)).settings;
    expect(s.startDate, isNull);
    expect(s.adults, 2);
    expect(s.kids, 0);
    expect(_result, isTrue);
    expect(find.byKey(_cta), findsNothing);
    expect(c.isNewUnsaved, isFalse);
    await _drain(t);
  });

  testWidgets('double_tap_sends_one_create', (t) async {
    final api = installFakeApi([_planRoute(), FakeRoute('POST', '/trips', _echo)]);
    await _openSheet(t);
    await _type(t, 'Lake Days');
    await t.tap(find.byKey(_cta));
    await t.tap(find.byKey(_cta), warnIfMissed: false);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(api.calls('POST', '/trips'), hasLength(1));
    await _drain(t);
  });

  testWidgets('server_name_refusal_shows_line_and_keeps_sheet', (t) async {
    installFakeApi([_planRoute(), FakeRoute.value('POST', '/trips', null, code: 400, errorType: 'TripNameInvalid')]);
    final c = await _openSheet(t);
    await _type(t, 'Lake Days');
    await _tapCta(t);
    expect(find.byKey(_cta), findsOneWidget);
    expect(find.text(TripStringsName.invalid), findsOneWidget);
    expect(_fieldText(t), 'Lake Days');
    expect(c.isNewUnsaved, isTrue);
    expect(_result, isNull);
    await _type(t, 'Lake Days 2');
    expect(find.text(TripStringsName.invalid), findsNothing);
    await _drain(t);
  });

  testWidgets('network_failure_keeps_sheet_and_no_banner', (t) async {
    installFakeApi([_planRoute(), FakeRoute.value('POST', '/trips', null, code: 500, errorType: 'ServerError')]);
    final c = await _openSheet(t);
    await _type(t, 'Lake Days');
    await _tapCta(t);
    expect(find.byKey(_cta), findsOneWidget);
    expect(_button(t).loading, isFalse);
    expect(c.saveFailed.value, isFalse);
    expect(c.isNewUnsaved, isTrue);
    await _drain(t);
  });

  testWidgets('saved_trip_never_opens_the_save_sheet', (t) async {
    final plan = enginePlan([[2]]);
    Get.put<TabConfigController>(_Tabs());
    final c = TripPlanController();
    c.plan.value = plan;
    c.trip.value = engineTrip(plan);
    Get.put<TripPlanController>(c, permanent: true);
    _result = null;
    await pumpPhone(
      t,
      Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(key: _open, onPressed: () async => _result = await TripDatesSheet.saveTrip(ctx), child: const Text('open')),
        ),
      ),
    );
    await t.tap(find.byKey(_open));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(_cta), findsNothing);
    expect(_result, isFalse);
    await _drain(t);
  });

  testWidgets('button_fixed_and_visible_with_keyboard_five_sizes', (t) async {
    for (final size in fiveSizes) {
      await t.pumpWidget(const SizedBox.shrink());
      Get.reset();
      installFakeApi([_planRoute()]);
      await _openSheet(t, size: size, keyboard: 300);
      expect(t.takeException(), isNull, reason: sizeLabel(size));
      final cta = t.getRect(find.byKey(_cta));
      expect(cta.bottom, lessThanOrEqualTo(size.height - 300), reason: sizeLabel(size));
      expect(cta.left, greaterThanOrEqualTo(0), reason: sizeLabel(size));
      expect(cta.right, lessThanOrEqualTo(size.width), reason: sizeLabel(size));
      expect(t.getRect(find.text(TripStringsSaveTrip.title)).top, greaterThan(phoneTopInset), reason: sizeLabel(size));
      expect(find.ancestor(of: find.byKey(_cta), matching: find.byType(Scrollable)), findsNothing, reason: sizeLabel(size));
      t.view.resetViewInsets();
      await t.pump();
    }
    await _drain(t);
  });

  testWidgets('sheet_five_sizes_without_keyboard', (t) async {
    for (final size in fiveSizes) {
      await t.pumpWidget(const SizedBox.shrink());
      Get.reset();
      installFakeApi([_planRoute()]);
      await _openSheet(t, size: size);
      expect(t.takeException(), isNull, reason: sizeLabel(size));
      final field = t.getRect(find.byKey(_field));
      final cta = t.getRect(find.byKey(_cta));
      expect(field.bottom, lessThan(cta.top), reason: sizeLabel(size));
      expect(cta.bottom, lessThanOrEqualTo(size.height), reason: sizeLabel(size));
      expect(t.getRect(find.text(TripStringsSaveTrip.title)).top, greaterThan(size.height * 0.1), reason: sizeLabel(size));
    }
    await _drain(t);
  });
}
