import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import 'package:get/get.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_offer_model.dart';
import '../trip_strings.dart';
import '../utils/trip_format.dart';
import 'trip_payment_line.dart';
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
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: RepliesCard.radius),
        backgroundColor: FitnessAppTheme.white,
        title: Text(TripStrings.replaceNight(label, name), style: FitnessAppTheme.title),
        content: Text(TripStrings.replaceTold(name), style: FitnessAppTheme.body2.copyWith(height: 1.4)),
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextLink(label: TripStrings.keep, onTap: () => Navigator.pop(ctx, false), tone: KitTone.trip),
          TextLink(label: TripStrings.replace, onTap: () => Navigator.pop(ctx, true), tone: KitTone.trip),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final enq = widget.enquiry;
    final cin = offer.checkIn ?? enq.checkIn;
    final cout = offer.checkOut ?? enq.checkOut;
    final dates = cin == null || cout == null ? null : TripFormat.dateRange(cin, cout);
    final nights = offer.nights;
    final advance = offer.advanceAmount;
    if (_revised) {
      final old = offer.oldTotal ?? enq.agreedTotalLocked;
      return TripSheetFrame(
        title: TripStrings.acceptNewPriceQ,
        description: old == null ? null : TripStrings.acceptNewPriceBody(BrowseItem.inr(old), BrowseItem.inr(offer.total)),
        footer: const TripPaymentLine(),
        children: [
          TemplateStagger(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          _row(TripStrings.stay, enq.listingName),
          if (dates != null) _row(TripStrings.dates, nights > 0 ? '$dates · ${TripStrings.nights(nights)}' : dates),
          _row(TripStrings.total, BrowseItem.inr(offer.total), strong: true),
          if (advance != null && advance > 0) _row(TripStrings.advance, BrowseItem.inr(advance)),
          const SizedBox(height: 12),
          TripButton(
            onPressed: _busy ? null : _submit,
            label: TripStrings.acceptNewPrice,
            loading: _busy,
            height: 52,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: RepliesTone.bad)),
          ],
            ],
          ),
        ],
      );
    }
    final target = _target;
    return TripSheetFrame(
      title: target == null
          ? TripStrings.acceptQuestion
          : TripStrings.replaceFor(target.row.listingName, TripStrings.night(target.day)),
      description: target == null ? null : TripStrings.replaceTold(target.row.listingName),
      children: [
        TemplateStagger(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        _row(TripStrings.stay, enq.listingName),
        if (dates != null) _row(TripStrings.dates, nights > 0 ? '$dates · ${TripStrings.nights(nights)}' : dates),
        _row(TripStrings.total, BrowseItem.inr(offer.total), strong: true),
        if (advance != null && advance > 0) _row(TripStrings.advance, BrowseItem.inr(advance)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _busy ? null : () => setState(() => _tell = !_tell),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(_tell ? Icons.check_box : Icons.check_box_outline_blank,
                    color: _tell ? RepliesTone.accent : FitnessAppTheme.grey.withValues(alpha: Alpha.strong)),
              ),
              const Expanded(
                child: Text(TripStrings.tellOtherStays,
                    style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: FitnessAppTheme.darkerText, height: 1.35)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TripButton(
          onPressed: _busy ? null : _submit,
          label: TripStrings.acceptOffer,
          loading: _busy,
          height: 52,
        ),
          ],
        ),
      ],
      footer: const TripPaymentLine(),
    );
  }

  Widget _row(String k, String v, {bool strong = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: FitnessAppTheme.caption.copyWith(fontSize: 12.5)),
          const SizedBox(width: 12),
          Expanded(
            child: strong
                ? Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(v,
                          style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 20, fontWeight: FontWeight.w700, color: RepliesTone.accent)),
                    ),
                  )
                : Text(v,
                    textAlign: TextAlign.end,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: FitnessAppTheme.body2.copyWith(fontWeight: FontWeight.w600, color: FitnessAppTheme.darkerText)),
          ),
        ]),
      );
}
