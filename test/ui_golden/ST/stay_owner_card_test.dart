import 'package:bakhli/features/stay/models/stay_owner_model.dart';
import 'package:bakhli/features/stay/setup/stay_owner_card.dart';
import 'package:bakhli/features/stay/setup/stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_support.dart';

StayOwnerModel _stay(String status, {bool accepting = true, int reports = 0, String? reason}) => StayOwnerModel.fromJson({
      'id': 's1',
      'status': status,
      'name': 'Riverside Heritage Homestay Near Naini Lake With Long Name',
      'cityName': 'Bhimtal',
      'districtName': 'Nainital',
      'acceptingGuests': accepting,
      'minPricePerNight': 2400,
      'pendingReportCount': reports,
      'rejectedReason': reason,
      'createdAt': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      'rooms': [
        {'id': 'r1', 'roomIndex': 1, 'pricePerNight': 2400, 'maxGuests': 2, 'roomName': 'Deluxe Valley View Room', 'meals': 'none'},
        {'id': 'r2', 'roomIndex': 2, 'pricePerNight': 3600, 'maxGuests': 4, 'roomName': '', 'meals': 'none'},
      ],
    });

Widget _card(StayOwnerModel s) => StayOwnerCard(
      stay: s,
      onAcceptingChanged: (_) {},
      onEditPrice: (_) {},
      onPreview: () {},
      onShare: () {},
      onDelete: () {},
      onReportsTap: () {},
      onOpenSetup: () {},
      onEnquiries: () {},
    );

Future<void> _pump(WidgetTester t, Widget child, double width, double scale) async {
  t.view.physicalSize = Size(width, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 1400), textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
    ),
  ));
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(loadGoldenFonts);

  final variants = <String, StayOwnerModel>{
    'live': _stay(StayStatus.approved),
    'paused': _stay(StayStatus.approved, accepting: false, reports: 2),
    'draft': _stay(StayStatus.draft),
    'review': _stay(StayStatus.pendingReview),
    'rejected': _stay(StayStatus.rejected, reason: 'Photos are blurry and the address does not match the map pin shown'),
  };

  for (final w in [300.0, 360.0, 412.0, 560.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final e in variants.entries) {
        testWidgets('owner card ${e.key} at ${w.toInt()}dp scale $scale', (t) async {
          await _pump(t, _card(e.value), w, scale);
          expect(t.takeException(), isNull);
          expect(find.text('View'), findsOneWidget);
        });
      }
    }
  }

  testWidgets('owner card keeps tap callbacks', (t) async {
    var viewed = 0, setup = 0, reports = 0;
    final s = _stay(StayStatus.rejected, reports: 1, reason: 'Bad photos');
    await _pump(
      t,
      StayOwnerCard(stay: s, onPreview: () => viewed++, onOpenSetup: () => setup++, onReportsTap: () => reports++),
      360,
      1.0,
    );
    await t.tap(find.text('View'));
    await t.tap(find.text('Fix and resubmit'));
    await t.tap(find.textContaining('report'));
    expect([viewed, setup, reports], [1, 1, 1]);
  });

  testWidgets('owner card golden', (t) async {
    setGoldenView(t, const Size(360, 1100));
    await t.pumpWidget(goldenHost(
      Column(children: [
        _card(variants['live']!),
        const SizedBox(height: 16),
        _card(variants['rejected']!),
      ]),
      scale: 1.0,
    ));
    await settleGolden(t);
    expect(t.takeException(), isNull);
    await expectLater(find.byKey(const ValueKey('golden_root')), matchesGoldenFile('goldens/stay_owner_card.png'));
  });

  testWidgets('confirm dialog stacks buttons at text scale 1.3 and returns taps', (t) async {
    var confirmed = false;
    await _pump(
      t,
      Builder(
        builder: (ctx) => TextButton(
          onPressed: () => showDialog(
            context: ctx,
            builder: (c) => StayConfirmDialog(
              title: 'Delete this stay?',
              body: 'This cannot be undone.',
              cancelLabel: 'Cancel',
              confirmLabel: 'Delete',
              destructive: true,
              onCancel: () => Navigator.pop(c),
              onConfirm: () => confirmed = true,
            ),
          ),
          child: const Text('open'),
        ),
      ),
      300,
      1.3,
    );
    await t.tap(find.text('open'));
    await t.pump(const Duration(milliseconds: 500));
    expect(t.takeException(), isNull);
    await t.tap(find.text('Delete'));
    expect(confirmed, isTrue);
  });
}
