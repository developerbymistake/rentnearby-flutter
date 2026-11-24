import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/config/app_theme.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/data/trip_city_catalog.dart';
import 'package:bakhli/features/trip/models/trip_city_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/screens/trip_plan_screen.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/features/trip/trip_strings_customize.dart';
import 'package:bakhli/features/trip/trip_strings_dayplan.dart';
import 'package:bakhli/features/trip/trip_strings_mca_a2.dart';
import 'package:bakhli/features/trip/trip_strings_mca_a3.dart';
import 'package:bakhli/features/trip/trip_strings_name.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:bakhli/features/trip/utils/trip_name_rules.dart';
import 'package:bakhli/features/trip/widgets/trip_add_city_card.dart';
import 'package:bakhli/features/trip/widgets/customize/trip_customize_spot_row.dart' show TripDashBox;
import 'package:bakhli/features/trip/widgets/trip_day_spot_list.dart';
import 'package:bakhli/features/trip/widgets/trip_leg_header.dart';
import 'package:bakhli/features/trip/widgets/trip_plan_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/five_sizes.dart';
import '../../support/real_phone.dart';
import 'support/engine_rig.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

const tallPhone = Size(360, 2400);

TripPlan dayPlanFixture({List<List<int>> perLeg = const [[2, 2, 2]]}) {
  final p = enginePlan(perLeg);
  return TripPlan(
    legs: p.legs,
    days: p.days,
    settings: p.settings,
    steps: const TripSteps(startFrom: TripStartFrom(name: 'Kathgodam', lat: 29.26, lon: 79.52)),
  );
}

Future<TripPlanController> pumpDayPlan(
  WidgetTester t,
  TripPlan plan, {
  Size size = tallPhone,
  TripPlanLock lock = TripPlanLock.none,
  double textScale = 1,
  List<GetPage> pages = const [],
}) async {
  Get.put<TabConfigController>(_Tabs());
  TripCityCatalog.to.seedForTest(const [
    TripCityModel(cityKey: 901, name: 'Bhimtal', stateName: 'Uttarakhand', latitude: 29.35, longitude: 79.56),
    TripCityModel(cityKey: 902, name: 'Mukteshwar', stateName: 'Uttarakhand', latitude: 29.47, longitude: 79.65),
    TripCityModel(cityKey: 903, name: 'Shimla', stateName: 'Himachal Pradesh', latitude: 31.10, longitude: 77.17),
  ]);
  final c = TripPlanController();
  c.plan.value = plan;
  c.trip.value = engineTrip(plan, lock: lock);
  Get.put<TripPlanController>(c, permanent: true);
  if (pages.isEmpty) {
    await pumpPhone(t, const TripPlanScreen(), size: size, textScale: textScale);
  } else {
    await loadRealFonts();
    final view = t.view;
    view.devicePixelRatio = 3;
    view.physicalSize = Size(size.width * 3, size.height * 3);
    view.padding = FakeViewPadding(top: phoneTopInset * 3, bottom: phoneBottomInset * 3);
    view.viewPadding = view.padding;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
      view.resetPadding();
      view.resetViewPadding();
    });
    await t.pumpWidget(GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      scrollBehavior: const AppScrollBehavior(),
      getPages: [GetPage(name: '/', page: () => const TripPlanScreen()), ...pages],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
        child: child!,
      ),
    ));
  }
  await settlePhone(t);
  return c;
}

Future<void> drainSave(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(minutes: 2));
}

