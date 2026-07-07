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
    return Obx(() {
      final reasons = _ctrl.reportReasons;
      // A real form-field dropdown reads as far more "clickable" here than a
      // popup-menu-on-a-bottom-sheet did, and reuses the same _inputDec()
      // styling as the details field below it, so the two fields match.
      return DropdownButtonFormField<String>(
        initialValue: _selectedReasonId,
        isExpanded: true,
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.textMedium,
          size: 22,
        ),
        iconSize: 22,
        dropdownColor: AppColors.background,
        elevation: 3,
        borderRadius: BorderRadius.circular(14),
        menuMaxHeight: 320,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: AppColors.textDark,
        ),
        decoration: _inputDec(hintText: 'Select a reason'),
        hint: const Text(
          'Select a reason',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textHint,
          ),
        ),
        items: reasons
            .map(
              (r) => DropdownMenuItem<String>(
                value: r.id,
                child: Text(
                  r.name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (id) => setState(() => _selectedReasonId = id),
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
