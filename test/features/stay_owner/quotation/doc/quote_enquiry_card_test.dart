import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/features/stay/enquiries/stay_enquiries_controller.dart';
import 'package:bakhli/features/stay_owner/enquiries_tab/stay_enquiries_tab.dart';
import 'package:bakhli/features/stay_owner/quotation/model/quote_prefill.dart';
import 'package:bakhli/features/stay_owner/strings/stay_quote_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/owner_fakes.dart';
import '../../../../support/real_phone.dart';
import '../../work/stay_work_fixtures.dart';

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

class _FormProbe extends StatelessWidget {
  const _FormProbe();

  @override
  Widget build(BuildContext context) {
    final p = QuotePrefill.fromArgs(Get.arguments);
    return Scaffold(body: Text('form:${p?.enquiryId}:${p?.guestName}'));
  }
}

final _pages = [GetPage<dynamic>(name: AppRoutes.stayQuotationEdit, page: () => const _FormProbe())];

void main() {
  setUpAll(() => initTestStorage('quote_enquiry_card'));
  tearDown(tearDownWork);

  testWidgets('Q2 new card: Make quotation opens the form with the enquiry prefill', (t) async {
    setUpEnquiries({StayEnquiryBucket.newOnes: pageJson([enquiryJson(id: 'n1', name: 'Rohit Sharma')], newCount: 1)});
    await pumpPhone(t, const StayEnquiriesTab(), pages: _pages);
    await _settle(t);
    expect(find.text(StayQuoteStrings.makeQuotation), findsOneWidget);
    await t.ensureVisible(find.text(StayQuoteStrings.makeQuotation));
    await t.tap(find.text(StayQuoteStrings.makeQuotation));
    await _settle(t);
    expect(find.text('form:n1:Rohit Sharma'), findsOneWidget);
  });

  testWidgets('Q2 offered card: Make quotation button', (t) async {
    setUpEnquiries({
      StayEnquiryBucket.newOnes: pageJson(const [], newCount: 0, offered: 1),
      StayEnquiryBucket.offered: pageJson([
        enquiryJson(id: 'o1', name: 'Anjali Verma', status: 'Offered', display: 'offered', openOffer: offerJson(id: 'oo1', perNight: 4500)),
      ], offered: 1),
    });
    await pumpPhone(t, const StayEnquiriesTab(), pages: _pages);
    await _settle(t);
    await t.tap(find.text('Offered').first);
    await _settle(t);
    expect(find.text(StayQuoteStrings.makeQuotation), findsOneWidget);
  });
}
