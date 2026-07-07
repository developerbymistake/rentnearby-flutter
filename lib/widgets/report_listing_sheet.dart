import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../controllers/report_controller.dart';
import '../utils/app_toast.dart';
import 'gradient_button.dart';

class ReportListingSheet extends StatefulWidget {
  final String listingId;
  final String listingType; // 'Room' | 'Plot'

  const ReportListingSheet({
    super.key,
    required this.listingId,
    required this.listingType,
  });

  static Future<void> show(
    BuildContext context, {
    required String listingId,
    required String listingType,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReportListingSheet(
          listingId: listingId,
          listingType: listingType,
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

  InputDecoration _inputDec({String? hintText}) => InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 14,
      color: AppColors.textHint,
    ),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Report this listing?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        content: const Text(
          'Our team will review this listing based on the details you provide. Continue?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textMedium,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Report',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    final fieldWidth =
        MediaQuery.of(context).size.width - 48; // matches 24+24 outer padding
    return Obx(() {
      final selected = _ctrl.reportReasons.firstWhereOrNull(
        (r) => r.id == _selectedReasonId,
      );
      return PopupMenuButton<String>(
        onSelected: (id) => setState(() => _selectedReasonId = id),
        offset: const Offset(0, 52),
        color: AppColors.background,
        elevation: 8,
        // Material 3 tints popup surfaces with colorScheme.surfaceTint by
        // default, which washes a white menu out to a flat gray — that's
        // what was reading as "disabled". Kill the tint, keep it crisp white.
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
        constraints: BoxConstraints(minWidth: fieldWidth, maxWidth: fieldWidth),
        itemBuilder: (_) => _ctrl.reportReasons
            .map(
              (r) {
                final isSelected = r.id == _selectedReasonId;
                return PopupMenuItem<String>(
                  value: r.id,
                  padding: EdgeInsets.zero,
                  height: 46,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.name,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textDark,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_rounded,
                              size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              },
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider, width: 1.3),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected?.name ?? 'Select a reason',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: selected == null
                        ? AppColors.textHint
                        : AppColors.textDark,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textMedium,
                size: 20,
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final minSheetHeight = MediaQuery.of(context).size.height * 0.55;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minSheetHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Report this listing',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _reasonPicker(context),
                const SizedBox(height: 20),
                TextField(
                  controller: _detailsCtrl,
                  maxLines: 5,
                  maxLength: 500,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                  decoration:
                      _inputDec(
                        hintText: 'Please describe the issue (required)',
                      ).copyWith(
                        counterStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textMedium,
                          side: const BorderSide(color: AppColors.divider),
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        label: 'Submit',
                        isLoading: _submitting,
                        onPressed: _isValid && !_submitting
                            ? _confirmAndSubmit
                            : null,
                        gradient: LinearGradient(
                          colors: [AppColors.error, AppColors.error],
                        ),
                        shadowColor: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
