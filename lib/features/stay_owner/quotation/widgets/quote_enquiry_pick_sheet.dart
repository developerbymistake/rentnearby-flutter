import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../stay/enquiries/stay_enquiries_controller.dart';
import '../../../stay/enquiries/stay_enquiry_format.dart';
import '../../../trip/models/trip_enquiry_model.dart';
import '../../enquiries_tab/stay_work_format.dart';
import '../../strings/stay_quote_strings.dart';
import '../../strings/stay_work_strings.dart';
import '../../widgets/stay_widgets.dart';
import '../model/quote_prefill.dart';
import 'quote_line_card.dart';

// "Choose an enquiry" (mock Q3 / Q4): the owner's New, Offered and Confirmed enquiries already loaded on this phone.
class QuoteEnquiryPickSheet extends StatelessWidget {
  const QuoteEnquiryPickSheet({super.key, required this.enquiries});

  final List<TripEnquiryModel> enquiries;

  static const Set<String> open = {
    TripEnquiryStatuses.asked,
    TripEnquiryStatuses.countered,
    TripEnquiryStatuses.offered,
    TripEnquiryStatuses.confirmedByBoth,
    TripEnquiryStatuses.confirmedByTraveller,
  };

  static List<TripEnquiryModel> loaded() {
    if (!Get.isRegistered<StayEnquiriesController>()) return const [];
    return Get.find<StayEnquiriesController>().items.where((e) => open.contains(e.status)).toList();
  }

  static Future<QuotePrefill?> pick(BuildContext context, {List<TripEnquiryModel>? enquiries}) =>
      SheetFrame.show<QuotePrefill>(context, builder: (_) => QuoteEnquiryPickSheet(enquiries: enquiries ?? loaded()));

  String _sub(TripEnquiryModel e) {
    final g = StayWorkFormat.guests(e);
    return [StayWorkFormat.dates(e), if (g > 0) StayWorkStrings.guests(g)].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      tone: ListingTone.forest,
      title: StayQuoteStrings.chooseEnquiry,
      child: enquiries.isEmpty
          ? Padding(padding: DS.sym(v: 16), child: Text(StayQuoteStrings.noEnquiries, style: QuoteText.body.copyWith(color: Ink3D.sub)))
          : StayRowsCard(
              margin: DS.insets(t: 10, b: 8),
              rows: [
                for (final e in enquiries)
                  StayRowData(
                    art: ListingArt.speechBalloon,
                    title: StayEnquiryFormat.guest(e),
                    sub: _sub(e),
                    semantics: StayEnquiryFormat.guest(e),
                    onTap: () => Navigator.of(context).pop(QuotePrefill.fromEnquiry(e)),
                  ),
              ],
            ),
    );
  }
}
