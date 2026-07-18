import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../models/inquiry_detail_model.dart';
import '../widgets/gradient_button.dart';
import '../widgets/max_width_content.dart';

/// Success state after InquiryFormScreen submits — reached via
/// Get.offNamed so the filled form is never left on the back stack.
/// MaxWidthContent-wrapped, matching every other single-column screen in
/// this feature.
class InquiryConfirmationScreen extends StatelessWidget {
  const InquiryConfirmationScreen({super.key});

  InquiryDetailModel? get _detail {
    final args = (Get.arguments as Map?) ?? const {};
    final d = args['detail'];
    return d is InquiryDetailModel ? d : null;
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: MaxWidthContent(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Iconsax.tick_circle5, color: AppColors.success, size: 52),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Inquiry Submitted!',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Our team will review your request and get in touch with you shortly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppColors.textLight, height: 1.5),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 24),
                  _buildSummaryCard(detail),
                ],
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'View My Inquiries',
                    onPressed: () => Get.offNamed(AppRoutes.myInquiries),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Get.until((route) => route.settings.name == AppRoutes.main),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primaryLight),
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Back to Home', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
                SizedBox(height: 12 + AppInsets.bottomViewPadding(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(InquiryDetailModel detail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.serviceName,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textLight)),
          const SizedBox(height: 3),
          Text(detail.servicePackageName,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const Divider(height: 22, color: AppColors.divider),
          _row('Reference ID', '#${detail.id.substring(0, 8).toUpperCase()}'),
          const SizedBox(height: 8),
          _row('Status', detail.status),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      ],
    );
  }
}
