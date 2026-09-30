import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_shadows.dart';

class NearestConfirmSheet extends StatelessWidget {
  final String itemLabel;
  final VoidCallback onConfirm;
  final bool isPlot;
  const NearestConfirmSheet({super.key, required this.itemLabel, required this.onConfirm, this.isPlot = false});

  static Future<void> show(
    BuildContext context, {
    required String itemLabel,
    required VoidCallback onConfirm,
    bool isPlot = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NearestConfirmSheet(itemLabel: itemLabel, onConfirm: onConfirm, isPlot: isPlot),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentFor(isPlot);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppShadows.premium(
          accent,
          alpha: 0.28,
          blur: 20,
          offset: const Offset(0, -6),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + AppInsets.bottomViewPadding(context)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.travel_explore_rounded, size: 30, color: accent),
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${_cap(itemLabel)} Nearby',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search the nearest $itemLabel in your district instead?',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Pop immediately — the actual fetch shows as a full-screen
                      // AppLoadingOverlay from MainScreen (see isLoadingNearest),
                      // not a loading state inside this sheet.
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Search Nearest', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Not Now',
                    style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
