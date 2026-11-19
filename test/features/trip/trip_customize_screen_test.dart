import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/screens/trip_customize_screen.dart';
import 'package:bakhli/features/trip/trip_strings_customize.dart';
import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';
import 'support/engine_rig.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

final List<String> _toasts = [];

const _openKey = ValueKey('open-customize');

TripPlanController _rig(TripPlan plan, {TripPlanLock lock = TripPlanLock.none}) {
  Get.put<TabConfigController>(_Tabs());
  final c = TripPlanController();
  c.plan.value = plan;
  c.trip.value = engineTrip(plan, lock: lock);
  Get.put<TripPlanController>(c);
  return c;
}

Widget _host({TripDraftPicker? picker, int leg = 1}) => Scaffold(
      body: Center(
        child: TextButton(
          key: _openKey,
          onPressed: () => Get.to(() => TripCustomizeScreen(legIndex: leg, picker: picker, toast: (ok, m) => _toasts.add('${ok ? 'ok' : 'warn'}:$m'))),
          child: const Text('open'),
        ),
      ),
    );

Future<void> _open(WidgetTester tester, {Size size = phoneSize, TripDraftPicker? picker, int leg = 1}) async {
  await pumpPhone(tester, _host(picker: picker, leg: leg), size: size);
  await tester.tap(find.byKey(_openKey));
  await tester.pumpAndSettle();
}

Future<void> _tapAddDay(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('customize-add-day')));
  await tester.tap(find.byKey(const ValueKey('customize-add-day')));
  await tester.pumpAndSettle();
}

Future<void> _deleteDay(WidgetTester tester, int index) async {
  final menu = find.byKey(ValueKey('customize-day-menu-$index'));
  await tester.ensureVisible(menu);
  await tester.tap(menu);
  await tester.pumpAndSettle();
  await tester.tap(find.text(TripStringsCustomize.deleteDay).last);
  await tester.pumpAndSettle();
}

GradientPillButton _update(WidgetTester t) => t.widget<GradientPillButton>(find.byKey(const ValueKey('customize-update')));

