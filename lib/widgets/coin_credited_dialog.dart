import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'coin_icon.dart';

/// "N coins added to your wallet" — the coin-purchase/redeem-code equivalent
/// of the old PaymentSuccessDialog, minus the plan-shaped fields (planType/
/// days/maxRooms) that don't apply to a plain coin credit. Shares the same
/// scale-in check + auto-dismiss-countdown visual language as the original.
class CoinCreditedDialog extends StatefulWidget {
  final int coinsCredited;
  final int newBalance;
  final String title;
  final VoidCallback? onDismiss;
  final String continueLabel;

  const CoinCreditedDialog({
    required this.coinsCredited,
    required this.newBalance,
    this.title = 'Coins Added!',
    this.onDismiss,
    this.continueLabel = 'Done',
    super.key,
  });

  @override
  State<CoinCreditedDialog> createState() => _CoinCreditedDialogState();
}

class _CoinCreditedDialogState extends State<CoinCreditedDialog> with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _progressCtrl;
  int _seconds = 3;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();

    _progressCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();
    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) _dismiss();
    });

    for (int i = 3; i > 0; i--) {
      Future.delayed(Duration(seconds: 4 - i), () {
        if (mounted) setState(() => _seconds = i - 1);
      });
    }
  }

  void _dismiss() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    widget.onDismiss?.call();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = AppColors.success;
    const lightColor = Color(0xFFECFDF5);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
              child: Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(color: lightColor, shape: BoxShape.circle),
                child: const CoinIcon(size: 38),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, fontFamily: 'Poppins', color: AppColors.textDark),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: lightColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Text(
                '+${widget.coinsCredited} coins',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: color),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: lightColor, borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                const Text('New Balance', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const CoinIcon(size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.newBalance}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: color),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _progressCtrl,
              builder: (_, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1 - _progressCtrl.value,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation(color),
                  minHeight: 3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Closing in ${_seconds}s', style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontFamily: 'Poppins')),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _dismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(widget.continueLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
