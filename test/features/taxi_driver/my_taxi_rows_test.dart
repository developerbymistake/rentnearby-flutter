import 'package:bakhli/features/taxi/leads/trip_leads_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_ready_controller.dart';
import 'package:bakhli/features/taxi/requests/controllers/driver_requests_controller.dart';
import 'package:bakhli/features/taxi/requests/strings/driver_entry_strings.dart';
import 'package:bakhli/features/taxi/setup/my_taxi_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_controller.dart';
import 'package:bakhli/features/trip/trip_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/five_sizes.dart';
import 'driver_wiring_fakes.dart';

void _register({int newRequests = 2, int newLeads = 0}) {
  wireBase();
  Get.put<TaxiSetupController>(WireTaxi(wireTaxi()));
  Get.put<TripLeadsController>(WireLeads(news: newLeads));
  Get.put<DriverRequestsController>(WireRequests(news: newRequests));
  Get.put<DriverReadyController>(WireReady());
}

Future<void> _drainToasts(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 6));
}

Future<void> _scrollTo(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  tearDown(Get.reset);

  testWidgets('three_rows_and_badge', (t) async {
    _register(newRequests: 3);
    await pumpAtSize(t, const MyTaxiScreen(), const Size(360, 800));
    await t.pump(const Duration(seconds: 1));
    for (final title in [DriverEntryStrings.requests, DriverEntryStrings.bookings, DriverEntryStrings.rating]) {
      await _scrollTo(t, title);
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.text(TripStrings.newCount(3)), findsOneWidget);
    expect(find.text(DriverEntryStrings.requestsLine), findsOneWidget);
    expect(find.text(DriverEntryStrings.bookingsLine), findsOneWidget);
    expect(find.text(DriverEntryStrings.ratingLine), findsOneWidget);
    expect((Get.find<DriverRequestsController>() as WireRequests).reloads, greaterThan(0));

    Get.find<DriverRequestsController>().counts.value = null;
    await t.pump();
    expect(find.text(TripStrings.newCount(3)), findsNothing);
    await _drainToasts(t);
  });

  testWidgets('leads_row_stays_for_journey_leads', (t) async {
    _register(newRequests: 0, newLeads: 4);
    await pumpAtSize(t, const MyTaxiScreen(), const Size(360, 800));
    await t.pump(const Duration(seconds: 1));
    final leadsTitle = TripStrings.tripLeadsRow.split(' · ').first;
    await _scrollTo(t, leadsTitle);
    expect(find.text(leadsTitle), findsOneWidget);
    expect(find.text(TripStrings.newCount(4)), findsOneWidget);
    await _scrollTo(t, DriverEntryStrings.requests);
    expect(find.text(DriverEntryStrings.requests), findsOneWidget);
    await _drainToasts(t);
  });

  for (final size in fiveSizes) {
    testWidgets('my_taxi_rows_five_sizes at ${sizeLabel(size)}', (t) async {
      _register(newRequests: 12, newLeads: 3);
      await pumpAtSize(t, const MyTaxiScreen(), size);
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      for (final title in [DriverEntryStrings.requests, DriverEntryStrings.bookings, DriverEntryStrings.rating]) {
        await _scrollTo(t, title);
        expect(find.text(title), findsOneWidget, reason: '$title at ${sizeLabel(size)}');
        expect(t.takeException(), isNull, reason: '$title at ${sizeLabel(size)}');
      }
      expect(find.text(TripStrings.newCount(12)), findsOneWidget);
      await _drainToasts(t);
    });
  }
}
