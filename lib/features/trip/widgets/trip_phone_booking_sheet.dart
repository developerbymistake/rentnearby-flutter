import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/selectable_chip.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a3.dart';
import '../utils/trip_format.dart';
import 'trip_accept_sheet.dart';
import 'trip_payment_line.dart';
import 'trip_sheet_frame.dart';

class _Copy {
  static const String hostName = 'Host name';
  static const String hostPhone = 'Host phone';
  static const String roomName = 'Room name';
  static const String errHostPhone = 'Enter a 10 digit phone or leave it empty';
  static const String optional = ' (optional)';
  static const String errAdvance = 'Advance must be more than ₹0 and at most the price';
  static const String linkTitle = 'Send the link to the host';
  static const String linkDescription = 'Opens WhatsApp with the message and link.';
}

class TripPhoneBookingSheet {
  static Future<TripPhoneBookingResult?> show(
    BuildContext context, {
    required String stayId,
    required String stayName,
    String? hostName,
    String? hostPhone,
    required int day,
    List<String> rooms = const [],
    TripEnquiryModel? existing,
    String? replaceEnquiryId,
  }) {
    return TripSheetFrame.show<TripPhoneBookingResult>(
      context,
      _PhoneBookingBody(
        stayId: stayId,
        stayName: stayName,
        hostName: hostName,
        hostPhone: hostPhone,
        day: day,
        rooms: rooms,
        existing: existing,
        replaceEnquiryId: replaceEnquiryId,
      ),
    );
  }
}

class TripConfirmLinkSheet {
  static Future<void> show(BuildContext context, TripPhoneBookingResult result) =>
      TripSheetFrame.show<void>(context, _LinkBody(result: result));
}

class _PhoneBookingBody extends StatefulWidget {
  final String stayId;
  final String stayName;
  final String? hostName;
  final String? hostPhone;
  final int day;
  final List<String> rooms;
  final TripEnquiryModel? existing;
  final String? replaceEnquiryId;

  const _PhoneBookingBody({
    required this.stayId,
    required this.stayName,
    this.hostName,
    this.hostPhone,
    required this.day,
    required this.rooms,
    this.existing,
    this.replaceEnquiryId,
  });

  @override
  State<_PhoneBookingBody> createState() => _PhoneBookingBodyState();
}

