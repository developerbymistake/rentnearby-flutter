import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/template_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

const _t3d = 'assets/images/design/travel3d/';

Widget _bar(int selected, {double inset = 24}) => TemplateBottomBar(
      bottomInset: inset,
      selectedIndex: selected,
      onTap: (_) {},
      items: [
        const TemplateNavItem(index: 0, label: 'Home', image: '${_t3d}compass.png'),
        TemplateNavItem(index: 1, label: 'Stays', image: ListingArt.stay, activeColor: ListingPalette.forest.text),
        const TemplateNavItem(index: 2, label: 'Trips', image: '${_t3d}luggage.png', center: true),
        TemplateNavItem(index: 3, label: 'Taxi', image: '${_t3d}taxi.png', activeColor: ListingPalette.coral.text),
        const TemplateNavItem(index: 4, label: 'Profile', image: '${_t3d}backpack.png'),
      ],
    );

Widget _page(ListingPalette p, List<Widget> body, {Widget? bottom, bool extend = false}) => Scaffold(
      backgroundColor: p.page,
      extendBody: extend,
      body: SafeArea(bottom: false, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body))),
      bottomNavigationBar: bottom,
    );

Widget _stays({bool long = false}) {
  final t = ListingTone.forest;
  return _page(
    ListingPalette.forest,
    [
      ModuleTitleBar(tone: t, art: ListingArt.hotel, title: long ? 'Stays and homestays' : 'Stays', subtitle: long ? 'Find the nearest stays around your current place' : 'Find stays near you'),
      SearchPill(tone: t, label: 'City', value: long ? 'Nainital > Bhowali Range Extension Colony' : 'Nainital > Nainital', leadingArt: ListingArt.roundPushpin, buttonArt: ListingArt.compass, onTap: () {}),
      ChipCPRow(children: [
        ChipCP(tone: ListingTone.cE, art: ListingArt.sunrise, label: 'All', onTap: () {}),
        ChipCP(tone: ListingTone.cA, art: ListingArt.bed, label: 'Homestay', off: true, onTap: () {}),
        ChipCP(tone: ListingTone.cB, art: ListingArt.hotel, label: 'Hotel', off: true, onTap: () {}),
      ]),
      TitleRow3D(
        title: long ? 'Stays nearest to Bhowali Range Extension' : 'Stays near you',
        tone: t,
        trailing: ListingFilterChip(tone: t, label: 'Filter', dot: long, onTap: () {}),
      ),
      DisclaimerBanner(text: long ? 'Fares are what drivers listed. The final fare is agreed with the driver on call.' : 'Fares are what drivers listed.'),
      TitleRow3D(title: 'Popular destinations', action: 'See all', subtitle: 'Plan a trip in a tap', onAction: () {}),
      WhiteCard3D(
        child: Column(children: [
          IconRow3D(art: ListingArt.key, title: 'Phone number', subtitle: long ? 'Verified and visible to hosts you contact' : null, onTap: () {}),
          IconRow3D(art: ListingArt.star, title: 'Show my number', divider: true, trailing: Switch(value: true, onChanged: (_) {})),
          IconRow3D(art: ListingArt.luggage, title: 'My Journeys', divider: true, onTap: () {}),
        ]),
      ),
      const SizedBox(height: 16),
      WhiteCard3D(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: IconRow3D(
          art: ListingArt.moneyBag,
          tile: 62,
          title: 'Plans & Billing',
          subtitle: 'Free plan',
          titleStyle: Ink3D.text(16, FontWeight.w700, Ink3D.title, letterSpacing: 0),
          trailing: ListingFilterChip(tone: ListingTone.indigo, label: 'Upgrade'),
        ),
      ),
      const SizedBox(height: 200),
    ],
    extend: true,
    bottom: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        _bar(1),
        Positioned(bottom: BarMetrics.boxHeightFor(24) + 14, child: MapPill3D(tone: t, label: 'Map', onTap: () {})),
      ],
    ),
  );
}

Widget _taxi({bool long = false}) {
  final t = ListingTone.coral;
  return _page(
    ListingPalette.coral,
    [
      TopBar3D(tone: t, title: long ? 'Kamalwaganja to Almora by taxi' : 'Getting there', subtitle: long ? 'Kamalwaganja to Almora, 14 Nov, 2 adults and 1 child' : 'Kamalwaganja to Almora', stepChip: 'Step 1 of 5', onBack: () {}),
      SearchPill(tone: t, label: 'From', value: 'Near you', leadingArt: ListingArt.roundPushpin, buttonArt: ListingArt.compass, margin: const EdgeInsets.fromLTRB(16, 20, 16, 0)),
      SearchPill(tone: t, label: 'To', value: 'Anywhere / search a place', hint: true, leadingArt: ListingArt.worldMap, buttonArt: ListingArt.compass, buttonChild: const Icon(Icons.close_rounded, color: Colors.white, size: 26)),
      ModuleTitleBar(tone: ListingTone.indigo, art: ListingArt.luggage, title: 'Trips', subtitle: 'Choose your', subtitleFirst: true),
      SearchPill(tone: ListingTone.indigo, value: 'Search a city', hint: true, inline: true, buttonArt: ListingArt.compass, margin: const EdgeInsets.fromLTRB(18, 0, 18, 0)),
      SearchPill(
        tone: ListingTone.indigo,
        value: '',
        inline: true,
        buttonArt: ListingArt.compass,
        field: TextField(
          decoration: InputDecoration.collapsed(hintText: 'Search a city', hintStyle: Ink3D.text(16, FontWeight.w400, Ink3D.hint, letterSpacing: 0)),
          style: Ink3D.text(16, FontWeight.w400, Ink3D.body, letterSpacing: 0),
        ),
      ),
      ChipCPRow(children: [
        ChipCP(tone: ListingTone.cB, art: ListingArt.luggage, label: 'My trips (2)'),
        ChipCP(tone: ListingTone.teal, art: ListingArt.worldMap, label: 'All'),
        ChipCP(tone: ListingTone.cA, art: ListingArt.mountain, label: 'Uttarakhand', off: true),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          RoundIconButton3D(asset: ListingArt.star, badge: RoundIconButton3D.count('2'), onTap: () {}),
          const SizedBox(width: 10),
          RoundIconButton3D(asset: ListingArt.speechBalloon, badge: RoundIconButton3D.count('99+'), onTap: () {}),
        ]),
      ),
    ],
    bottom: long
        ? DockLinks(tone: t, firstLabel: 'I will arrange it myself', onFirst: () {}, secondLabel: 'Skip this', onSecond: () {})
        : DockBar(tone: t, title: '2 of 3 shortlisted', subtitle: 'Tap Done to send your enquiry', actionLabel: 'Done', onAction: () {}),
  );
}

