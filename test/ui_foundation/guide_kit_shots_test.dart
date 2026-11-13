import 'package:bakhli/design/extra/art_3d.dart';
import 'package:bakhli/design/extra/guide_kit_3d.dart';
import 'package:bakhli/design/tokens/listing_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

const _opts = ['Help me find', 'I will arrange it myself', 'Skip this'];

Widget _question(String which) {
  final (tone, art, step, title, body, pct, why) = switch (which) {
    'stayq' => (ListingTone.forest, ListingArt.hotel, 'Stay in Nainital \u00b7 Step 2 of 5', 'Where will you stay in Nainital?', 'Would you like to see stays in Nainital?', 0.2, 'Pick at least one and send your enquiry to continue'),
    'sent' => (ListingTone.coral, ListingArt.speechBalloon, 'Getting there \u00b7 Step 1 of 5', 'Enquiry sent', 'We told 3 drivers. You will see replies here.', 0.2, ''),
    'long' => (
        ListingTone.coral,
        ListingArt.bus,
        'To Kamalwaganja Malla Talla \u00b7 Step 4 of 5',
        'On to Kamalwaganja Malla Talla and beyond the hills',
        'Do you need a taxi from Nainital to Kamalwaganja Malla Talla for your whole group?',
        0.6,
        'Skip means we will not show taxis for this trip',
      ),
    _ => (ListingTone.indigo, ListingArt.taxi, 'Getting there \u00b7 Step 1 of 5', "Let's get you there", 'Would you like to see taxis from Kamalwaganja to Almora?', 0.0, 'Pick at least one and send your enquiry to continue'),
  };
  final tones = [ListingTone.cB, ListingTone.cA, ListingTone.cC];
  final arts = [ListingArt.compass, ListingArt.backpack, ListingArt.airplane];
  return Scaffold(
    body: GuideSheetScaffold(
      tone: tone,
      art: art,
      stepLabel: step,
      title: title,
      body: body,
      progress: pct,
      bottom: GuideButtons(tone: tone, primaryLabel: which == 'sent' ? 'Next' : 'Find stays', enabled: which == 'sent', onPrimary: () {}, onSquare: () {}, why: why),
      children: [
        if (which != 'sent')
          for (var i = 0; i < 3; i++)
            OptionCard(
              tone: tones[i],
              art: arts[i],
              label: which == 'long' && i == 1 ? 'I will arrange it myself with my own driver and car' : _opts[i],
              state: which == 'guide' ? OptionState.idle : (i == 0 ? OptionState.on : OptionState.off),
              onTap: () {},
            ),
      ],
    ),
  );
}

Widget _modal({bool long = false}) {
  return Scaffold(
    backgroundColor: const Color(0xFFFFE3DA),
    body: SheetModal(
      tone: ListingTone.coral,
      art: ListingArt.taxi,
      title: long ? 'Great picks for your long trip' : 'Great picks',
      body: 'Send an enquiry to all your shortlisted taxis together?',
      names: [
        const SheetNameChip(art: ListingArt.taxi, label: 'Pradeep'),
        const SheetNameChip(art: ListingArt.taxi, label: 'Rakesh'),
        SheetNameChip(art: ListingArt.bus, label: long ? 'Mohan Singh Rawat Bisht' : 'Mohan'),
      ],
      primaryLabel: 'Send to all',
      onPrimary: () {},
      secondaryLabel: 'Change my picks',
      onSecondary: () {},
      linkLabel: 'Not now',
      onLink: () {},
    ),
  );
}

