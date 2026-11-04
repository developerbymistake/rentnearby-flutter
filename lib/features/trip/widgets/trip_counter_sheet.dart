import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a5.dart';
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
  static const _inputStyle = TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark);

  final _price = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _fieldError;
  String? _serverError;

  int? get _listed {
    final e = widget.enquiry;
    return e.openOffer?.pricePerNight ?? e.pendingCounter?.listedPerNight;
  }

  String? _totalLine() {
    final price = int.tryParse(_price.text.trim());
    if (price == null || price <= 0) return null;
    final rooms = widget.enquiry.context.rooms ?? 1;
    final nights = widget.enquiry.nights;
    return TripStringsA5.roomsNightsTotal(rooms, nights, BrowseItem.inr(price * rooms * nights));
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
        if (_totalLine() != null) ...[
          const SizedBox(height: 6),
          Text(_totalLine()!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: TripColors.accentDark)),
        ],
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
        GradientButton(
          onPressed: _busy ? null : _send,
          label: TripStrings.sendMyPrice,
          isLoading: _busy,
          height: 52,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
        ),
        if (_serverError != null) ...[
          const SizedBox(height: 8),
          Text(_serverError!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
        ],
      ],
    );
  }

  Widget _listedRow(int listed) => Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.neutralChip,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(children: [
          const Text(TripStrings.listedLabel,
              maxLines: 1, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(BrowseItem.inr(listed),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                      decoration: TextDecoration.lineThrough,
                    )),
                const Text(TripStringsA5.perRoomNightShort,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ),
        ]),
      );

  Widget _info(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Iconsax.info_circle, size: 16, color: TripColors.accentDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium, height: 1.4)),
          ),
        ]),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
      );

  InputDecoration _decoration({String? prefix, String? error}) => InputDecoration(
        prefixText: prefix,
        errorText: error,
        errorMaxLines: 2,
        filled: true,
        fillColor: AppColors.scaffoldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TripColors.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
      );
}
