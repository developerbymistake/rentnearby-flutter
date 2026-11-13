import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/services.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_offer_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
import '../utils/trip_format.dart';
import '../utils/trip_money.dart';
import 'trip_sheet_frame.dart';

class TripCounterSheet {
  static Future<bool> show(BuildContext context, {required TripEnquiryModel enquiry}) async {
    final ok = await TripSheetFrame.show<bool>(context, _CounterBody(enquiry: enquiry));
    return ok == true;
  }
}

class _CounterBody extends StatefulWidget {
  const _CounterBody({required this.enquiry});

  final TripEnquiryModel enquiry;

  @override
  State<_CounterBody> createState() => _CounterBodyState();
}

class _CounterBodyState extends State<_CounterBody> {
  final _price = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _fieldError;
  String? _serverError;

  int? get _listed {
    final e = widget.enquiry;
    return e.openOffer?.pricePerNight ?? e.pendingCounter?.listedPerNight;
  }

  // The server prices a counter on the host's open (or latest) offer: its rooms and its dates.
  TripOfferModel? get _basis => widget.enquiry.openOffer ?? widget.enquiry.pendingCounter;

  String? _totalLine() {
    final price = int.tryParse(_price.text.trim());
    if (price == null || price <= 0) return null;
    final basis = _basis;
    final lines = basis?.lines.where((l) => l.units > 0 && l.pricePerNight > 0).toList() ?? const <TripOfferLine>[];
    final nights = basis != null && basis.nights > 0 ? basis.nights : widget.enquiry.nights;
    if (lines.isEmpty) {
      final rooms = widget.enquiry.context.rooms ?? 1;
      final units = rooms < 1 ? 1 : rooms;
      return TripStringsA5.roomsNightsTotal(units, nights, BrowseItem.inr(price * units * nights));
    }
    final units = lines.fold<int>(0, (s, l) => s + l.units);
    final perNight = TripMoney.counterPerNight(
      price,
      [for (final l in lines) l.units],
      [for (final l in lines) l.pricePerNight],
    );
    return TripStringsA5.roomsNightsTotal(units, nights, BrowseItem.inr(perNight * nights));
  }

  String? get _basisDates {
    final a = _basis?.checkIn;
    final b = _basis?.checkOut;
    return a == null || b == null ? null : TripFormat.dayMonthRange(a, b);
  }

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final price = int.tryParse(_price.text.trim());
    if (price == null || price < TripConstants.counterMin || price > TripConstants.counterMax) {
      setState(() => _fieldError =
          TripStringsA5.errPriceRange(BrowseItem.inr(TripConstants.counterMin), BrowseItem.inr(TripConstants.counterMax)));
      return;
    }
    setState(() {
      _busy = true;
      _fieldError = null;
      _serverError = null;
    });
    final ctrl = TripEnquiryController.to;
    final offer = await ctrl.counter(widget.enquiry.id, pricePerNight: price, note: _note.text);
    if (!mounted) return;
    if (offer != null) {
      AppToast.success(TripStrings.priceSent);
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _serverError = ctrl.lastErrorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final listed = _listed;
    final tone = ListingTone.forest;
    final total = _totalLine();
    final cut = total?.lastIndexOf(' = ') ?? -1;
    final sub = [widget.enquiry.listingName, ?_basisDates].where((t) => t.isNotEmpty).join(' · ');
    return TripSheetFrame(
      tone: tone,
      art: ListingArt.moneyBag,
      title: TripStrings.proposePrice,
      description: sub.isEmpty ? null : sub,
      footnote: TripStrings.noPaymentLine,
      footer: GradientPillButton(tone: tone, label: TripStrings.sendMyPrice, loading: _busy, onTap: _busy ? null : _send),
      children: [
        if (listed != null && listed > 0) KeyValueRow(label: TripStrings.listedLabel, value: '${BrowseItem.inr(listed)} ${TripStringsA5.perRoomNightShort}'),
        PillField(
          tone: tone,
          controller: _price,
          enabled: !_busy,
          label: TripStringsA5.perRoomPerNight,
          firstLabel: listed == null || listed <= 0,
          leadingArt: ListingArt.moneyBag,
          prefixText: '₹ ',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(TripConstants.counterMax.toString().length),
          ],
          errorText: _fieldError,
          onChanged: (_) => setState(() => _fieldError = null),
        ),
        if (total != null)
          cut > 0
              ? SummaryBar3D(tone: tone, label: total.substring(0, cut), value: total.substring(cut + 3))
              : SummaryBar3D(tone: tone, label: total, value: ''),
        PillField(
          tone: tone,
          controller: _note,
          enabled: !_busy,
          label: TripStrings.note,
          firstLabel: false,
          leadingArt: ListingArt.speechBalloon,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.noteMax)],
        ),
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(TripStrings.counterInfo, style: RepliesLook.foot)),
        if (_serverError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_serverError!, maxLines: 3, overflow: TextOverflow.ellipsis, style: FieldMessage.errorStyle),
          ),
      ],
    );
  }
}
