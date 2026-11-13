import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_reports.dart';
import '../config/module_palette.dart';
import '../controllers/report_controller.dart';
import '../utils/app_toast.dart';
import '../utils/input_formatters.dart';

class ReportListingSheet extends StatefulWidget {
  final String listingId;
  final String listingType; // 'Stay' | 'Taxi'
  final ModulePalette palette;
  final String? tripEnquiryId;

  const ReportListingSheet({
    super.key,
    required this.listingId,
    required this.listingType,
    this.palette = templateModulePalette,
    this.tripEnquiryId,
  });

  static Future<void> show(
    BuildContext context, {
    required String listingId,
    required String listingType,
    ModulePalette palette = templateModulePalette,
    String? tripEnquiryId,
  }) {
    return showDockSheet(
      context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (_) => ReportListingSheet(
        listingId: listingId,
        listingType: listingType,
        palette: palette,
        tripEnquiryId: tripEnquiryId,
      ),
    );
  }

  @override
  State<ReportListingSheet> createState() => _ReportListingSheetState();
}

class _ReportListingSheetState extends State<ReportListingSheet> {
  final _ctrl = Get.find<ReportController>();
  final _detailsCtrl = TextEditingController();
  final _detailsFocus = FocusNode();
  String? _selectedReasonId;
  bool _submitting = false;

  bool get _isValid =>
      _selectedReasonId != null && _detailsCtrl.text.trim().isNotEmpty;

  ListingTone get _tone => Report3D.tone(widget.listingType);

  @override
  void initState() {
    super.initState();
    _detailsFocus.addListener(() => setState(() {}));
    if (_ctrl.reportReasons.isEmpty) _ctrl.loadReportReasons();
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    _detailsFocus.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSubmit() async {
    final confirmed = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: _tone,
        art: ListingArt.clipboard,
        title: 'Report this listing?',
        body: 'Our team will review this listing based on the details you provide. Continue?',
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx, false),
        primaryLabel: 'Report',
        primaryDanger: true,
        leftAlign: true,
        artDanger: true,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _submitting = true);
    final ok = await _ctrl.submitReport(
      listingId: widget.listingId,
      listingType: widget.listingType,
      reasonId: _selectedReasonId!,
      details: _detailsCtrl.text.trim(),
      tripEnquiryId: widget.tripEnquiryId,
    );
    if (mounted) {
      if (ok) {
        AppToast.success('Report submitted. Thank you for letting us know.');
        Navigator.pop(context);
      } else {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _reasonPicker(BuildContext context) {
    final tone = _tone;
    return Obx(() {
      final reasons = _ctrl.reportReasons;
      final fieldWidth = MediaQuery.of(context).size.width - 48;
      return DropdownMenu<String>(
        key: ValueKey(_selectedReasonId),
        initialSelection: _selectedReasonId,
        width: fieldWidth,
        enableFilter: false,
        enableSearch: false,
        requestFocusOnTap: false,
        hintText: 'Select a reason',
        textStyle: ReportField3D.text,
        trailingIcon: ReportField3D.caret(tone),
        selectedTrailingIcon: ReportField3D.caret(tone),
        inputDecorationTheme: ReportField3D.pickerTheme(tone),
        menuStyle: ReportField3D.menuStyle,
        dropdownMenuEntries: reasons
            .map(
              (r) => DropdownMenuEntry<String>(
                value: r.id,
                label: r.name,
                trailingIcon: r.id == _selectedReasonId ? ReportField3D.check(tone) : null,
                style: ReportField3D.entryStyle(tone, r.id == _selectedReasonId),
              ),
            )
            .toList(),
        onSelected: (id) => setState(() => _selectedReasonId = id),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final mq = MediaQuery.of(context);
    final avail = mq.size.height - mq.padding.top - 60 - SheetInsets.lift(context);
    final height = math.max(320.0, math.min(744.0 + mq.padding.bottom, avail));
    const room = ReportSheetBand.artRoom;
    return SizedBox(
      height: height + room,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: room,
            child: DecoratedBox(
              decoration: Report3D.sheetDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReportSheetBand(tone: tone, title: 'Report this listing'),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ReportNote3D.warn(text: 'Please report responsibly. Misuse may lead to action on your account.'),
                          const SizedBox(height: 18),
                          Align(alignment: Alignment.centerLeft, child: _reasonPicker(context)),
                          const SizedBox(height: 18),
                          TextField(
                            controller: _detailsCtrl,
                            focusNode: _detailsFocus,
                            maxLines: 5,
                            maxLength: 500,
                            inputFormatters: noEmojiInputFormatters,
                            onChanged: (_) => setState(() {}),
                            cursorColor: tone.text,
                            style: ReportField3D.areaText,
                            decoration: ReportField3D.area(tone, hintText: 'Please describe the issue (required)', focused: _detailsFocus.hasFocus),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 14, 24, 26 + mq.padding.bottom),
                    child: PillButtonRow(
                      children: [
                        WhitePillButton(
                          tone: tone,
                          label: 'Cancel',
                          enabled: !_submitting,
                          onTap: () => Navigator.pop(context),
                        ),
                        GradientPillButton(
                          tone: tone,
                          label: 'Submit',
                          danger: true,
                          loading: _submitting,
                          enabled: _isValid,
                          onTap: _confirmAndSubmit,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: Center(child: ReportSheetArt())),
        ],
      ),
    );
  }
}