class _PhoneBookingBodyState extends State<_PhoneBookingBody> {
  static const _inputStyle = TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark);
  static final _phoneRule = RegExp(r'^[6-9]\d{9}$');

  late final TripPlanController _plan;
  late final TextEditingController _hostName;
  late final TextEditingController _hostPhone;
  late final TextEditingController _otherRoom;
  late final TextEditingController _price;
  late final TextEditingController _advance;
  late final TextEditingController _note;
  late int _day;
  bool _allNights = false;
  bool _advancePaid = false;
  String? _room;
  bool _otherSelected = false;
  bool _saving = false;

  TripEnquiryModel? get _existing => widget.existing;

  bool get _edit => _existing != null;

  bool get _hasRoomChips => widget.rooms.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _plan = TripPlanController.to;
    final ex = _existing;
    final pb = ex?.phoneBooking;
    _day = ex == null ? widget.day : (_plan.dayOfDate(ex.checkIn) ?? ex.day ?? widget.day);
    _allNights = ex != null && ex.nights > 1;
    _hostName = TextEditingController(text: pb?.hostName ?? widget.hostName ?? '');
    _hostPhone = TextEditingController(text: _phoneText(pb?.hostPhone ?? widget.hostPhone));
    _price = TextEditingController(text: pb == null || pb.agreedTotal <= 0 ? '' : '${pb.agreedTotal}');
    _advancePaid = pb?.advancePaid ?? false;
    _advance = TextEditingController(text: pb?.advanceAmount == null ? '' : '${pb!.advanceAmount}');
    _note = TextEditingController(text: pb?.note ?? '');
    final room = pb?.roomName ?? '';
    final known = widget.rooms.contains(room);
    _room = known ? room : null;
    _otherSelected = room.isNotEmpty && !known;
    _otherRoom = TextEditingController(text: _otherSelected ? room : '');
  }

  @override
  void dispose() {
    _hostName.dispose();
    _hostPhone.dispose();
    _otherRoom.dispose();
    _price.dispose();
    _advance.dispose();
    _note.dispose();
    super.dispose();
  }

  String _phoneText(String? raw) {
    if (raw == null || raw.contains(RegExp(r'[xX*]'))) return '';
    final digits = ContactLauncher.tenDigits(raw);
    return digits.length == 10 ? digits : '';
  }

  int get _runNights => _plan.enquiryNightsRun(_day, ignoreEnquiryId: _existing?.id).length;

  bool get _canPickAllNights => _runNights > 1 || (_existing?.nights ?? 0) > 1;

  int get _nights {
    final ex = _existing;
    if (ex != null && (_allNights == (ex.nights > 1) || _plan.dayCount < 1)) return ex.nights;
    final run = _runNights;
    return _allNights && run > 1 ? run : 1;
  }

  DateTime? get _checkIn => _existing?.checkIn ?? _plan.dateOf(_day);

  String _datesText() {
    final a = _checkIn;
    if (a == null) return TripStrings.dayN(_day);
    final b = DateTime(a.year, a.month, a.day + _nights);
    return '${TripFormat.dateRange(a, b)} · ${TripStrings.nights(_nights)}';
  }

  String get _roomValue => _otherSelected || !_hasRoomChips ? _otherRoom.text.trim() : (_room ?? '');

  Map<String, dynamic>? _validate() {
    final host = _hostName.text.trim();
    final phone = _hostPhone.text.trim();
    if (phone.isNotEmpty && !_phoneRule.hasMatch(phone)) return _warn(_Copy.errHostPhone);
    final room = _roomValue;
    final priceText = _price.text.trim();
    var price = 0;
    if (priceText.isNotEmpty) {
      price = int.tryParse(priceText) ?? 0;
      if (price < 1 || price > TripConstants.maxAmount) return _warn(TripStringsA3.errPriceRange(TripConstants.maxAmount));
    }
    int? advance;
    if (_advancePaid) {
      advance = int.tryParse(_advance.text.trim());
      if (advance == null || advance < 1 || (price > 0 && advance > price)) return _warn(_Copy.errAdvance);
    }
    final note = _note.text.trim();
    return {
      'hostName': host.isEmpty ? null : host,
      'hostPhone': phone.isEmpty ? null : phone,
      'roomName': room.isEmpty ? null : room,
      'agreedTotal': price,
      'advancePaid': _advancePaid,
      'advanceAmount': advance,
      'note': note.isEmpty ? null : note,
    };
  }

  Map<String, dynamic>? _warn(String message) {
    AppToast.warning(message);
    return null;
  }

  Future<bool> _confirmReplace(String name, {String? title}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title ?? TripStrings.replaceNight(TripStrings.night(_day), name),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        content: Text(TripStrings.replaceTold(name),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStrings.keep, style: TextStyle(fontFamily: 'Poppins', color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            child: const Text(TripStrings.replace,
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: TripColors.accentDark)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final fields = _validate();
    if (fields == null) return;
    setState(() => _saving = true);
    final ctrl = TripEnquiryController.to;
    TripPhoneBookingResult? result;
    final ex = _existing;
    if (ex != null) {
      final keep = _allNights == (ex.nights > 1);
      result = await ctrl.editPhoneBooking(ex.id, {
        if (!keep) ...{'allNights': _nights > 1, 'nights': _nights},
        ...fields,
      });
    } else {
      final target = TripReplaceTarget.find(
        tripId: _plan.trip.value?.id,
        checkIn: _plan.dateOf(_day),
        nights: _nights,
        replaceEnquiryId: widget.replaceEnquiryId,
      );
      String? replaceId;
      if (target != null) {
        final name = target.row.listingName;
        final ok = await _confirmReplace(name, title: TripStrings.replaceFor(name, TripStrings.night(target.day)));
        if (!mounted) return;
        if (!ok) {
          setState(() => _saving = false);
          return;
        }
        replaceId = target.row.id;
      }
      result = await ctrl.savePhoneBooking(
          stayId: widget.stayId,
          day: _day,
          allNights: _allNights,
          nights: _nights,
          fields: fields,
          replaceEnquiryId: replaceId);
      final conflict = ctrl.lastConflict;
      if (result == null && conflict != null && conflict.enquiryId != replaceId) {
        final replace = await _confirmReplace(conflict.listingName);
        if (!mounted) return;
        if (!replace) {
          setState(() => _saving = false);
          return;
        }
        result = await ctrl.savePhoneBooking(
          stayId: widget.stayId,
          day: _day,
          allNights: _allNights,
          nights: _nights,
          fields: fields,
          replaceEnquiryId: conflict.enquiryId,
        );
      }
    }
    if (!mounted) return;
    if (result == null) {
      setState(() => _saving = false);
      return;
    }
    if (_edit) AppToast.success(TripStrings.bookingUpdated);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return TripSheetFrame(
      title: _edit ? TripStrings.editBooking : TripStrings.phoneBookingTitle,
      description: widget.stayName,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_edit) ...[
            const Text(TripStrings.phoneBookingFooter,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35)),
            const SizedBox(height: 6),
          ],
          const TripPaymentLine(),
        ],
      ),
      children: [
        _label(_Copy.hostName + _Copy.optional),
        TextField(
          controller: _hostName,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.hostNameMax)],
          style: _inputStyle,
          decoration: _decoration(),
        ),
        const SizedBox(height: 14),
        _label(_Copy.hostPhone + _Copy.optional),
        TextField(
          controller: _hostPhone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          style: _inputStyle,
          decoration: _decoration(prefix: '+91 '),
        ),
        const SizedBox(height: 14),
        _label(TripStrings.dates),
        _datesBox(),
        const SizedBox(height: 14),
        _label(TripStrings.room + _Copy.optional),
        _roomSection(),
        const SizedBox(height: 14),
        _label(TripStrings.agreedPrice + _Copy.optional),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          style: _inputStyle,
          decoration: _decoration(prefix: '₹ '),
        ),
        const SizedBox(height: 14),
        _label(TripStrings.advancePaid),
        _advanceSection(),
        const SizedBox(height: 14),
        _label(TripStrings.note + _Copy.optional),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.noteMax)],
          style: _inputStyle,
          decoration: _decoration(),
        ),
        const SizedBox(height: 20),
        GradientButton(
          onPressed: _saving ? null : _save,
          label: TripStrings.saveBooking,
          isLoading: _saving,
          gradient: TripColors.gradient,
          shadowColor: TripColors.accent,
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
      );

  InputDecoration _decoration({String? prefix}) => InputDecoration(
        prefixText: prefix,
        filled: true,
        fillColor: AppColors.scaffoldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TripColors.accent, width: 1.5)),
      );

  Widget _datesBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.calendar_1, size: 16, color: TripColors.accent),
              const SizedBox(width: 8),
              Expanded(child: Text(_datesText(), maxLines: 2, overflow: TextOverflow.ellipsis, style: _inputStyle)),
            ],
          ),
          if (_canPickAllNights)
            InkWell(
              onTap: _saving ? null : () => setState(() => _allNights = !_allNights),
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Checkbox(
                        value: _allNights,
                        activeColor: TripColors.accent,
                        onChanged: _saving ? null : (v) => setState(() => _allNights = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(TripStrings.allNights,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textDark)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _roomSection() {
    final showOther = _otherSelected || !_hasRoomChips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasRoomChips)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in widget.rooms)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: SelectableChip(
                    label: r,
                    selected: !_otherSelected && _room == r,
                    onTap: () => setState(() {
                      _room = r;
                      _otherSelected = false;
                    }),
                    activeColor: TripColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: SelectableChip(
                  label: TripStrings.other,
                  selected: _otherSelected,
                  onTap: () => setState(() {
                    _otherSelected = true;
                    _room = null;
                  }),
                  activeColor: TripColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
              ),
            ],
          ),
        if (showOther) ...[
          if (_hasRoomChips) const SizedBox(height: 10),
          TextField(
            controller: _otherRoom,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.roomNameMax)],
            style: _inputStyle,
            decoration: _decoration().copyWith(hintText: _Copy.roomName),
          ),
        ],
      ],
    );
  }

  Widget _advanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: SelectableChip(
                  label: TripStrings.no,
                  selected: !_advancePaid,
                  onTap: () => setState(() => _advancePaid = false),
                  activeColor: TripColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: SelectableChip(
                  label: TripStrings.yes,
                  selected: _advancePaid,
                  onTap: () => setState(() => _advancePaid = true),
                  activeColor: TripColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
              ),
            ),
          ],
        ),
        if (_advancePaid) ...[
          const SizedBox(height: 10),
          _label(TripStrings.amount),
          TextField(
            controller: _advance,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            style: _inputStyle,
            decoration: _decoration(prefix: '₹ '),
          ),
        ],
      ],
    );
  }
}

class _LinkBody extends StatelessWidget {
  final TripPhoneBookingResult result;

  const _LinkBody({required this.result});

  String? get _phone {
    final digits = ContactLauncher.tenDigits(result.enquiry.phoneBooking?.hostPhone ?? '');
    return digits.length == 10 ? digits : null;
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone;
    return TripSheetFrame(
      title: _Copy.linkTitle,
      description: _Copy.linkDescription,
      footer: const TripPaymentLine(),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.scaffoldBg, borderRadius: BorderRadius.circular(12)),
          child: Text(result.whatsAppText,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textMedium, height: 1.4)),
        ),
        const SizedBox(height: 16),
        if (phone != null) ...[
          GradientButton(
            onPressed: () => ContactLauncher.whatsApp(phone, message: result.whatsAppText),
            label: TripStrings.sendOnWhatsApp,
            gradient: TripColors.gradient,
            shadowColor: TripColors.accent,
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: result.confirmLink));
              AppToast.success(TripStrings.linkCopied);
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 48),
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(TripStrings.copyLink,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: TripColors.accentDark)),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          child: const Text(TripStrings.done,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
        ),
      ],
    );
  }
}
