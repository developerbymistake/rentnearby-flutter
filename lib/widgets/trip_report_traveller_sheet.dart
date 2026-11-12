import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import '../controllers/report_controller.dart';
import '../features/trip/data/trip_enquiry_repository.dart';
import '../features/trip/models/trip_enquiry_model.dart';
import '../features/trip/trip_strings.dart';
import '../features/trip/widgets/trip_payment_line.dart';
import '../features/trip/widgets/trip_sheet_frame.dart';
import '../utils/app_toast.dart';
import '../utils/dio_error_mapper.dart';
import '../utils/input_formatters.dart';

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
    final name = widget.enquiry.traveller.name?.trim();
    return TripSheetFrame(
      title: TripStrings.reportTraveller,
      description: name == null || name.isEmpty ? null : name,
      footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Obx(() => TripButton(
              onPressed: _reasonId == null || _saving || _ctrl.reportReasons.isEmpty ? null : _submit,
              loading: _saving,
              label: TripStrings.sendReport,
            )),
        if (_reasonId == null) ...[
          const SizedBox(height: 8),
          const Text(TripStrings.pickReason,
              textAlign: TextAlign.center, style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: DesignColors.textMuted)),
        ],
        const SizedBox(height: 10),
        const TripPaymentLine(text: TripStrings.reportFooter),
      ]),
      children: [
        TemplateStagger(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        Obx(() {
          final reasons = _ctrl.reportReasons;
          if (reasons.isEmpty) return _reasonsEmpty();
          return TemplateStagger(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final r in reasons) _reasonRow(r.id, r.name),
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
          style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14),
          decoration: InputDecoration(
            labelText: TripStrings.note,
            counterText: '',
            filled: true,
            fillColor: DesignColors.scaffold,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.transparent)),
            focusedBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: DesignColors.primary, width: 1.5)),
          ),
        ),
          ],
        ),
      ],
    );
  }

  Widget _reasonsEmpty() {
    if (_loading) {
      return Column(children: [
        for (var i = 0; i < 3; i++) ...[const TemplatePlaceholder(height: 48, radius: 12), const SizedBox(height: 8)],
      ]);
    }
    return Column(children: [
      const Text(TripStrings.couldNotLoad, style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: DesignColors.textSecondary)),
      TextLink(label: TripStrings.retry, onTap: _loadReasons, tone: KitTone.trip),
    ]);
  }

  Widget _reasonRow(String id, String label) {
    final on = _reasonId == id;
    const r = BorderRadius.all(Radius.circular(16));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: on ? DesignColors.primarySoft : DesignColors.surface,
          borderRadius: r,
          boxShadow: DesignShadows.card,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _saving ? null : () => setState(() => _reasonId = id),
            borderRadius: r,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              foregroundDecoration:
                  on ? BoxDecoration(borderRadius: r, border: Border.all(color: DesignColors.primary, width: 1.5)) : null,
              child: Row(children: [
                Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 22, color: on ? DesignColors.primary : DesignColors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: FitnessAppTheme.fontName,
                            fontSize: 14,
                            fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                            color: DesignColors.textStrong)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
