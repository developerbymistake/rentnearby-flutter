import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class RoleCorrectionDialog {
  const RoleCorrectionDialog._();

  static Future<bool> confirm(BuildContext context, {required String kind, required int percent}) async {
    final body = percent <= 0
        ? 'Nothing filled yet. You can do this only once.'
        : '$kind draft, $percent% filled, will be deleted. You can do this only once.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete draft and change role?',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
        content: Text(body,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Change role',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.error)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
