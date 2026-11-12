import 'package:bakhli/design/design.dart';
import 'package:bakhli/screens/intro/intro_slide_a.dart';
import 'package:bakhli/screens/intro/intro_slide_b.dart';
import 'package:bakhli/screens/intro/intro_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

Widget _loginLike() => GateHeroLayout(
      heroHeight: 256,
      overlap: 48,
      hero: const GateHeroHeader(
        asset: TravelIcon.place,
        title: 'Bakhli',
        titleSize: 34,
        subtitle: 'Plan your next trip',
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: GateKit.heroCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome to Bakhli', style: FitnessAppTheme.headline.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text('Enter your mobile number to continue', style: FitnessAppTheme.caption),
            const SizedBox(height: 24),
            const TextField(decoration: InputDecoration(hintText: 'Mobile number')),
            const SizedBox(height: 20),
            GateButton(label: 'Send OTP', onPressed: () {}),
            const SizedBox(height: 12),
            GateOutlineButton(label: 'Edit', onPressed: () {}),
          ],
        ),
      ),
    );

void main() {
  setUpAll(loadGoldenFonts);

  for (final scale in [1.0, 1.3]) {
    testWidgets('login layout $scale', (t) async {
      setGoldenView(t);
      await t.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto'),
        home: MediaQuery(
          data: MediaQueryData(size: goldenSize, textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            backgroundColor: goldenBg,
            body: RepaintBoundary(
              key: const ValueKey('golden_root'),
              child: SingleChildScrollView(child: _loginLike()),
            ),
          ),
        ),
      ));
      await settleGolden(t);
      expect(t.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('golden_root')),
          matchesGoldenFile('goldens/login_layout_$scale.png'));
    });

    testWidgets('legal section $scale', (t) async {
      setGoldenView(t);
      await t.pumpWidget(goldenHost(
        const Column(children: [
          GateLegalHeading('Terms of Service'),
          GateLegalCaption('Last updated: November 6, 2026'),
          GateLegalSection(
            title: 'Plans and Subscriptions',
            body: 'Stay Owners and Taxi Drivers may choose a paid plan with the features shown in the app.',
            bullets: ['Paid plans are subscriptions bought through the app store.', 'A subscription renews automatically.'],
          ),
        ]),
        scale: scale,
      ));
      await settleGolden(t);
      expect(t.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('golden_root')),
          matchesGoldenFile('goldens/legal_section_$scale.png'));
    });

    testWidgets('intro scenes $scale', (t) async {
      setGoldenView(t);
      await t.pumpWidget(goldenHost(
        Column(children: [
          SizedBox(
            width: 280,
            height: 240,
            child: IntroSlidePick(isActive: true, progress: ValueNotifier<double>(0)),
          ),
          SizedBox(
            width: 280,
            height: 240,
            child: IntroSlidePlan(isActive: true, progress: ValueNotifier<double>(1)),
          ),
          SizedBox(
            width: 280,
            height: 240,
            child: IntroSlideStart(isActive: true, progress: ValueNotifier<double>(5)),
          ),
        ]),
        scale: scale,
      ));
      await settleGolden(t);
      expect(t.takeException(), isNull);
      await expectLater(find.byKey(const ValueKey('golden_root')),
          matchesGoldenFile('goldens/intro_scenes_$scale.png'));
    });
  }

  testWidgets('stage loop stops when inactive and respects reduce motion', (t) async {
    setGoldenView(t);
    late Animation<double> loop;
    Widget host(bool active, bool reduce) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: goldenSize, disableAnimations: reduce),
            child: IntroStage(
              isActive: active,
              builder: (context, enter) {
                loop = IntroStageScope.loopOf(context);
                return const SizedBox();
              },
            ),
          ),
        );
    await t.pumpWidget(host(true, false));
    await t.pump(const Duration(milliseconds: 900));
    expect(loop.value, greaterThan(0));
    await t.pumpWidget(host(false, false));
    final frozen = loop.value;
    await t.pump(const Duration(milliseconds: 900));
    expect(loop.value, frozen);
    await t.pumpWidget(host(true, true));
    await t.pump(const Duration(milliseconds: 900));
    expect(loop.value, 0);
  });
}
