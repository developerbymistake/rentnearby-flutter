import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/controllers/trip_shortlist_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_shortlist_model.dart';
import 'package:bakhli/features/trip/widgets/trip_send_result_sheet.dart';
import 'package:bakhli/features/trip/widgets/trip_shortlist_bar.dart';
import 'package:bakhli/features/trip/widgets/trip_shortlist_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const _widths = <double>[300, 360, 412, 560];
const _scales = <double>[1.0, 2.0];

Widget _host(double width, double scale, Widget child) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: SizedBox(width: width, child: child))),
      ),
    );

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(TripShortlistController(tripId: () async => 't', offline: () => false, warn: (_) {}));
  });

  tearDown(Get.reset);

  for (final w in _widths) {
    for (final s in _scales) {
      testWidgets('toggle and bar fit at $w dp, scale $s', (tester) async {
        final c = TripShortlistController.to;
        c.items.addAll(const [
          ShortlistItem(stepKey: 'stay:1', kind: 'Stay', listingId: 'a', name: 'A'),
          ShortlistItem(stepKey: 'stay:1', kind: 'Stay', listingId: 'b', name: 'B'),
        ]);
        await tester.pumpWidget(_host(
          w,
          s,
          Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: TripShortlistToggle(selected: false, onTap: () {})),
              const SizedBox(width: 8),
              Expanded(child: TripShortlistToggle(selected: true, onTap: () {}, tone: KitTone.taxi)),
            ]),
            TripShortlistBar(step: 'stay:1', onDone: () {}),
          ]),
        ));
        expect(tester.takeException(), isNull);
        expect(find.text('2 of 3 shortlisted'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      });
    }
  }

  testWidgets('toggle is disabled while busy', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(360, 1, TripShortlistToggle(selected: false, busy: true, onTap: () => taps++)));
    await tester.tap(find.byType(TripShortlistToggle));
    expect(taps, 0);
  });

  testWidgets('bar count follows the controller', (tester) async {
    final c = TripShortlistController.to;
    await tester.pumpWidget(_host(360, 1, TripShortlistBar(step: 'taxi', onDone: () {})));
    expect(find.text('0 of 3 shortlisted'), findsOneWidget);
    c.items.add(const ShortlistItem(stepKey: 'taxi', kind: 'Taxi', listingId: 'x', name: 'X'));
    await tester.pump();
    expect(find.text('1 of 3 shortlisted'), findsOneWidget);
  });

  for (final w in _widths) {
    testWidgets('result sheet shows every status at $w dp, scale 2.0', (tester) async {
      const results = [
        TripSendResult(listingId: '1', status: 'Sent'),
        TripSendResult(listingId: '2', status: 'AlreadyOpen'),
        TripSendResult(listingId: '3', status: 'Replayed'),
        TripSendResult(listingId: '4', status: 'NotAvailable'),
        TripSendResult(listingId: '5', status: 'Blocked'),
        TripSendResult(listingId: '6', status: 'LimitReached'),
        TripSendResult(listingId: '7', status: 'Failed'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(w, 1400), textScaler: const TextScaler.linear(2.0)),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => TripSendResultSheet.show(
                  context,
                  batch: const TripEnquiryBatch(items: [], skipped: [], veryShortNotice: false, results: results),
                  names: {for (var i = 1; i <= 7; i++) '$i': 'Host number $i'},
                  shortlist: true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Enquiry sent'), findsOneWidget);
      for (final label in ['Sent', 'Already sent earlier', 'Already sent', 'Not available', "Can't be reached", 'Limit reached', 'Try again']) {
        expect(find.text(label, skipOffstage: false), findsWidgets, reason: label);
      }
    });
  }
}
