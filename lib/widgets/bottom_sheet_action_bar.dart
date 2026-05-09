import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class BottomSheetActionBar extends StatelessWidget {
  final String listingId;
  final String? ownerPhone;
  const BottomSheetActionBar({super.key, required this.listingId, this.ownerPhone});

  void _call() async {
    if (ownerPhone == null) return;
    final url = Uri.parse('tel:+91$ownerPhone');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _whatsapp() async {
    if (ownerPhone == null) return;
    final url = Uri.parse('https://wa.me/91$ownerPhone');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = ownerPhone != null;
    return Column(
      children: [
        // Row 1: View Details — full width
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Get.toNamed(AppRoutes.listingDetail, arguments: listingId);
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('View Details',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        if (hasPhone) ...[
          const SizedBox(height: 8),
          // Row 2: Call Owner + WhatsApp side by side
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _call,
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call Owner',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _whatsapp,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('WhatsApp',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
