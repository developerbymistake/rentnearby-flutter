import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'credit_icon.dart';

/// Shown after a POST /{listings|plots}/{id}/go-live that submitted the
/// listing for admin review instead of activating it — a first-time (or
/// never-approved) Go-Live. Sibling to GoLiveSuccessDialog, not a
/// parameterization of it: this outcome never activates the listing, so it
/// has no "Valid For" stat and no plan-chip (the plan is still just spent
/// credits, shown only in the "paid" case).
class GoLiveSubmittedDialog extends StatefulWidget {
  final bool isPlot;
  final int creditsSpent;
  final VoidCallback onDismiss;

  const GoLiveSubmittedDialog({
    required this.isPlot,
    this.creditsSpent = 0,
    required this.onDismiss,
    super.key,
  });

  @override
  State<GoLiveSubmittedDialog> createState() => _GoLiveSubmittedDialogState();
}

class _GoLiveSubmittedDialogState extends State<GoLiveSubmittedDialog> with TickerProviderStateMixin {
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
    widget.onDismiss();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFree = widget.creditsSpent == 0;
    const color = AppColors.warning;
    const lightColor = Color(0xFFFFFBEB);

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
                child: const Icon(Icons.hourglass_top_rounded, size: 34, color: color),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Submitted for Review',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, fontFamily: 'Poppins', color: AppColors.textDark),
            ),
            const SizedBox(height: 10),
            Text(
              'Your ${widget.isPlot ? 'Plot' : 'Room'} has been submitted for review. '
              "We'll notify you once it's approved.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textLight, fontFamily: 'Poppins', height: 1.4),
            ),
            if (!isFree) ...[
              const SizedBox(height: 18),
              _statBox(
                icon: const CreditIcon(size: 16),
                label: 'Credits Spent',
                value: '${widget.creditsSpent}',
                color: color,
                lightColor: lightColor,
              ),
            ],
            const SizedBox(height: 18),
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
                child: Text(
                  widget.isPlot ? 'My Plots' : 'My Rooms',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox({
    required Widget icon,
    required String label,
    required String value,
    required Color color,
    required Color lightColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(color: lightColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Poppins', color: color)),
        ],
      ),
    );
  }
}
