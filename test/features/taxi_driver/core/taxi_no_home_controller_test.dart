import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi_driver/calendar/taxi_upcoming_card.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_attention_screen.dart';
import 'package:bakhli/features/taxi_driver/home/taxi_driver_home_controller.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_home_strings.dart';
import 'package:bakhli/features/taxi_driver/widgets/taxi_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';

void main() {
  setUpAll(() => initTestStorage('taxi_no_home_controller'));
  useOwnerRenderScale();
  tearDown(resetOwnerTestState);

  testWidgets('attention screen without a home controller shows the plain header', (tester) async {
    expect(Get.isRegistered<TaxiDriverHomeController>(), isFalse);
    await tester.pumpWidget(const MaterialApp(home: TaxiAttentionScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(TaxiHomeStrings.attentionPageTitle), findsOneWidget);
    expect(tester.widget<TaxiPageHeader>(find.byType(TaxiPageHeader)).subtitle, isNull);
  });

  testWidgets('upcoming card without a home controller shows the loading view', (tester) async {
    expect(Get.isRegistered<TaxiDriverHomeController>(), isFalse);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TaxiUpcomingCard()))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(TaxiUpcomingCardView), findsOneWidget);
    expect(find.byType(SkeletonBox), findsNWidgets(3));
  });
}
