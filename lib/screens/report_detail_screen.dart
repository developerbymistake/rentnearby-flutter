import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../models/listing_report_model.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Get.arguments as ListingReportModel;
    final isPending = r.status == 'Pending';

    return Scaffold(
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 24),
              child: Row(children: [
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                ),
                const Text('Report Details',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isPending ? AppColors.reportAlert.withValues(alpha: 0.08) : AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('REASON',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: isPending ? AppColors.reportAlert : AppColors.success)),
                  const SizedBox(height: 4),
                  Text(r.reasonName,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                ]),
              ),
              const SizedBox(height: 16),
              _field('Message from reporter', r.details.isNotEmpty ? r.details : 'No additional details provided.'),
              const SizedBox(height: 16),
              _field('Status', r.status),
              const SizedBox(height: 16),
              _field('Filed on', _formatDate(r.createdAt)),
              if (r.resolvedAt != null) ...[
                const SizedBox(height: 16),
                _field('Resolved on', _formatDate(r.resolvedAt!)),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Iconsax.shield_tick, size: 16, color: AppColors.textLight),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text("The reporter's identity is withheld to protect their privacy.",
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _field(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textHint)),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: AppColors.textMedium, height: 1.5)),
    ]);
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
