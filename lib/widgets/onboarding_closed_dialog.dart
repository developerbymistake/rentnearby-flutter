import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class OnboardingClosedDialog {
  const OnboardingClosedDialog._();

  static Future<void> show(BuildContext context, {VoidCallback? onChangeRole}) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Not open here yet',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          content: const Text("We can't take new listings in this area right now.",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5)),
          actions: [
            if (onChangeRole != null)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onChangeRole();
                },
                child: const Text('Change role',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.error)),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textMedium)),
            ),
          ],
        ),
      );
}
