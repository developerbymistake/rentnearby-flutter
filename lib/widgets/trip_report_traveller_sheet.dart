import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:get/get.dart';
import '../controllers/report_controller.dart';
import '../features/trip/data/trip_enquiry_repository.dart';
import '../features/trip/models/trip_enquiry_model.dart';
import '../features/trip/trip_strings.dart';
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

  static final ListingTone _tone = ListingTone.forest;
  static const List<String> _arts = [ListingArt.clipboard, ListingArt.roundPushpin, ListingArt.speechBalloon, ListingArt.calendar, ListingArt.moneyBag, ListingArt.compass];

  @override
  Widget build(BuildContext context) {
    final name = widget.enquiry.traveller.name?.trim();
    return TripSheetFrame(
      tone: _tone,
      art: ListingArt.roundPushpin,
      size: SheetSize.list,
      title: TripStrings.reportTraveller,
      description: name == null || name.isEmpty ? null : name,
      footnote: _reasonId == null ? TripStrings.pickReason : TripStrings.reportFooter,
      footer: Obx(() {
        final hasReasons = _ctrl.reportReasons.isNotEmpty;
        return GradientPillButton(
          tone: _tone,
          label: TripStrings.sendReport,
          loading: _saving,
          enabled: _reasonId != null && hasReasons,
          onTap: _reasonId == null || _saving || !hasReasons ? null : _submit,
        );
      }),
      children: [
        Obx(() {
          final reasons = _ctrl.reportReasons;
          if (reasons.isEmpty) return _reasonsEmpty();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < reasons.length; i++)
              ProblemOption3D(
                tone: ListingTone.at(i),
                art: _arts[i % _arts.length],
                label: reasons[i].name,
                selected: _reasonId == reasons[i].id,
                onTap: _saving ? null : () => setState(() => _reasonId = reasons[i].id),
              ),
          ]);
        }),
        PillField(
          tone: _tone,
          controller: _details,
          enabled: !_saving,
          label: TripStrings.note,
          firstLabel: false,
          leadingArt: ListingArt.speechBalloon,
          maxLength: _detailsMax,
          counterText: '',
          minLines: 2,
          maxLines: 4,
          inputFormatters: noEmojiInputFormatters,
        ),
      ],
    );
  }

  Widget _reasonsEmpty() {
    if (_loading) {
      return Column(children: [
        for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(top: 12), child: SkeletonBox(height: 70, radius: 20)),
      ]);
    }
    return StateCard3D(
      tone: _tone,
      art: ListingArt.worldMap,
      title: TripStrings.couldNotLoad,
      actionLabel: TripStrings.retry,
      onAction: _loadReasons,
      layout: StateLayout.plain,
    );
  }
}
