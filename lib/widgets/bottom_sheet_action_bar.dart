import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';

class BottomSheetActionBar extends StatelessWidget {
  final String listingId;
  const BottomSheetActionBar({super.key, required this.listingId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
    );
  }
}