Future<void> openRename(WidgetTester t) async {
  await t.tap(find.byKey(TripMenuDots.boxKey).first);
  await t.pumpAndSettle();
  await t.tap(find.text(TripStringsV2Plan.menuRename));
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  testWidgets('no_progress_card_name_only_in_header', (t) async {
    await pumpDayPlan(t, dayPlanFixture());
    expect(find.descendant(of: find.byType(TripPlanHeader), matching: find.text('Uttarakhand Hills Trip')), findsOneWidget);
    expect(find.text('Uttarakhand Hills Trip'), findsOneWidget);
    expect(find.text('Your plan'), findsNothing);
    expect(find.byKey(const ValueKey('plan-top-card')), findsNothing);
    final cardTop = t.getRect(find.byKey(TripLegSectionHeader.cardKey).first).top;
    expect(cardTop - t.getRect(find.byType(TripPlanHeader)).bottom, closeTo(TripLegSectionHeader.gapAbove + DS.s(2), 1));
  });

  testWidgets('city_and_day_art_sit_inside_their_headers', (t) async {
    await pumpDayPlan(t, dayPlanFixture());
    final card = find.byKey(TripLegSectionHeader.cardKey).first;
    final cardRect = t.getRect(card);
    final luggage = find.descendant(of: card, matching: find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.luggage));
    expect(luggage, findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.mountain), findsNothing);
    final luggageRect = t.getRect(luggage);
    expect(luggageRect.top, greaterThanOrEqualTo(cardRect.top));
    expect(luggageRect.left, greaterThanOrEqualTo(cardRect.left));
    expect(luggageRect.right, lessThanOrEqualTo(t.getRect(find.descendant(of: card, matching: find.text('Nainital'))).left));
    final detail = t.renderObject<RenderParagraph>(find.byKey(TripLegSectionHeader.detailKey).first);
    final boxes = detail.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: detail.text.toPlainText().length));
    expect({for (final b in boxes) b.top.round()}.length, 1);

    final header = find.byKey(TripDaySpotList.headerKey).first;
    final headerRect = t.getRect(header);
    final calendar = find.descendant(of: header, matching: find.byWidgetPredicate((w) => w is Art3D && w.asset == ListingArt.calendar));
    expect(calendar, findsOneWidget);
    final calendarRect = t.getRect(calendar);
    expect(calendarRect.top, greaterThanOrEqualTo(headerRect.top));
    expect(calendarRect.bottom, lessThanOrEqualTo(headerRect.bottom));
  });

  testWidgets('city_is_coral_day_is_green_and_no_dot_before_day', (t) async {
    await pumpDayPlan(t, dayPlanFixture(perLeg: const [[2, 2], [1, 1]]));
    Gradient? gradientOf(Finder f) => ((t.widget<Container>(f).decoration) as BoxDecoration).gradient;
    for (final e in find.byKey(TripLegSectionHeader.cardKey).evaluate()) {
      expect(gradientOf(find.byWidget(e.widget)), TripLook.cityTone.gradient);
    }
    final headers = find.byKey(TripDaySpotList.headerKey);
    expect(headers, findsWidgets);
    for (final e in headers.evaluate()) {
      final header = find.byWidget(e.widget);
      expect(gradientOf(header), TripLook.dayTone.gradient);
      final dot = find.descendant(
        of: header,
        matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).shape == BoxShape.circle && (w.decoration! as BoxDecoration).border != null),
      );
      expect(dot, findsNothing);
    }
    final pill = t.widget<Text>(find.text(TripStringsDayplan.customize).first);
    expect(pill.style!.color, TripLook.cityInk);
    final fold = t.widget<Text>(find.text(TripStringsDayplan.hide).first);
    expect(fold.style!.color, TripLook.cityInk);
  });

  testWidgets('day_header_chips', (t) async {
    await pumpDayPlan(t, dayPlanFixture());
    final header = find.byKey(TripDaySpotList.headerKey).first;
    final art = find.descendant(of: header, matching: find.byType(Art3D));
    expect(art.evaluate().any((e) => (e.widget as Art3D).asset == ListingArt.calendar), isTrue);
    final chips = find.descendant(of: header, matching: find.byKey(TripDaySpotList.chipsKey));
    expect(chips, findsOneWidget);
    expect(find.descendant(of: chips, matching: find.text('2 places')), findsOneWidget);
    expect(find.descendant(of: chips, matching: find.byType(Text)), findsNWidgets(2));
    expect(t.getSize(header).height, greaterThanOrEqualTo(DS.s(90)));
  });

  testWidgets('single-city header', (t) async {
    await pumpDayPlan(t, dayPlanFixture());
    expect(find.byType(TripLegHeader), findsOneWidget);
    expect(find.text('Nainital'), findsWidgets);
    expect(find.byKey(TripLegSectionHeader.customizeKey), findsOneWidget);
    expect(find.byKey(TripLegSectionHeader.foldKey), findsOneWidget);
  });

  testWidgets('fold hides days', (t) async {
    await pumpDayPlan(t, dayPlanFixture(perLeg: const [[2, 2], [1, 1]]));
    expect(find.byType(TripDaySpotList), findsNWidgets(4));
    await t.tap(find.byKey(TripLegSectionHeader.foldKey).first);
    await t.pumpAndSettle();
    expect(find.byType(TripDaySpotList), findsNWidgets(2));
    expect(find.textContaining(TripStringsDayplan.foldedSummary(2, 4)), findsOneWidget);
    await t.tap(find.byKey(TripLegSectionHeader.foldKey).first);
    await t.pumpAndSettle();
    expect(find.byType(TripDaySpotList), findsNWidgets(4));
  });

  testWidgets('unlocked plan unchanged', (t) async {
    final c = await pumpDayPlan(t, dayPlanFixture());
    expect(c.canEditStructure, isTrue);
    expect(find.byKey(TripPlanScreen.lockedBannerKey), findsNothing);
    expect(find.byKey(TripPlanScreen.viewButtonKey), findsNothing);
    expect(find.byType(TripAddCityCard), findsOneWidget);
    expect(find.text(TripStringsDayplan.backToOverview), findsOneWidget);
  });

  testWidgets('customize_opens_the_route_with_the_leg', (t) async {
    Object? args;
    await pumpDayPlan(t, dayPlanFixture(perLeg: const [[2, 2], [1, 1]]), pages: [
      GetPage(name: AppRoutes.tripCustomize, page: () {
        args = Get.arguments;
        return const Scaffold(body: Text('customize'));
      }),
    ]);
    await t.tap(find.byKey(TripLegSectionHeader.customizeKey).last);
    await t.pumpAndSettle();
    expect(find.text('customize'), findsOneWidget);
    expect(args, isA<Map>().having((m) => m['tripId'], 'tripId', 't1').having((m) => m['leg'], 'leg', 2).having((m) => m['toast'], 'toast', isNotNull));
  });

  testWidgets('add_city_card_looks_like_the_add_day_card', (t) async {
    await pumpDayPlan(t, dayPlanFixture());
    final card = find.byType(TripAddCityCard);
    expect(find.descendant(of: card, matching: find.text(TripStringsMcaA2.addACityRow)), findsOneWidget);
    expect(find.descendant(of: card, matching: find.byType(Art3D)), findsNothing);
    final paint = t.widget<CustomPaint>(find.descendant(of: card, matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is TripDashBox)));
    final dash = paint.painter! as TripDashBox;
    expect(dash.line, DesignColors.addDayLine);
    expect(dash.fill, DesignColors.addDayFill);
    expect(find.descendant(of: card, matching: find.text(TripStringsMcaA3.nearbyCities(const ['Bhimtal', 'Mukteshwar']))), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(TripStringsMcaA3.addAnotherCity)), findsNothing);
    expect(find.descendant(of: card, matching: find.byIcon(Icons.add_rounded)), findsNothing);
  });

  testWidgets('plan_updated_note_is_a_dark_bar_above_save_trip', (t) async {
    Object? args;
    await pumpDayPlan(t, dayPlanFixture(), size: const Size(360, 800), pages: [
      GetPage(name: AppRoutes.tripCustomize, page: () {
        args = Get.arguments;
        return const Scaffold(body: Text('customize'));
      }),
    ]);
    await t.tap(find.byKey(TripLegSectionHeader.customizeKey).first);
    await t.pumpAndSettle();
    final toast = (args as Map)['toast'] as void Function(bool, String);
    Get.back();
    await t.pumpAndSettle();
    toast(true, TripStringsCustomize.planUpdated);
    await t.pump();
    final note = find.byKey(TripPlanScreen.noteKey);
    expect(note, findsOneWidget);
    expect(find.descendant(of: note, matching: find.text(TripStringsCustomize.planUpdated)), findsOneWidget);
    expect(find.descendant(of: note, matching: find.byType(Icon)), findsNothing);
    expect(((t.widget<Container>(note).decoration) as BoxDecoration).color, TripLook.ink);
    expect(t.getRect(note).bottom, lessThanOrEqualTo(t.getRect(find.byKey(TripPlanScreen.saveTripKey)).top));
    expect(t.getRect(note).top, greaterThan(t.getRect(find.byType(TripPlanHeader)).bottom));
    await t.pump(const Duration(seconds: 4));
    expect(note, findsNothing);
  });

  testWidgets('day_count_follows_the_plan', (t) async {
    final plan = dayPlanFixture();
    final c = await pumpDayPlan(t, plan);
    expect(find.byType(TripDaySpotList), findsNWidgets(3));
    expect(find.textContaining('3 days'), findsWidgets);
    c.plan.value = plan.copyWith(days: plan.days.take(2).toList());
    await t.pumpAndSettle();
    expect(find.byType(TripDaySpotList), findsNWidgets(2));
    expect(find.textContaining('2 days'), findsWidgets);
  });

  testWidgets('rename_field_is_limited_to_60', (t) async {
    await pumpDayPlan(t, dayPlanFixture(), size: const Size(360, 800));
    await openRename(t);
    final input = find.descendant(of: find.byKey(TripPlanScreen.renameFieldKey), matching: find.byType(TextField));
    expect(input, findsOneWidget);
    final tf = t.widget<TextField>(input);
    expect(tf.maxLength, TripNameRules.max);
    await t.enterText(input, List.filled(75, 'a').join());
    await t.pump();
    expect(tf.controller!.text.length, 60);
    expect(find.text(TripStringsName.counter(60)), findsOneWidget);
  });

  testWidgets('rename_empty_keeps_the_dialog_open', (t) async {
    final c = await pumpDayPlan(t, dayPlanFixture(), size: const Size(360, 800));
    await openRename(t);
    final input = find.descendant(of: find.byKey(TripPlanScreen.renameFieldKey), matching: find.byType(TextField));
    await t.enterText(input, '   ');
    await t.tap(find.text(TripStringsV2Plan.save));
    await t.pumpAndSettle();
    expect(find.byKey(TripPlanScreen.renameFieldKey), findsOneWidget);
    expect(find.text(TripStringsName.empty), findsOneWidget);
    expect(c.title, 'Uttarakhand Hills Trip');
    await t.enterText(input, 'x');
    await t.pump();
    expect(find.text(TripStringsName.empty), findsNothing);
  });

  testWidgets('rename_dialog_five_sizes', (t) async {
    for (final size in fiveSizes) {
      await t.pumpWidget(const SizedBox.shrink());
      Get.reset();
      await pumpDayPlan(t, dayPlanFixture(), size: size);
      await openRename(t);
      expect(find.byKey(TripPlanScreen.renameFieldKey), findsOneWidget, reason: sizeLabel(size));
      expect(t.takeException(), isNull, reason: sizeLabel(size));
      if (size.height < 600) {
        t.view.viewInsets = FakeViewPadding(bottom: 250 * t.view.devicePixelRatio);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'keyboard ${sizeLabel(size)}');
        expect(find.text(TripStringsV2Plan.save).hitTestable(), findsOneWidget);
        t.view.resetViewInsets();
      }
    }
  });

  testWidgets('rename_save_sends_the_clean_name', (t) async {
    final c = await pumpDayPlan(t, dayPlanFixture(), size: const Size(360, 800));
    await openRename(t);
    final input = find.descendant(of: find.byKey(TripPlanScreen.renameFieldKey), matching: find.byType(TextField));
    await t.enterText(input, '   Hills   and \t lakes  ');
    await t.tap(find.text(TripStringsV2Plan.save));
    await t.pumpAndSettle();
    expect(find.byKey(TripPlanScreen.renameFieldKey), findsNothing);
    expect(c.title, 'Hills and lakes');
    await drainSave(t);
  });

  testWidgets('rename_prefill_cuts_old_long_title_to_60', (t) async {
    final c = await pumpDayPlan(t, dayPlanFixture(), size: const Size(360, 800));
    final long = List.filled(70, 'b').join();
    c.trip.value = c.trip.value!.copyWith(title: long, nameChosen: true);
    await t.pumpAndSettle();
    expect(c.title, long);
    await openRename(t);
    final input = find.descendant(of: find.byKey(TripPlanScreen.renameFieldKey), matching: find.byType(TextField));
    expect(t.widget<TextField>(input).controller!.text, long.substring(0, TripNameRules.max));
  });

  testWidgets('edit_mode_header_has_no_pace_chip', (t) async {
    final c = await pumpDayPlan(t, dayPlanFixture());
    c.editMode.value = true;
    await t.pumpAndSettle();
    final header = find.byType(TripPlanHeader);
    expect(find.descendant(of: header, matching: find.text('Relaxed')), findsNothing);
    expect(find.descendant(of: header, matching: find.text('Normal')), findsNothing);
  });

  testWidgets('city_header_has_no_menu', (t) async {
    await pumpDayPlan(t, dayPlanFixture(perLeg: const [[2, 2], [1, 1]]));
    expect(find.byKey(TripLegSectionHeader.customizeKey), findsWidgets);
    expect(find.byKey(const ValueKey('leg-menu')), findsNothing);
  });

  testWidgets('unavailable_city_banner_removes_the_city', (t) async {
    final c = await pumpDayPlan(t, dayPlanFixture(perLeg: const [[2, 2], [1, 1]]));
    c.unavailableCities.add(c.plan.value!.legAt(2)!.cityKey);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text(TripStringsMcaA3.removeCity));
    await t.tap(find.text(TripStringsMcaA3.removeCity));
    await t.pumpAndSettle();
    await t.tap(find.text(TripStringsMcaA3.remove));
    await t.pumpAndSettle();
    expect(c.plan.value!.legCount, 1);
    await t.pump(const Duration(seconds: 10));
  });

  testWidgets('unavailable_one_city_plan_has_no_remove_action', (t) async {
    final c = await pumpDayPlan(t, dayPlanFixture());
    c.unavailableCities.add(c.plan.value!.legAt(1)!.cityKey);
    await t.pumpAndSettle();
    expect(find.text(TripStringsMcaA3.removeCity), findsNothing);
  });

  testWidgets('five sizes', (t) async {
    for (final size in fiveSizes) {
      await t.pumpWidget(const SizedBox.shrink());
      Get.reset();
      await pumpDayPlan(t, dayPlanFixture(perLeg: const [[2, 2], [1, 1]]), size: size);
      expect(t.takeException(), isNull, reason: sizeLabel(size));
    }
  });

}
