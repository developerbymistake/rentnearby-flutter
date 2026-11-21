import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/design.dart';
import '../../../utils/input_formatters.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_sheet.dart';
import '../../stay_owner/strings/stay_work_strings.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../stay_owner/enquiries_tab/stay_work_format.dart';
import 'stay_enquiries_controller.dart';
import 'stay_enquiry_format.dart';

abstract final class StayCancelBookingSheet {
  static Future<bool> show(BuildContext context, TripEnquiryModel e) async {
    final key = GlobalKey<StayCancelBookingFormState>();
    final guest = StayEnquiryFormat.guest(e);
    final dates = StayWorkFormat.dates(e);
    final done = await OwnerSheet.show<bool>(
      context,
      look: OwnerLook.stay,
      title: StayWorkStrings.cancelBooking,
      subtitle: StayWorkStrings.nameDates(guest, dates),
      size: SheetSize.form,
      dirty: () => key.currentState?.dirty ?? false,
      child: (_) => StayCancelBookingForm(key: key, enquiry: e),
      footer: (c) => StayCancelBookingFooter(form: key),
    );
    return done == true;
  }
}

class StayCancelBookingForm extends StatefulWidget {
  const StayCancelBookingForm({super.key, required this.enquiry});

  final TripEnquiryModel enquiry;

  @override
  State<StayCancelBookingForm> createState() => StayCancelBookingFormState();
}

class StayCancelBookingFormState extends State<StayCancelBookingForm> {
  final reason = TextEditingController();
  final saving = ValueNotifier<bool>(false);
  final valid = ValueNotifier<bool>(false);
  String? error;

  bool get dirty => reason.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    reason.addListener(_changed);
  }

  @override
  void dispose() {
    reason.dispose();
    saving.dispose();
    valid.dispose();
    super.dispose();
  }

  void _changed() {
    valid.value = reason.text.trim().isNotEmpty;
    if (mounted) setState(() => error = null);
  }

  Future<void> submit() async {
    if (saving.value || !valid.value) return;
    FocusScope.of(context).unfocus();
    saving.value = true;
    final ctrl = StayEnquiriesController.ensure();
    try {
      final ok = await ctrl.cancelBooking(widget.enquiry.id, reason.text.trim());
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => error = ctrl.lastErrorMessage);
    } finally {
      if (mounted) saving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final full = StayEnquiryFormat.guest(widget.enquiry);
    final space = full.indexOf(' ');
    final guest = space > 0 ? full.substring(0, space) : full;
    final err = error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(StayWorkStrings.reason, style: Ink3D.text(12, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
            Text(StayWorkStrings.required, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
          ],
        ),
        Gap.v(6),
        PillField(
          tone: OwnerLook.stay.tone,
          controller: reason,
          minLines: 1,
          maxLines: 4,
          maxLength: StayWorkStrings.reasonMax,
          counterText: '',
          textCapitalization: TextCapitalization.sentences,
          errorText: err,
          inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(StayWorkStrings.reasonMax)],
        ),
        Padding(
          padding: DS.gapInsets(l: 4, t: 6),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: reason,
            builder: (_, v, _) => Text(
              StayWorkStrings.reasonCount(v.text.characters.length),
              style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0),
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.only(top: DS.gv(12)),
          padding: DS.sym(h: 14, v: 12),
          decoration: BoxDecoration(color: ListingTone.teal.tint, borderRadius: DS.circular(12)),
          child: Row(
            children: [
              Art3D(asset: ListingArt.speechBalloon, size: 22),
              Gap.h(10),
              Expanded(
                child: Text(
                  StayWorkStrings.cancelInfo(guest),
                  style: Ink3D.text(12, FontWeight.w600, ListingTone.teal.text, height: 1.35, letterSpacing: 0),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StayCancelBookingFooter extends StatefulWidget {
  const StayCancelBookingFooter({super.key, required this.form});

  final GlobalKey<StayCancelBookingFormState> form;

  @override
  State<StayCancelBookingFooter> createState() => _StayCancelBookingFooterState();
}

class _StayCancelBookingFooterState extends State<StayCancelBookingFooter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.form.currentState;
    if (state == null) return _buttons(context, null, false, false);
    return ValueListenableBuilder<bool>(
      valueListenable: state.saving,
      builder: (context, saving, _) => ValueListenableBuilder<bool>(
        valueListenable: state.valid,
        builder: (context, valid, _) => _buttons(context, state, saving, valid),
      ),
    );
  }

  Widget _buttons(BuildContext context, StayCancelBookingFormState? s, bool saving, bool valid) {
    return Row(
      children: [
        Expanded(
          child: GradientPillButton(
            tone: OwnerLook.stay.tone,
            label: StayWorkStrings.cancelBooking,
            danger: true,
            loading: saving,
            enabled: valid && !saving,
            onTap: s == null || !valid || saving ? null : s.submit,
          ),
        ),
        Gap.h(12),
        Expanded(
          child: WhitePillButton(
            tone: ListingTone.indigo,
            label: StayWorkStrings.keep,
            onTap: saving ? null : () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}
