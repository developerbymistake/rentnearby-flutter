import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import 'coin_icon.dart';

/// The one shared bottom sheet used identically by Room and Plot Go-Live
/// whenever a spend attempt returns INSUFFICIENT_BALANCE — parameterized by
/// the numbers, never duplicated per listing kind. This is the single most
/// important UX moment in the coin economy: a clear "Recharge" call-to-
/// action, not just a toast.
class InsufficientBalanceSheet extends StatelessWidget {
  final int required;
  final int current;

  const InsufficientBalanceSheet({super.key, required this.required, required this.current});

  /// Resolves `true` when the owner topped up via "Recharge Now" and the
  /// purchase completed — callers (my_listings_screen.dart/my_plots_screen
  /// .dart) use this to re-run the Go-Live flow so the plan sheet reopens
  /// against the fresh balance, rather than leaving the owner to manually
  /// retry. Resolves `false` for every other dismissal (swipe-to-close,
  /// "Redeem a Code", or a cancelled/failed purchase).
  static Future<bool> show(BuildContext context, {required int required, required int current}) {
    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => InsufficientBalanceSheet(required: required, current: current),
    ).then((v) => v == true);
  }

  @override
  Widget build(BuildContext context) {
    final shortfall = (required - current).clamp(0, required);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(16)),
            child: const CoinIcon(size: 30),
          ),
          const SizedBox(height: 16),
          const Text(
            'Not Enough Coins',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            'This plan costs $required coins. Top up $shortfall more to continue.',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(children: [
            _statChip(label: 'Required', value: required, color: AppColors.primary),
            const SizedBox(width: 10),
            _statChip(label: 'You Have', value: current, color: AppColors.textMedium),
            const SizedBox(width: 10),
            _statChip(label: 'Short By', value: shortfall, color: AppColors.error),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                // Stay open behind the coin-packs route rather than popping
                // first — that way the purchase result (see CoinPacksScreen's
                // `returnToGoLive` handling) can be relayed on through this
                // sheet's own Navigator.pop, and show() above resolves it.
                final result = await Get.toNamed(AppRoutes.coinPacks, arguments: {'returnToGoLive': true});
                if (context.mounted) Navigator.pop(context, result == true);
              },
              icon: const Icon(Icons.bolt_rounded, size: 16),
              label: const Text('Recharge Now', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Get.toNamed(AppRoutes.redeemCode);
            },
            child: const Text(
              'Redeem a Code',
              style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({required String label, required int value, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text('$value', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textLight)),
        ]),
      ),
    );
  }
}
