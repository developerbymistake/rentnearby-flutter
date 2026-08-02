import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class ListingLimitReachedSheet {
  static void show(
    BuildContext context, {
    required int cap,
    required String unitSingular,
    required String unitPlural,
    required Color accent,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.lock_outline_rounded, size: 30, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(height: 16),
            Text(
              '${_cap(unitSingular)} Limit Reached',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              'You can list up to $cap $unitSingular${cap > 1 ? 's' : ''}. Delete an existing $unitSingular to add a new one.',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.list_alt_rounded, size: 16),
                label: Text('Manage ${_cap(unitPlural)}', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
