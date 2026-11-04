import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/module_palette.dart';
import '../controllers/report_controller.dart';
import '../features/stay/setup/stay_option_sets.dart';
import '../features/taxi/taxi_option_sets.dart';
import '../features/trip/data/trip_enquiry_repository.dart';
import '../features/trip/models/trip_enquiry_model.dart';
import '../features/trip/trip_strings.dart';
import '../features/trip/widgets/trip_payment_line.dart';
import '../features/trip/widgets/trip_shimmers.dart';
import '../features/trip/widgets/trip_sheet_frame.dart';
import '../utils/app_toast.dart';
import '../utils/dio_error_mapper.dart';
import '../utils/input_formatters.dart';
import 'gradient_button.dart';

class TripReportTravellerSheet {
  static Future<bool> show(BuildContext context, {required TripEnquiryModel enquiry}) async {
    final sent = await TripSheetFrame.show<bool>(context, _ReportBody(enquiry: enquiry));
    return sent == true;
  }
}

class _ReportBody extends StatefulWidget {
  const _ReportBody({required this.enquiry});

  final TripEnquiryModel enquiry;

  @override
  State<_ReportBody> createState() => _ReportBodyState();
}

class _ReportBodyState extends State<_ReportBody> {
  final _ctrl = Get.isRegistered<ReportController>() ? Get.find<ReportController>() : Get.put(ReportController());
  static const int _detailsMax = 500;

  final _details = TextEditingController();
  String? _reasonId;
  bool _loading = false;
  bool _saving = false;

  ModulePalette get _palette => widget.enquiry.isTaxi ? TaxiColors.palette : StayColors.palette;

  @override
  void initState() {
    super.initState();
    if (_ctrl.reportReasons.isEmpty) _loadReasons();
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    setState(() => _loading = true);
    await _ctrl.loadReportReasons();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final reason = _reasonId;
    if (reason == null || _saving) return;
    setState(() => _saving = true);
    try {
      final text = _details.text.trim();
      await const TripEnquiryRepository().reportTraveller(
        widget.enquiry.id,
        reasonId: reason,
        details: text.isEmpty ? null : text,
      );
      if (!mounted) return;
      AppToast.success(TripStrings.reportSent);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (DioErrorMapper.isNetworkError(e)) {
        AppToast.error(TripStrings.noNetwork);
      } else if (DioErrorMapper.errorType(e) == TripEnquiryErrorTypes.enquiryClosed) {
        AppToast.warning(DioErrorMapper.toMessage(e, TripStrings.couldNotLoad, showRawMessageForStatusCodes: {409}));
      } else if (e is DioException && e.response?.statusCode == 409) {
        AppToast.info(TripStrings.alreadyReportedTraveller);
      } else {
        AppToast.error(DioErrorMapper.toMessage(e, TripStrings.couldNotLoad, showRawMessageForStatusCodes: {400, 403, 429}));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    final name = widget.enquiry.traveller.name?.trim();
    return TripSheetFrame(
      title: TripStrings.reportTraveller,
      description: name == null || name.isEmpty ? null : name,
      footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Obx(() => GradientButton(
              onPressed: _reasonId == null || _saving || _ctrl.reportReasons.isEmpty ? null : _submit,
              isLoading: _saving,
              label: TripStrings.sendReport,
              gradient: p.gradient,
              shadowColor: p.accent,
            )),
        if (_reasonId == null) ...[
          const SizedBox(height: 8),
          const Text(TripStrings.pickReason,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textLight)),
        ],
        const SizedBox(height: 10),
        const TripPaymentLine(text: TripStrings.reportFooter),
      ]),
      children: [
        Obx(() {
          final reasons = _ctrl.reportReasons;
          if (reasons.isEmpty) return _reasonsEmpty();
          return Column(children: [
            for (final r in reasons) _reasonRow(r.id, r.name, p),
          ]);
        }),
        const SizedBox(height: 12),
        TextField(
          controller: _details,
          enabled: !_saving,
          maxLength: _detailsMax,
          minLines: 2,
          maxLines: 4,
          inputFormatters: noEmojiInputFormatters,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: TripStrings.note,
            counterText: '',
            filled: true,
            fillColor: p.surface,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.accent, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _reasonsEmpty() {
    if (_loading) {
      return Column(children: [
        for (var i = 0; i < 3; i++) ...[TripShimmers.rowBox(height: 48, radius: 12), const SizedBox(height: 8)],
      ]);
    }
    return Column(children: [
      const Text(TripStrings.couldNotLoad, style: TextStyle(fontSize: 13, color: AppColors.textMedium)),
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: _palette.accentDark),
        onPressed: _loadReasons,
        child: const Text(TripStrings.retry),
      ),
    ]);
  }

  Widget _reasonRow(String id, String label, ModulePalette p) {
    final on = _reasonId == id;
    return InkWell(
      onTap: _saving ? null : () => setState(() => _reasonId = id),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 22, color: on ? p.accent : AppColors.textHint),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: on ? FontWeight.w600 : FontWeight.w400, color: AppColors.textDark)),
            ),
          ),
        ]),
      ),
    );
  }
}
