import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../controllers/report_controller.dart';
import '../utils/app_toast.dart';
import 'gradient_button.dart';

class ReportListingSheet extends StatefulWidget {
  final String listingId;
  final String listingType; // 'Room' | 'Plot'

  const ReportListingSheet({super.key, required this.listingId, required this.listingType});

  static Future<void> show(BuildContext context, {required String listingId, required String listingType}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ReportListingSheet(listingId: listingId, listingType: listingType),
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

  bool get _isValid => _selectedReasonId != null && _detailsCtrl.text.trim().isNotEmpty;

  InputDecoration _inputDec({String? hintText}) => InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
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
        title: const Text('Report this listing?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark)),
        content: const Text(
          'Our team will review this listing based on the details you provide. Continue?',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Report this listing',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 16),
          Obx(() => DropdownButtonFormField<String>(
                initialValue: _selectedReasonId,
                hint: const Text('Select a reason',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint)),
                items: _ctrl.reportReasons
                    .map((r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(r.name, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedReasonId = v),
                decoration: _inputDec(),
              )),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsCtrl,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark),
            decoration: _inputDec(hintText: 'Please describe the issue (required)'),
          ),
          const SizedBox(height: 20),
          GradientButton(
            label: 'Submit',
            isLoading: _submitting,
            onPressed: _isValid && !_submitting ? _confirmAndSubmit : null,
            gradient: LinearGradient(colors: [AppColors.error, AppColors.error]),
            shadowColor: AppColors.error,
          ),
        ],
      ),
    );
  }
}
