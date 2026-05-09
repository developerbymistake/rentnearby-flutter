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
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              Get.toNamed(AppRoutes.listingDetail, arguments: listingId);
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View Details',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        if (hasPhone) ...[
          const SizedBox(width: 8),
          _IconAction(
            icon: Icons.call_rounded,
            color: const Color(0xFF2E7D32),
            onTap: _call,
            tooltip: 'Call',
          ),
          const SizedBox(width: 8),
          _IconAction(
            icon: Icons.chat_rounded,
            color: const Color(0xFF25D366),
            onTap: _whatsapp,
            tooltip: 'WhatsApp',
          ),
        ],
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  const _IconAction({required this.icon, required this.color, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      );
}
