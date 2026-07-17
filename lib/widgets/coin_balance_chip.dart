import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/wallet_controller.dart';

/// Small reusable pill showing the user's live coin balance — Obx-wrapped
/// around WalletController.balance so it stays live across the app without
/// each call site needing its own listener. Tap navigates to the Coin Packs
/// (wallet home) screen. [color] lets callers on a dark gradient header
/// (e.g. My Rooms/My Plots) pass Colors.white; defaults to AppColors.primary
/// for light backgrounds (e.g. Profile).
class CoinBalanceChip extends StatelessWidget {
  final Color? color;
  final EdgeInsetsGeometry padding;

  const CoinBalanceChip({
    super.key,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.coinPacks),
      child: Obx(() {
        final wallet = Get.find<WalletController>();
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.monetization_on_rounded, size: 16, color: c),
              const SizedBox(width: 6),
              Text(
                wallet.isLoadingBalance.value && wallet.balance.value == 0
                    ? '...'
                    : '${wallet.balance.value}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
