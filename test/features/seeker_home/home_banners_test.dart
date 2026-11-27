import 'dart:io';

import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/widgets/home_hero_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../support/owner_sizes.dart';
import '../../support/real_phone.dart';

class _Auth extends AuthController {
  _Auth({this.stayOwner = false});

  final bool stayOwner;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  bool get staysEnabled => stayOwner;

  @override
  bool get taxisEnabled => false;

  @override
  bool get effectiveIsOwner => stayOwner;
}

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

Widget _carousel() => const Scaffold(body: SafeArea(child: SingleChildScrollView(child: HomeHeroCarousel())));

Finder _cardOf(String title) => find.ancestor(of: find.text(title, skipOffstage: false), matching: find.byType(WorkoutCard, skipOffstage: false)).first;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('home_banners').path,
    );
    await GetStorage.init();
  });
  tearDown(Get.reset);

  void register({bool stayOwner = false}) {
    Get.reset();
    Get.put<TabConfigController>(_Tabs());
    Get.put<AuthController>(_Auth(stayOwner: stayOwner));
  }

  testWidgets('I-17: the traveller sees only the Trip slide, no dots and no auto-slide', (t) async {
    register();
    await pumpPhone(t, _carousel(), size: const Size(360, 800));
    final card = _cardOf('Plan your trip');
    expect(t.widget<WorkoutCard>(card).actionLabel, 'Plan a trip');
    expect(t.widget<WorkoutCard>(card).minHeight, 156);
    for (final s in ['Looking for a stay?', 'Find your stay', 'Need a taxi?', 'Find a taxi']) {
      expect(find.text(s, skipOffstage: false), findsNothing, reason: s);
    }
    expect(find.byType(PageView), findsNothing);
    await t.pump(const Duration(seconds: 5));
    expect(find.text('Plan your trip'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Bug 10: owner slide keeps its words and the plain round arrow on the same base', (t) async {
    register(stayOwner: true);
    await pumpPhone(t, _carousel(), size: const Size(360, 800));
    final card = _cardOf('List your stay');
    final w = t.widget<WorkoutCard>(card);
    expect(w.actionLabel, isNull);
    expect(w.trailing, WorkoutTrailing.arrow);
    expect(w.minHeight, 156);
    expect(w.subtitle, 'Grow your reach');
    expect(find.descendant(of: card, matching: find.byType(RoundGoButton, skipOffstage: false)), findsOneWidget);
    expect(find.descendant(of: card, matching: find.byType(WorkoutActionPill, skipOffstage: false)), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  for (final size in ownerSizes) {
    for (final scale in ownerTextScales) {
      testWidgets('Bug 10: carousel has no overflow and the pill never crowds the text at ${ownerSizeLabel(size, scale)}', (t) async {
        register();
        await pumpPhone(t, _carousel(), size: size, textScale: scale);
        expect(t.takeException(), isNull);
        const title = 'Plan your trip';
        final shown = find.ancestor(of: find.text(title), matching: find.byType(WorkoutCard)).first;
        final box = t.getRect(find.descendant(of: shown, matching: find.byType(DecoratedBox)).first);
        final pill = t.getRect(find.descendant(of: shown, matching: find.byType(WorkoutActionPill)));
        expect(box.right - pill.right, moreOrLessEquals(DS.s(20), epsilon: 0.5), reason: title);
        expect(box.bottom - pill.bottom, moreOrLessEquals(DS.s(20), epsilon: 0.5), reason: title);
        expect(pill.left, greaterThanOrEqualTo(box.left), reason: title);
        for (final text in find.descendant(of: shown, matching: find.byType(Text)).evaluate()) {
          final w = text.widget as Text;
          if (find.descendant(of: shown, matching: find.descendant(of: find.byType(WorkoutActionPill), matching: find.byWidget(w))).evaluate().isNotEmpty) continue;
          expect(pill.overlaps(t.getRect(find.byWidget(w))), isFalse, reason: '$title: ${w.data}');
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}
