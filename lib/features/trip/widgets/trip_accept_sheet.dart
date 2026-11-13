import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:get/get.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_offer_model.dart';
import '../trip_strings.dart';
import '../trip_strings_v2_easy.dart';
import '../utils/trip_format.dart';
import 'trip_sheet_frame.dart';

class TripReplaceTarget {
  final TripEnquiryModel row;
  final int day;

  const TripReplaceTarget(this.row, this.day);

  static TripReplaceTarget? find({
    required String? tripId,
    required DateTime? checkIn,
    required int nights,
    String? selfId,
    String? replaceEnquiryId,
  }) {
    if (tripId == null || checkIn == null || !Get.isRegistered<TripPlanController>()) return null;
    final c = Get.find<TripPlanController>();
    if (c.trip.value?.id != tripId) return null;
    final first = c.dayOfDate(checkIn);
    if (first == null) return null;
    TripReplaceTarget? any;
    for (var d = first; d < first + (nights < 1 ? 1 : nights); d++) {
      for (final e in c.enquiriesForNight(d)) {
        if (!e.isBooked || e.id == selfId) continue;
        if (e.id == replaceEnquiryId) return TripReplaceTarget(e, d);
        any ??= TripReplaceTarget(e, d);
      }
    }
    return any;
  }
}

class TripAcceptSheet extends StatefulWidget {
  const TripAcceptSheet._({required this.enquiry, required this.offer, this.replaceEnquiryId});

  final TripEnquiryModel enquiry;
  final TripOfferModel offer;
  final String? replaceEnquiryId;

  static Future<bool> show(
    BuildContext context, {
    required TripEnquiryModel enquiry,
    required TripOfferModel offer,
    String? replaceEnquiryId,
  }) async {
    final ok = await TripSheetFrame.show<bool>(
        context, TripAcceptSheet._(enquiry: enquiry, offer: offer, replaceEnquiryId: replaceEnquiryId));
    return ok == true;
  }

  @override
  State<TripAcceptSheet> createState() => _TripAcceptSheetState();
}

class _TripAcceptSheetState extends State<TripAcceptSheet> {
  bool _tell = true;
  bool _busy = false;
  String? _error;
  TripReplaceTarget? _target;

  @override
  void initState() {
    super.initState();
    if (!widget.offer.isRevised) {
      final offer = widget.offer;
      final enq = widget.enquiry;
      _target = TripReplaceTarget.find(
        tripId: enq.tripId,
        checkIn: offer.checkIn ?? enq.checkIn,
        nights: offer.nights > 0 ? offer.nights : enq.nights,
        selfId: enq.id,
        replaceEnquiryId: widget.replaceEnquiryId,
      );
    }
  }

  bool get _revised => widget.offer.isRevised;

  Future<void> _submitRevised() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ctrl = TripEnquiryController.to;
    final res = await ctrl.acceptRevised(widget.enquiry.id, widget.offer.id);
    if (!mounted) return;
    if (res != null) {
      AppToast.success(TripStrings.newPriceAccepted);
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = ctrl.lastErrorMessage;
    });
  }

  Future<void> _submit() async {
    if (_revised) return _submitRevised();
    if (_busy) return;
    setState(() => _busy = true);
    final ctrl = TripEnquiryController.to;
    String? replaceId = _target?.row.id;
    try {
      while (true) {
        final res = await ctrl.accept(
          widget.enquiry.id,
          widget.offer.id,
          closeOthers: _tell,
          replaceEnquiryId: replaceId,
        );
        if (res != null) {
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
        final conflict = ctrl.lastConflict;
        if (conflict != null && conflict.enquiryId != replaceId && mounted) {
          final replace = await _askReplace(conflict.listingName);
          if (replace != true) return;
          replaceId = conflict.enquiryId;
          continue;
        }
        final fresh = await ctrl.refreshOne(widget.enquiry.id);
        if (fresh != null && fresh.openOffer?.id != widget.offer.id && mounted) Navigator.of(context).pop(false);
        return;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _askReplace(String name) {
    final d = widget.enquiry.day;
    final label = d == null ? TripStrings.dates : TripStrings.night(d);
    final offer = widget.offer;
    return Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: _tone,
        art: ListingArt.bed,
        title: TripStrings.replaceNight(label, name),
        body: TripStrings.replaceTold(name),
        content: ReplySummaryStrip(
          tone: _tone,
          title: widget.enquiry.listingName,
          subtitle: label,
          value: BrowseItem.inr(offer.total),
          margin: EdgeInsets.zero,
        ),
        secondaryLabel: TripStrings.keep,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: TripStrings.replace,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
  }

  static final ListingTone _tone = ListingTone.forest;

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final enq = widget.enquiry;
    final cin = offer.checkIn ?? enq.checkIn;
    final cout = offer.checkOut ?? enq.checkOut;
    final dates = cin == null || cout == null ? null : TripFormat.dayMonthRange(cin, cout);
    final nights = offer.nights;
    final advance = offer.advanceAmount;
    final left = advance == null ? 0 : offer.total - advance;
    final rows = <Widget>[
      KeyValueRow(label: TripStrings.stay, value: enq.listingName),
      if (dates != null) KeyValueRow(label: TripStrings.dates, value: nights > 0 ? '$dates · ${TripStrings.nights(nights)}' : dates),
      KeyValueRow(label: TripStrings.total, value: BrowseItem.inr(offer.total), big: true),
      if (advance != null && advance > 0) KeyValueRow(label: TripStrings.advance, value: BrowseItem.inr(advance)),
      if (!_revised && advance != null && advance > 0 && left > 0) KeyValueRow(label: TripStringsV2Easy.balanceAtCheckIn, value: BrowseItem.inr(left)),
    ];
    if (_revised) {
      final old = offer.oldTotal ?? enq.agreedTotalLocked;
      return TripSheetFrame(
        tone: _tone,
        art: ListingArt.moneyBag,
        size: SheetSize.confirm,
        title: TripStrings.acceptNewPriceQ,
        description: old == null ? null : TripStrings.acceptNewPriceBody(BrowseItem.inr(old), BrowseItem.inr(offer.total)),
        footnote: TripStrings.stayPayLine,
        footer: GradientPillButton(tone: _tone, label: TripStrings.acceptNewPrice, loading: _busy, onTap: _busy ? null : _submit),
        children: [
          ...rows,
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, maxLines: 3, overflow: TextOverflow.ellipsis, style: FieldMessage.errorStyle),
            ),
        ],
      );
    }
    final target = _target;
    return TripSheetFrame(
      tone: _tone,
      art: ListingArt.key,
      size: SheetSize.confirm,
      title: target == null ? TripStrings.acceptQuestion : TripStrings.replaceFor(target.row.listingName, TripStrings.night(target.day)),
      description: target == null ? null : TripStrings.replaceTold(target.row.listingName),
      footnote: TripStrings.stayPayLine,
      footer: GradientPillButton(tone: _tone, label: TripStrings.acceptOffer, loading: _busy, onTap: _busy ? null : _submit),
      children: [
        ...rows,
        const SizedBox(height: 6),
        CheckRow(tone: _tone, value: _tell, label: TripStrings.tellOtherStays, onChanged: _busy ? null : (v) => setState(() => _tell = v)),
      ],
    );
  }
}
