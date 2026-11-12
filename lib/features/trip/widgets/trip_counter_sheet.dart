import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
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
import 'trip_payment_line.dart';
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
  static const _inputStyle = TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14, color: FitnessAppTheme.darkerText);

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
    return a == null || b == null ? null : TripFormat.dateRange(a, b);
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
    return TripSheetFrame(
      title: TripStrings.proposePrice,
      description: widget.enquiry.listingName.isEmpty ? null : widget.enquiry.listingName,
      footer: const TripPaymentLine(text: TripStrings.noPaymentLine),
      children: [
        TemplateStagger(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        if (listed != null && listed > 0) ...[
          _listedRow(listed),
          const SizedBox(height: 14),
        ],
        _label(TripStringsA5.perRoomPerNight),
        TextField(
          controller: _price,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(TripConstants.counterMax.toString().length),
          ],
          style: _inputStyle,
          onChanged: (_) => setState(() => _fieldError = null),
          decoration: _decoration(prefix: '₹ ', error: _fieldError),
        ),
        if (_totalLine() != null)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 6),
          Text(_totalLine()!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w600, color: RepliesTone.accent)),
          if (_basisDates != null)
            Text(_basisDates!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.deactivatedText)),
        ])
        else
          const SizedBox.shrink(),
        const SizedBox(height: 14),
        _label(TripStrings.note),
        TextField(
          controller: _note,
          enabled: !_busy,
          minLines: 2,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.noteMax)],
          style: _inputStyle,
          decoration: _decoration(),
        ),
        const SizedBox(height: 14),
        _info(TripStrings.counterInfo),
        const SizedBox(height: 16),
        TripButton(
          onPressed: _busy ? null : _send,
          label: TripStrings.sendMyPrice,
          loading: _busy,
          height: 52,
        ),
        if (_serverError != null) ...[
          const SizedBox(height: 8),
          Text(_serverError!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: RepliesTone.bad)),
        ],
          ],
        ),
      ],
    );
  }

  Widget _listedRow(int listed) => Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: FitnessAppTheme.background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Text(TripStrings.listedLabel,
              maxLines: 1, style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.deactivatedText)),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(BrowseItem.inr(listed),
                    style: const TextStyle(
                      fontFamily: FitnessAppTheme.fontName,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: FitnessAppTheme.deactivatedText,
                      decoration: TextDecoration.lineThrough,
                    )),
                const Text(TripStringsA5.perRoomNightShort,
                    style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.deactivatedText)),
              ],
            ),
          ),
        ]),
      );

  Widget _info(String text) => TripNote(
        iconAsset: TravelIcon.money,
        iconSize: 18,
        child: Text(text,
            style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.lightText, height: 1.4)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w600, color: FitnessAppTheme.lightText)),
      );

  InputDecoration _decoration({String? prefix, String? error}) => InputDecoration(
        prefixText: prefix,
        errorText: error,
        errorMaxLines: 2,
        filled: true,
        fillColor: FitnessAppTheme.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: RepliesTone.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: RepliesTone.bad)),
        focusedErrorBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: RepliesTone.bad, width: 1.5)),
      );
}