Future<void> _tapUpdate(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('customize-update')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

bool _isLive(GradientPillButton b) => b.enabled && b.onTap != null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (call) async => Directory.systemTemp.createTempSync('customize_gs').path);
    await GetStorage.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });
  setUp(_toasts.clear);
  tearDown(Get.reset);

  testWidgets('renders_draft', (tester) async {
    _rig(enginePlan([[3, 2, 1]], start: DateTime(2030, 12, 18)));
    await _open(tester);
    expect(find.text('Customize Nainital'), findsOneWidget);
    expect(find.text('18-20 Dec · 3 days · 6 places'), findsOneWidget);
    expect(find.text(TripStringsCustomize.hintDrag), findsOneWidget);
    expect(find.text(TripStringsCustomize.hintCity), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('customize-day-$i')), findsOneWidget);
    }
    expect(find.text(TripStringsCustomize.reset), findsOneWidget);
    expect(find.text(TripStringsCustomize.update), findsOneWidget);
  });

  testWidgets('update_live_without_error_and_plan_untouched', (tester) async {
    final c = _rig(enginePlan([[3, 2]]));
    final before = legSignature(c.plan.value!, 1);
    await _open(tester);
    expect(_isLive(_update(tester)), isTrue);
    await _tapAddDay(tester);
    expect(_isLive(_update(tester)), isTrue);
    expect(legSignature(c.plan.value!, 1), before);
    expect(c.plan.value!.legDayCount(1), 2);
  });

  testWidgets('update_unchanged_just_closes', (tester) async {
    final c = _rig(enginePlan([[3, 2]]));
    final before = legSignature(c.plan.value!, 1);
    await _open(tester);
    await _tapUpdate(tester);
    await tester.pumpAndSettle();
    expect(find.byType(TripCustomizeScreen), findsNothing);
    expect(legSignature(c.plan.value!, 1), before);
    expect(_toasts, isEmpty);
  });

  testWidgets('empty_day_blocks_update_with_inline_text', (tester) async {
    final c = _rig(enginePlan([[3, 2]]));
    await _open(tester);
    await _tapAddDay(tester);
    await _tapUpdate(tester);
    expect(find.text(TripStringsCustomize.emptyDayError(3)), findsOneWidget);
    expect(find.byKey(const ValueKey('customize-day-error-2')), findsOneWidget);
    expect(find.byType(TripCustomizeScreen), findsOneWidget);
    expect(c.plan.value!.legDayCount(1), 2);
    expect(_isLive(_update(tester)), isFalse);
    await _deleteDay(tester, 2);
    expect(find.text(TripStringsCustomize.emptyDayError(3)), findsNothing);
    expect(_isLive(_update(tester)), isTrue);
    await _tapAddDay(tester);
    expect(_isLive(_update(tester)), isTrue);
  });

  testWidgets('rest_day_passes', (tester) async {
    final c = _rig(enginePlan([[2, 0, 1]], restDays: {2}));
    await _open(tester);
    await _deleteDay(tester, 2);
    await _tapUpdate(tester);
    expect(find.text(TripStringsCustomize.emptyDayError(2)), findsNothing);
    expect(find.byType(TripCustomizeScreen), findsNothing);
    expect(c.plan.value!.legDayCount(1), 2);
    expect(legSignature(c.plan.value!, 1), [':L1d1s0,L1d1s1,L1d3s0', 'R:']);
    Get.delete<TripPlanController>(force: true);
  });

  testWidgets('delete_blocked_banner', (tester) async {
    _rig(enginePlan([[6, 6, 1]]));
    await _open(tester);
    await _deleteDay(tester, 2);
    expect(find.text(TripStringsCustomize.blockedTitle(2)), findsOneWidget);
    expect(find.text('13 places. 2 days fit 12.'), findsOneWidget);
    expect(find.byKey(const ValueKey('customize-day-2')), findsOneWidget);
    expect(_isLive(_update(tester)), isFalse);
  });

  testWidgets('delete_done_banner', (tester) async {
    _rig(enginePlan([[3, 2, 3]]));
    await _open(tester);
    await _deleteDay(tester, 2);
    expect(find.text('Day 3 deleted. Its 3 places moved into Day 1.'), findsOneWidget);
    expect(find.byKey(const ValueKey('customize-day-2')), findsNothing);
    expect(_isLive(_update(tester)), isTrue);
  });

  testWidgets('reset_restores', (tester) async {
    _rig(enginePlan([[3, 2]]));
    await _open(tester);
    await _tapAddDay(tester);
    expect(find.byKey(const ValueKey('customize-day-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('customize-reset')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('customize-day-2')), findsNothing);
    expect(_isLive(_update(tester)), isTrue);
  });

  testWidgets('discard_dialog_both_answers', (tester) async {
    final c = _rig(enginePlan([[3, 2]]));
    await _open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TripCustomizeScreen), findsNothing);
    expect(find.text(TripStringsCustomize.discardTitle), findsNothing);
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    await _tapAddDay(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(TripStringsCustomize.discardTitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('customize-keep-editing')));
    await tester.pumpAndSettle();
    expect(find.byType(TripCustomizeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('customize-day-2')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customize-discard')));
    await tester.pumpAndSettle();
    expect(find.byType(TripCustomizeScreen), findsNothing);
    expect(c.plan.value!.legDayCount(1), 2);
  });

  testWidgets('add_places_feeds_the_draft_only', (tester) async {
    final c = _rig(enginePlan([[2, 1]]));
    final asked = <List<Object>>[];
    await _open(tester, picker: (city, {required legIndex, required dayNumber, required dayCount, required existingIds}) async {
      asked.add([city.name, dayNumber, dayCount, existingIds.length]);
      return const [
        TripSpotModel(id: 'new1', source: 'osm', name: 'New one', latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60),
      ];
    });
    final add = find.byKey(const ValueKey('customize-add-1'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(asked.single, ['Nainital', 2, 1, 3]);
    expect(find.byKey(const ValueKey('customize-row-new1')), findsOneWidget);
    expect(c.plan.value!.spotCount, 3);
    expect(_isLive(_update(tester)), isTrue);
  });

  testWidgets('add_places_default_picker_through_named_route', (tester) async {
    final c = _rig(enginePlan([[2, 1]]));
    Object? seen;
    tester.view.physicalSize = phoneSize * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GetMaterialApp(
      getPages: [
        GetPage(
          name: AppRoutes.tripSpots,
          page: () {
            seen = Get.arguments;
            return Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('stub-pick'),
                  onPressed: () => Get.back(result: const <TripSpotModel>[
                    TripSpotModel(id: 'new1', source: 'osm', name: 'New one', latitude: 29.4, longitude: 79.4, category: 'attraction', visitMinutes: 60),
                  ]),
                  child: const Text('pick'),
                ),
              ),
            );
          },
        ),
      ],
      home: Scaffold(
        body: Center(
          child: TextButton(
            key: _openKey,
            onPressed: () => Get.to(() => TripCustomizeScreen(legIndex: 1, toast: (ok, m) => _toasts.add('${ok ? 'ok' : 'warn'}:$m'))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('customize-add-1'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('stub-pick')), findsOneWidget);
    expect(seen, isA<Map>());
    final args = seen as Map;
    expect(args['pickForDraft'], isTrue);
    expect(args['legIndex'], 1);
    expect(args['dayNumber'], 2);
    await tester.tap(find.byKey(const ValueKey('stub-pick')));
    await tester.pumpAndSettle();
    expect(find.byType(TripCustomizeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('customize-row-new1')), findsOneWidget);
    expect(c.plan.value!.spotCount, 3);
    expect(_isLive(_update(tester)), isTrue);
  });

  testWidgets('header_back_asks_before_discard', (tester) async {
    final c = _rig(enginePlan([[3, 2]]));
    await _open(tester);
    final back = find.descendant(of: find.byType(ModuleHeader), matching: find.byIcon(Icons.arrow_back_ios_new_rounded));
    await _tapAddDay(tester);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text(TripStringsCustomize.discardTitle), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('customize-keep-editing')));
    await tester.pumpAndSettle();
    expect(find.byType(TripCustomizeScreen), findsOneWidget);
    await tester.tap(back);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customize-discard')));
    await tester.pumpAndSettle();
    expect(find.byType(TripCustomizeScreen), findsNothing);
    expect(c.plan.value!.legDayCount(1), 2);
  });

  testWidgets('missing_leg_closes_with_message', (tester) async {
    _rig(enginePlan([[3, 2]]));
    await _open(tester, leg: 7);
    expect(find.byType(TripCustomizeScreen), findsNothing);
    expect(_toasts, ['warn:${TripStringsCustomize.missingCity}']);
  });

  testWidgets('read_only_path_says_why', (tester) async {
    final c = _rig(enginePlan([[3, 2]]));
    await _open(tester);
    await _deleteDay(tester, 1);
    c.trip.value = engineTrip(c.plan.value!, status: TripStatuses.completed);
    await _tapUpdate(tester);
    expect(find.byType(TripCustomizeScreen), findsOneWidget);
    expect(_toasts, ['warn:${TripStringsCustomize.readOnly}']);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('update_applies_once_and_toasts_plan_updated', (tester) async {
    final c = _rig(enginePlan([[3, 2]]));
    var writes = 0;
    final sub = c.plan.listen((_) => writes++);
    addTearDown(sub.cancel);
    await _open(tester);
    await _deleteDay(tester, 1);
    expect(writes, 0);
    await _tapUpdate(tester);
    expect(writes, 1);
    expect(find.byType(TripCustomizeScreen), findsNothing);
    expect(_toasts, ['ok:${TripStringsCustomize.planUpdated}']);
    expect(c.plan.value!.legDayCount(1), 1);
    Get.delete<TripPlanController>(force: true);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('double_tap_update_pops_only_customize', (tester) async {
    final c = _rig(enginePlan([[3, 2]]));
    var writes = 0;
    final sub = c.plan.listen((_) => writes++);
    addTearDown(sub.cancel);
    const dayPlanKey = ValueKey('stub-day-plan');
    await pumpPhone(
      tester,
      Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('open-day-plan'),
            onPressed: () => Get.to(() => Scaffold(key: dayPlanKey, body: _host())),
            child: const Text('day plan'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-day-plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();
    await _deleteDay(tester, 1);
    final onTap = _update(tester).onTap!;
    onTap();
    onTap();
    await tester.pumpAndSettle();
    expect(find.byType(TripCustomizeScreen), findsNothing);
    expect(find.byKey(dayPlanKey), findsOneWidget);
    expect(writes, 1);
    expect(_toasts, ['ok:${TripStringsCustomize.planUpdated}']);
    expect(c.plan.value!.legDayCount(1), 1);
    Get.delete<TripPlanController>(force: true);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('blocked_update_can_be_tapped_again', (tester) async {
    final c = _rig(enginePlan([[3, 2]]));
    await _open(tester);
    await _deleteDay(tester, 1);
    c.trip.value = engineTrip(c.plan.value!, lock: lockedByRequest);
    await _tapUpdate(tester);
    expect(_toasts, ['warn:${c.planLockMessage}']);
    c.trip.value = engineTrip(c.plan.value!);
    await _tapUpdate(tester);
    expect(find.byType(TripCustomizeScreen), findsNothing);
    expect(_toasts, ['warn:${c.planLockMessage}', 'ok:${TripStringsCustomize.planUpdated}']);
    Get.delete<TripPlanController>(force: true);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('other_cities_identical_after_update', (tester) async {
    final c = _rig(enginePlan([[2, 1], [2, 2], [1]]));
    final before = c.plan.value!;
    await _open(tester, leg: 2);
    await _deleteDay(tester, 1);
    await _tapUpdate(tester);
    final after = c.plan.value!;
    expect(legSignature(after, 1), legSignature(before, 1));
    expect(legSignature(after, 3), legSignature(before, 3));
    expect(after.legDayCount(2), 1);
    expect(after.legs.map((l) => l.cityKey).toList(), [1, 2, 3]);
    Get.delete<TripPlanController>(force: true);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('stale_path_closes_with_message', (tester) async {
    final c = _rig(enginePlan([[3, 2]]));
    await _open(tester);
    await _tapAddDay(tester);
    c.plan.value = enginePlan([[2, 3]]);
    await _tapUpdate(tester);
    expect(find.byType(TripCustomizeScreen), findsNothing);
    expect(_toasts, ['warn:${TripStringsCustomize.planChanged}']);
    expect(legSignature(c.plan.value!, 1), legSignature(enginePlan([[2, 3]]), 1));
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('locked_path_stays_with_lock_text', (tester) async {
    final c = _rig(enginePlan([[3, 2]]));
    await _open(tester);
    await _deleteDay(tester, 1);
    c.trip.value = engineTrip(c.plan.value!, lock: lockedByRequest);
    await _tapUpdate(tester);
    expect(find.byType(TripCustomizeScreen), findsOneWidget);
    expect(_toasts, ['warn:${c.planLockMessage}']);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  group('five_sizes', () {
    for (final size in fiveSizes) {
      testWidgets('five_sizes_${sizeLabel(size)}', (tester) async {
        _rig(enginePlan([[6, 6, 3, 0]], restDays: {4}, start: DateTime(2030, 12, 18)));
        await _open(tester, size: size);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('customize-update')), findsOneWidget);
        expect(tester.getBottomLeft(find.byKey(const ValueKey('customize-update'))).dy, lessThanOrEqualTo(size.height));
        await _deleteDay(tester, 2);
        expect(tester.takeException(), isNull);
        await _tapAddDay(tester);
        await _tapUpdate(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('customize-day-error-3')), findsOneWidget);
        expect(tester.getBottomLeft(find.byKey(const ValueKey('customize-update'))).dy, lessThanOrEqualTo(size.height));
      });
    }
  });
}
