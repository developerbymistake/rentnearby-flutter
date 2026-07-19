import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../controllers/inquiry_controller.dart';
import '../utils/app_toast.dart';
import '../utils/input_formatters.dart';
import 'gradient_button.dart';

const _reasons = <(String value, String label)>[
  ('NotResponding', 'Not responding'),
  ('Unhelpful', 'Unhelpful / rude'),
  ('WrongInformation', 'Gave wrong information'),
  ('Other', 'Other'),
];

/// "Report an issue with my agent" — visual shape mirrors InquiryContactSheet (gradient header,
/// rounded-top, drag handle, keyboard-avoiding), but unlike that sheet's pure-local-form precedent
/// this one has real submit plumbing: it calls InquiryController.submitEscalation directly and
/// reacts to its own isSubmittingEscalation flag, since the result (whether a Pending report
/// already exists, 409) can only be known from the server.
class EscalateInquirySheet extends StatefulWidget {
  final String inquiryId;
  const EscalateInquirySheet({super.key, required this.inquiryId});

  static Future<bool?> show(BuildContext context, {required String inquiryId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: EscalateInquirySheet(inquiryId: inquiryId),
      ),
    );
  }

  @override
  State<EscalateInquirySheet> createState() => _EscalateInquirySheetState();
}

class _EscalateInquirySheetState extends State<EscalateInquirySheet> {
  final _ctrl = Get.find<InquiryController>();
  late final _noteCtrl = TextEditingController();
  String? _selectedReason;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null) {
      AppToast.error('Please select a reason.');
      return;
    }
    final ok = await _ctrl.submitEscalation(widget.inquiryId, reason, note: _noteCtrl.text);
    if (!mounted) return;
    if (ok) {
      AppToast.success("Reported. We'll notify you once it's reviewed.");
      Navigator.pop(context, true);
    }
    // On failure, submitEscalation has already toasted the real server message (e.g. a 409 for an
    // already-open report) — the sheet just stays open so the user can see it and dismiss manually.
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Need help with this agent?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Let us know what's going on — our team will review and step in.",
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textLight, height: 1.5),
                ),
                const SizedBox(height: 18),
                for (final r in _reasons) ...[
                  _ReasonOption(
                    label: r.$2,
                    selected: _selectedReason == r.$1,
                    onTap: () => setState(() => _selectedReason = r.$1),
                  ),
                  const SizedBox(height: 9),
                ],
                const SizedBox(height: 4),
                TextField(
                  controller: _noteCtrl,
                  inputFormatters: noEmojiInputFormatters,
                  maxLines: 3,
                  maxLength: 500,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Add more details (optional)',
                    hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textHint),
                    filled: true,
                    fillColor: AppColors.surface,
                    counterText: '',
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Obx(() {
                  final submitting = _ctrl.isSubmittingEscalation.value;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GradientButton(
                        label: 'Submit Report',
                        isLoading: submitting,
                        onPressed: submitting ? null : _submit,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: submitting ? null : () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLight)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primaryLight : AppColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? AppColors.primaryLight : AppColors.divider, width: 2),
                color: selected ? AppColors.primaryLight : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 11),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