void main() {
  setUp(() {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\chrome';
  });

  for (final cfg in [(1.0, 360.0, false), (1.3, 360.0, true), (1.0, 300.0, true)]) {
    final tag = '${cfg.$1}_${cfg.$2.toInt()}';
    testWidgets('chrome stays $tag', (t) async {
      debugDisableShadows = false;
      await pumpPhone(t, _stays(long: cfg.$3), size: Size(cfg.$2, 1250), textScale: cfg.$1);
      await t.pump(const Duration(milliseconds: 1200));
      await settlePhone(t);
      await shot(t, 'stays_$tag');
      debugDisableShadows = true;
      expect(t.takeException(), isNull);
    });
    testWidgets('chrome taxi $tag', (t) async {
      debugDisableShadows = false;
      await pumpPhone(t, _taxi(long: cfg.$3), size: Size(cfg.$2, 900), textScale: cfg.$1);
      await settlePhone(t);
      await shot(t, 'taxi_$tag');
      debugDisableShadows = true;
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('dock bar loading, disabled and stacked', (t) async {
    debugDisableShadows = false;
    await pumpPhone(
      t,
      _page(ListingPalette.forest, [
        DockBar(tone: ListingTone.forest, title: '1 of 3 shortlisted', subtitle: 'Pick up to 3 stays', actionLabel: 'Done', loading: true, onAction: () {}),
        const SizedBox(height: 20),
        DockBar(tone: ListingTone.forest, title: '0 of 3 shortlisted', subtitle: 'Pick a stay first', actionLabel: 'Done'),
        const SizedBox(height: 20),
        DockBar(tone: ListingTone.forest, title: '3 of 3 shortlisted', subtitle: 'Your list is full'),
      ]),
      size: const Size(290, 700),
    );
    await settlePhone(t);
    await shot(t, 'dock_states_290');
    debugDisableShadows = true;
    expect(t.takeException(), isNull);
  });

  testWidgets('bottom bar trips selected', (t) async {
    debugDisableShadows = false;
    await pumpPhone(t, Scaffold(backgroundColor: ListingPalette.indigo.page, extendBody: true, body: const SizedBox.expand(), bottomNavigationBar: _bar(2)), size: const Size(360, 300));
    await t.pump(const Duration(milliseconds: 1200));
    await settlePhone(t);
    await shot(t, 'bar_trips');
    debugDisableShadows = true;
    final bar = t.getRect(find.byType(TemplateBottomBar));
    expect(bar.height, BarMetrics.boxHeightFor(24));
    expect(t.takeException(), isNull);
  });

  testWidgets('chrome callbacks fire', (t) async {
    final hits = <String>[];
    debugDisableShadows = false;
    await pumpPhone(
      t,
      _page(ListingPalette.coral, [
        TopBar3D(tone: ListingTone.coral, title: 'Taxi', onBack: () => hits.add('back')),
        SearchPill(tone: ListingTone.coral, value: 'Near you', buttonArt: ListingArt.compass, buttonKey: const ValueKey('go'), onTap: () => hits.add('field'), onButtonTap: () => hits.add('button')),
        ChipCPRow(children: [ChipCP(tone: ListingTone.cA, art: ListingArt.bed, label: 'Homestay', onTap: () => hits.add('chip'))]),
        Row(children: [ListingFilterChip(tone: ListingTone.coral, label: 'Filter', onTap: () => hits.add('filter')), MapPill3D(tone: ListingTone.coral, label: 'Map', onTap: () => hits.add('map'))]),
      ], bottom: DockBar(tone: ListingTone.coral, title: 'T', actionLabel: 'Done', actionKey: const ValueKey('done'), onAction: () => hits.add('done'))),
    );
    await t.tap(find.byTooltip('Back'));
    await t.tap(find.text('Near you'));
    await t.tap(find.byKey(const ValueKey('go')));
    await t.tap(find.text('Homestay'));
    await t.tap(find.text('Filter'));
    await t.tap(find.text('Map'));
    await t.tap(find.byKey(const ValueKey('done')));
    await t.pump(const Duration(milliseconds: 400));
    debugDisableShadows = true;
    expect(hits, ['back', 'field', 'button', 'chip', 'filter', 'map', 'done']);
  });
}