Widget _ways() {
  return Scaffold(
    backgroundColor: const Color(0xFFFFE3DA),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WayCard(
              tone: ListingTone.coral,
              art: ListingArt.taxi,
              bestLabel: 'BEST WAY',
              title: 'Plan A',
              subtitle: '2 cars \u00b7 1 change \u00b7 about \u20b92,300',
              rows: const [
                WayRow.stop('Haldwani', filled: false),
                WayRow.drive('Rakesh +2 more', right: '\u20b9900'),
                WayRow.stop('Bhowali', tag: 'change car'),
                WayRow.drive('Pradeep +1 more', right: '\u20b91,400'),
                WayRow.stop('Almora'),
              ],
              buttons: [
                WayButton(label: 'Call Rakesh', onTap: () {}),
                WayButton(label: 'Call Pradeep', onTap: () {}),
                WayButton(label: 'Ask both drivers', primary: true, onTap: () {}),
                WayButton(label: 'Save plan', onTap: () {}),
              ],
              note: 'Saving does not contact anyone. Asking sends an enquiry to each car.',
            ),
            WayCard(tone: ListingTone.cB, art: ListingArt.bus, title: 'Plan B', subtitle: '3 cars \u00b7 about \u20b92,750', buttons: [WayButton(label: 'Open journey', full: true, onTap: () {})]),
            WayCard(
              tone: ListingTone.cC,
              art: ListingArt.taxi,
              bestLabel: 'BEST WAY',
              bestReason: 'Fewest changes and the lowest fare',
              title: 'Plan C with a very long plan name here',
              subtitle: '2 cars \u00b7 about \u20b93,100',
              rows: const [
                WayRow.stop('Kamalwaganja Malla Talla Bazaar', filled: false),
                WayRow.drive('Rakesh Singh Bisht Rawat +2 more', right: '\u20b912,900', note: 'Fits 7 of your 9 people'),
                WayRow.stop('Almora Mall Road Bus Stand', tag: 'change car'),
              ],
              buttons: [
                WayButton(label: 'Call Rakesh', onTap: () {}),
                WayButton(label: 'Ask this driver', primary: true, busy: true, onTap: () {}),
                WayButton(label: 'Save plan', onTap: () {}),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

const _cfgs = [(1.0, Size(390, 844)), (1.0, Size(360, 800)), (1.3, Size(360, 800)), (1.0, Size(300, 640))];

Future<void> _lit(Future<void> Function() body) async {
  debugDisableShadows = false;
  try {
    await body();
  } finally {
    debugDisableShadows = true;
  }
}

void main() {
  setUp(() {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\guide_kit';
  });

  for (final cfg in _cfgs) {
    final tag = '${cfg.$1}_${cfg.$2.width.toInt()}';
    testWidgets('question sheets share one position $tag', (t) => _lit(() async {
      Rect? buttons;
      for (final s in ['guide', 'stayq', 'sent', 'long']) {
        await pumpPhone(t, _question(s), size: cfg.$2, textScale: cfg.$1);
        await settlePhone(t);
        await shot(t, '${s}_$tag');
        expect(t.takeException(), isNull, reason: s);
        final r = t.getRect(find.byType(GuideButtons));
        buttons ??= r;
        expect(r, buttons, reason: s);
        final view = t.getRect(find.byType(GuideSheetScaffold));
        expect(r.bottom, lessThanOrEqualTo(view.bottom));
      }
    }));
    testWidgets('modal $tag', (t) => _lit(() async {
      await pumpPhone(t, _modal(), size: cfg.$2, textScale: cfg.$1);
      await settlePhone(t);
      await shot(t, 'modal_$tag');
      expect(t.takeException(), isNull);
      await pumpPhone(t, _modal(long: true), size: cfg.$2, textScale: cfg.$1);
      await settlePhone(t);
      await shot(t, 'modal_long_$tag');
      expect(t.takeException(), isNull);
    }));
    testWidgets('ways $tag', (t) => _lit(() async {
      await pumpPhone(t, _ways(), size: Size(cfg.$2.width, 1500), textScale: cfg.$1);
      await settlePhone(t);
      await shot(t, 'ways_$tag');
      expect(t.takeException(), isNull);
      final a = t.getSize(find.text('Call Rakesh').first.evaluate().isEmpty ? find.byType(WayCard).first : find.bySemanticsLabel('Call Rakesh').first);
      final b = t.getSize(find.bySemanticsLabel('Save plan').first);
      expect(a.height, b.height);
    }));
  }

  testWidgets('SheetModal.show returns the pop value and closes on scrim tap', (t) async {
    Object? got = 'unset';
    await pumpPhone(
      t,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                got = await SheetModal.show<bool>(
                  context,
                  builder: (c) => SheetModal(
                    tone: ListingTone.coral,
                    art: ListingArt.taxi,
                    title: 'Great picks',
                    primaryLabel: 'Send to all',
                    primaryKey: const ValueKey('send'),
                    onPrimary: () => Navigator.of(c).pop(true),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('send')));
    await t.pumpAndSettle();
    expect(got, true);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(20, 60));
    await t.pumpAndSettle();
    expect(got, isNull);
    expect(find.byType(SheetModal), findsNothing);
  });

  testWidgets('guide buttons: disabled and loading primary do not fire, square keeps its label', (t) async {
    var taps = 0;
    var back = 0;
    Widget build({bool enabled = true, bool loading = false}) => Scaffold(
          body: Center(child: GuideButtons(tone: ListingTone.forest, primaryLabel: 'Next', enabled: enabled, loading: loading, onPrimary: () => taps++, onSquare: () => back++)),
        );
    await pumpPhone(t, build());
    await t.tap(find.bySemanticsLabel('Next'));
    await t.tap(find.byTooltip('Previous'));
    expect((taps, back), (1, 1));
    await pumpPhone(t, build(enabled: false));
    await t.tap(find.bySemanticsLabel('Next'));
    expect(taps, 1);
    await pumpPhone(t, build(loading: true));
    await t.tap(find.bySemanticsLabel('Next'), warnIfMissed: false);
    expect(taps, 1);
    expect(find.bySemanticsLabel('Previous'), findsOneWidget);
  });
}
