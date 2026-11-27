import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../stay/enquiries/stay_enquiries_controller.dart';
import '../../../stay/enquiries/stay_enquiry_format.dart';
import '../../../trip/data/trip_enquiry_repository.dart';
import '../../../trip/models/trip_enquiry_model.dart';
import '../../enquiries_tab/stay_work_format.dart';
import '../../strings/stay_quote_strings.dart';
import '../../strings/stay_work_strings.dart';
import '../../widgets/stay_widgets.dart';
import '../model/quote_prefill.dart';
import 'quote_line_card.dart';

typedef QuoteEnquiryLoader = Future<List<TripEnquiryModel>> Function(String bucket);

// "Choose an enquiry" (mock Q3 / Q4): the first page of the owner's New, Offered and Confirmed enquiries, read
// through the existing owner list; the Enquiries tab's own list and bucket are never touched.
class QuoteEnquiryPickSheet extends StatefulWidget {
  const QuoteEnquiryPickSheet({super.key, this.enquiries, this.loader});

  final List<TripEnquiryModel>? enquiries;
  final QuoteEnquiryLoader? loader;

  static const Set<String> open = {
    TripEnquiryStatuses.asked,
    TripEnquiryStatuses.countered,
    TripEnquiryStatuses.offered,
    TripEnquiryStatuses.confirmedByBoth,
    TripEnquiryStatuses.confirmedByTraveller,
  };

  static const List<String> buckets = [StayEnquiryBucket.newOnes, StayEnquiryBucket.offered, StayEnquiryBucket.confirmed];

  static Future<List<TripEnquiryModel>> ownerPage(String bucket) async {
    final fetch = StayEnquiriesController.debugFetch;
    if (fetch == null) return (await const TripEnquiryRepository().ownerList(status: bucket, pageSize: StayEnquiriesController.pageSize)).items;
    final res = await fetch(bucket, 1, StayEnquiriesController.pageSize);
    final data = res['data'];
    return TripOwnerEnquiryPage.fromJson(data is Map<String, dynamic> ? data : const {}).items;
  }

  // Pages merged in bucket order, one row per enquiry, only enquiries still open (a confirmed stay that ended is closed).
  static Future<List<TripEnquiryModel>> loadOpen({QuoteEnquiryLoader? loader}) async {
    final load = loader ?? ownerPage;
    final pages = await Future.wait([
      for (final b in buckets) load(b).catchError((_) => const <TripEnquiryModel>[]),
    ]);
    final seen = <String>{};
    return [
      for (final page in pages)
        for (final e in page)
          if (open.contains(e.status) && StayEnquiryBucket.of(e) != StayEnquiryBucket.closed && seen.add(e.id)) e,
    ];
  }

  static Future<QuotePrefill?> pick(BuildContext context, {List<TripEnquiryModel>? enquiries, QuoteEnquiryLoader? loader}) =>
      SheetFrame.show<QuotePrefill>(context, builder: (_) => QuoteEnquiryPickSheet(enquiries: enquiries, loader: loader));

  @override
  State<QuoteEnquiryPickSheet> createState() => _QuoteEnquiryPickSheetState();
}

class _QuoteEnquiryPickSheetState extends State<QuoteEnquiryPickSheet> {
  List<TripEnquiryModel>? _items;

  @override
  void initState() {
    super.initState();
    _items = widget.enquiries;
    if (_items == null) _load();
  }

  Future<void> _load() async {
    final items = await QuoteEnquiryPickSheet.loadOpen(loader: widget.loader);
    if (mounted) setState(() => _items = items);
  }

  String _sub(TripEnquiryModel e) {
    final g = StayWorkFormat.guests(e);
    return [StayWorkFormat.dates(e), if (g > 0) StayWorkStrings.guests(g)].join(' · ');
  }

  Widget _body() {
    final items = _items;
    if (items == null) {
      return Padding(
        padding: DS.insets(t: 10, b: 8),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [SkeletonListRow(twoLines: true), SkeletonListRow(twoLines: true), SkeletonListRow(twoLines: true)]),
      );
    }
    if (items.isEmpty) return Padding(padding: DS.sym(v: 16), child: Text(StayQuoteStrings.noEnquiries, style: QuoteText.body.copyWith(color: Ink3D.sub)));
    return StayRowsCard(
      margin: DS.insets(t: 10, b: 8),
      rows: [
        for (final e in items)
          StayRowData(
            art: ListingArt.speechBalloon,
            title: StayEnquiryFormat.guest(e),
            sub: _sub(e),
            semantics: StayEnquiryFormat.guest(e),
            onTap: () => Navigator.of(context).pop(QuotePrefill.fromEnquiry(e)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SheetFrame(tone: ListingTone.forest, title: StayQuoteStrings.chooseEnquiry, child: _body());
}
