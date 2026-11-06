import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../trip_colors.dart';
import '../trip_strings_bar.dart';

class TripBarHideSheet {
  static Future<bool> show(BuildContext context) async {
    final hide = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                TripStringsBar.hideTitle,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark),
              ),
              const SizedBox(height: 4),
              const Text(
                TripStringsBar.hideBody,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, height: 1.5, color: AppColors.textMedium),
              ),
              const SizedBox(height: 14),
              _primary(ctx),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: TripColors.accentDark,
                  side: const BorderSide(color: TripColors.accent, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(TripStringsBar.keepShowing,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
    return hide == true;
  }

  static Widget _primary(BuildContext ctx) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(ctx, true),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            height: 46,
            decoration: BoxDecoration(gradient: TripColors.gradient, borderRadius: BorderRadius.circular(14)),
            child: const Center(
              child: Text(
                TripStringsBar.hideAction,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      );
}
