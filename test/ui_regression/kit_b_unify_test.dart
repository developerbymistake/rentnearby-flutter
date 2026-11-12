import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/jobs_kit.dart';
import 'package:bakhli/design/extra/kit_tone.dart';
import 'package:bakhli/design/extra/stay_setup_kit.dart';
import 'package:bakhli/design/extra/taxi_kit.dart';
import 'package:bakhli/design/extra/taxi_setup_kit.dart';
import 'package:bakhli/design/extra/ways_kit.dart';

Future<void> _pump(WidgetTester t, double w, double scale, Widget child) async {
  await t.binding.setSurfaceSize(Size(w, 800));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(w, 800), textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ));
  await t.pump(const Duration(seconds: 1));
}

void main() {
  for (final w in [300.0, 360.0, 560.0]) {
    for (final s in [1.0, 1.3]) {
      testWidgets('kit B widgets no overflow @$w x$s', (t) async {
        var taps = 0;
        await _pump(
          t,
          w,
          s,
          Column(children: [
            SetupCard(title: 'Title', child: Text('Body', style: SetupKit.fieldText())),
            SetupFooter(child: SetupOutlineButton(label: 'Back', onPressed: () => taps++)),
            const WaysBanner(icon: Icons.info_outline, text: 'A fairly long warning line to wrap around'),
            Row(children: [
              Expanded(child: JourneyButton(label: 'Open journey now', maxLines: 2, kind: JourneyButtonKind.outline, onPressed: () => taps++)),
              const SizedBox(width: 8),
              Expanded(child: JourneyButton(label: 'Ask drivers', onPressed: () => taps++)),
            ]),
            JourneyButton(label: 'Busy', busy: true, onPressed: () {}),
            JourneyButton(label: 'Off', onPressed: null),
            Row(children: [
              WaysOutlineButton(label: 'Outline', onPressed: () => taps++),
              const SizedBox(width: 8),
              WaysFilledButton(label: 'Filled', onPressed: () => taps++),
            ]),
            const JourneyPill(text: 'Pill text', fg: DesignColors.textStrong, bg: DesignColors.surface),
            const TaxiStepDot(index: 0, step: 0, label: 'Step'),
            SetupPill(label: 'Confirm', onTap: () => taps++),
            TaxiPill(label: 'Confirm', onTap: () => taps++, destructive: true),
            const JobsTag('Tag'),
            JobsDropdownChip(label: 'Dropdown', selected: true, onTap: () => taps++),
            const SizedBox(height: 300, child: TaxiEmpty(asset: SetupAssets.pin, title: 'Empty', subtitle: 'Sub')),
          ]),
        );
        expect(t.takeException(), isNull);
        await t.tap(find.text('Ask drivers'));
        expect(taps, 1);
      });
    }
  }

  testWidgets('dialog frame returns values and fits 300', (t) async {
    await t.binding.setSurfaceSize(const Size(300, 600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    bool? res;
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(300, 600), textScaler: TextScaler.linear(1.3)),
        child: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async => res = await showTaxiDialog(c,
                  title: 'Delete this route', body: 'This cannot be undone.', cancelLabel: 'Cancel', confirmLabel: 'Delete', destructive: true),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    await t.tap(find.text('Delete'));
    await t.pump(const Duration(seconds: 1));
    expect(res, true);
  });

  testWidgets('SetupKit.sheet shows bare content on an opaque sheet and JobsKit option sheet pops index', (t) async {
    int? picked;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: Column(children: [
            TextButton(
              onPressed: () => SetupKit.sheet<void>(c, builder: (_) => const SizedBox(height: 80, child: Text('bare'))),
              child: const Text('sheet'),
            ),
            TextButton(
              onPressed: () async => picked = await JobsKit.pickOption(c, title: 'Pick', labels: const ['A', 'B', 'C'], selectedIndex: 0),
              child: const Text('opt'),
            ),
          ]),
        ),
      ),
    ));
    await t.tap(find.text('sheet'));
    await t.pumpAndSettle();
    expect(find.text('bare'), findsOneWidget);
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    await t.tap(find.text('opt'));
    await t.pumpAndSettle();
    await t.tap(find.text('B'));
    await t.pumpAndSettle();
    expect(picked, 1);
    expect(KitTone.jobs.accent, isNotNull);
  });
}
