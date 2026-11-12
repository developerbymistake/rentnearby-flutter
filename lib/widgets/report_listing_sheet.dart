import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReportListingSheet(
          listingId: listingId,
          listingType: listingType,
          palette: palette,
          tripEnquiryId: tripEnquiryId,
        ),
      ),
    );
  }

  @override
  State<ReportListingSheet> createState() => _ReportListingSheetState();
}

class _ReportListingSheetState extends State<ReportListingSheet> {
  final _ctrl = Get.find<ReportController>();
  final _detailsCtrl = TextEditingController();
  String? _selectedReasonId;
  bool _submitting = false;

  bool get _isValid =>
      _selectedReasonId != null && _detailsCtrl.text.trim().isNotEmpty;

  ChatKindStyle get _kind => ChatKindStyle.of(widget.listingType);

  InputDecoration _inputDec({String? hintText}) => InputDecoration(
    hintText: hintText,
    hintStyle: FitnessAppTheme.body2.copyWith(color: FitnessAppTheme.deactivatedText),
    filled: true,
    fillColor: FitnessAppTheme.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: FitnessAppTheme.spacer),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: _kind.dark, width: 1.5),
    ),
  );

  @override
  void initState() {
    super.initState();
    if (_ctrl.reportReasons.isEmpty) _ctrl.loadReportReasons();
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _ReportConfirmDialog(),
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
        textStyle: FitnessAppTheme.body2.copyWith(color: FitnessAppTheme.darkerText),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: FitnessAppTheme.body2.copyWith(color: FitnessAppTheme.deactivatedText),
          filled: true,
          fillColor: FitnessAppTheme.background,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: FitnessAppTheme.spacer),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _kind.dark, width: 1.5),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(FitnessAppTheme.white),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(4),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: FitnessAppTheme.spacer),
            ),
          ),
        ),
        dropdownMenuEntries: reasons
            .map(
              (r) => DropdownMenuEntry<String>(
                value: r.id,
                label: r.name,
                style: MenuItemButton.styleFrom(
                  textStyle: FitnessAppTheme.body2.copyWith(fontWeight: FontWeight.w500),
                  foregroundColor: FitnessAppTheme.darkerText,
                ),
              ),
            )
            .toList(),
        onSelected: (id) => setState(() => _selectedReasonId = id),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final minSheetHeight = MediaQuery.of(context).size.height * 0.62;
    return ChatSheetFrame(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minSheetHeight,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          child: TemplateStagger(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
                decoration: BoxDecoration(
                  gradient: _kind.gradient,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: FitnessAppTheme.white.withValues(alpha: Alpha.half),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Report this listing',
                      textAlign: TextAlign.center,
                      style: FitnessAppTheme.headline.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: FitnessAppTheme.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: RepliesTone.warnSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DesignColors.warnDeep.withValues(alpha: Alpha.scrim)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: DesignColors.warnDeep),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Please report responsibly — misuse may lead to '
                          'action on your account.',
                          style: FitnessAppTheme.caption.copyWith(
                            fontSize: 12,
                            color: FitnessAppTheme.darkText,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Align(alignment: Alignment.centerLeft, child: _reasonPicker(context)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: TextField(
                  controller: _detailsCtrl,
                  maxLines: 5,
                  maxLength: 500,
                  inputFormatters: noEmojiInputFormatters,
                  onChanged: (_) => setState(() {}),
                  cursorColor: FitnessAppTheme.nearlyDarkBlue,
                  style: FitnessAppTheme.body2.copyWith(color: FitnessAppTheme.darkerText),
                  decoration: _inputDec(hintText: 'Please describe the issue (required)').copyWith(
                    counterStyle: FitnessAppTheme.caption.copyWith(fontSize: 12, color: FitnessAppTheme.deactivatedText),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _submitting ? 0.5 : 1,
                        child: SecondaryButton(
                          label: 'Cancel',
                          neutral: true,
                          height: 52,
                          onPressed: _submitting ? null : () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Submit',
                        loading: _submitting,
                        height: 52,
                        tone: KitTone.danger,
                        onPressed: _isValid && !_submitting ? _confirmAndSubmit : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportConfirmDialog extends StatelessWidget {
  const _ReportConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: DesignColors.textInverse,
            borderRadius: CardRadius.hero,
            boxShadow: ShadowTokens.elev3,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Report this listing?', style: TypeTokens.title),
                  const SizedBox(height: 8),
                  Text(
                    'Our team will review this listing based on the details you provide. Continue?',
                    style: TypeTokens.body,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Cancel',
                          neutral: true,
                          compact: true,
                          onPressed: () => Navigator.pop(context, false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Report',
                          tone: KitTone.danger,
                          compact: true,
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
