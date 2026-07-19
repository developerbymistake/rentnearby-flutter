import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../utils/app_toast.dart';
import '../utils/input_formatters.dart';
import 'gradient_button.dart';

/// The result of [InquiryContactSheet] — a contact to submit an Inquiry under, distinct from the
/// logged-in account (e.g. booking on behalf of someone else).
class InquiryContact {
  final String name;
  final String mobile;
  const InquiryContact({required this.name, required this.mobile});
}

/// Bottom sheet for overriding who an Inquiry submission contacts, pre-filled with whatever the
/// form is currently showing (the account's own details, or a previously-saved override) so this
/// is always a quick edit, never a blank form. Mirrors ReportListingSheet's exact shape.
class InquiryContactSheet extends StatefulWidget {
  final String initialName;
  final String initialMobile;

  const InquiryContactSheet({
    super.key,
    required this.initialName,
    required this.initialMobile,
  });

  static Future<InquiryContact?> show(
    BuildContext context, {
    required String initialName,
    required String initialMobile,
  }) {
    return showModalBottomSheet<InquiryContact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: InquiryContactSheet(initialName: initialName, initialMobile: initialMobile),
      ),
    );
  }

  @override
  State<InquiryContactSheet> createState() => _InquiryContactSheetState();
}

class _InquiryContactSheetState extends State<InquiryContactSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.initialName);
  late final _mobileCtrl = TextEditingController(text: widget.initialMobile);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDec({String? hintText, Widget? prefixIcon}) => InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
      );

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    if (name.isEmpty || mobile.length != 10) {
      AppToast.error('Please enter a valid name and 10-digit mobile number.');
      return;
    }
    Navigator.pop(context, InquiryContact(name: name, mobile: mobile));
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
                  'Contact a different number',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "We'll reach out about this one inquiry using the details below instead of your account.",
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textLight, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nameCtrl,
                    inputFormatters: noEmojiInputFormatters,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                    decoration: _inputDec(hintText: 'Full name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _mobileCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
                    decoration: _inputDec(hintText: '10-digit mobile number').copyWith(counterText: ''),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Mobile number is required';
                      if (t.length != 10) return 'Enter a valid 10-digit number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textMedium,
                            side: const BorderSide(color: AppColors.divider),
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GradientButton(label: 'Save', onPressed: _save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
