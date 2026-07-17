import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Shown after a successful POST /{listings|plots}/{id}/go-live — the coin-
/// economy replacement for the old razorpay PaymentSuccessDialog. Covers
/// both a paid plan activation ([coinsSpent] > 0) and a free reactivation
/// within an already-paid window ([coinsSpent] == 0, [planType] null).
class GoLiveSuccessDialog extends StatefulWidget {
  final bool isPlot;
  final String? planType;
  final int coinsSpent;
  final DateTime? validUntil;
  final VoidCallback onDismiss;

  const GoLiveSuccessDialog({
    required this.isPlot,
    this.planType,
    this.coinsSpent = 0,
    this.validUntil,
    required this.onDismiss,
    super.key,
  });

  @override
  State<GoLiveSuccessDialog> createState() => _GoLiveSuccessDialogState();
}

class _GoLiveSuccessDialogState extends State<GoLiveSuccessDialog> with TickerProviderStateMixin {
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

  int? get _daysLeft {
    final v = widget.validUntil;
    if (v == null) return null;
    return v.toUtc().difference(DateTime.now().toUtc()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final isFree = widget.coinsSpent == 0;
    final color = widget.isPlot ? const Color(0xFF92400E) : AppColors.success;
    final lightColor = widget.isPlot ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5);

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
                decoration: BoxDecoration(color: lightColor, shape: BoxShape.circle),
                child: Icon(Icons.rocket_launch_rounded, size: 34, color: color),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.isPlot ? 'Plot is Live!' : 'Room is Live!',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, fontFamily: 'Poppins', color: AppColors.textDark),
            ),
            if (widget.planType != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: lightColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${widget.planType} Plan',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: color),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(children: [
              _statBox(
                icon: Icons.monetization_on_rounded,
                label: 'Coins Spent',
                value: isFree ? 'FREE' : '${widget.coinsSpent}',
                color: color,
                lightColor: lightColor,
              ),
              const SizedBox(width: 10),
              _statBox(
                icon: Icons.event_available_rounded,
                label: 'Valid For',
                value: _daysLeft != null ? '$_daysLeft days' : '—',
                color: color,
                lightColor: lightColor,
              ),
            ]),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _progressCtrl,
              builder: (_, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1 - _progressCtrl.value,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(color),
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
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color lightColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(color: lightColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 5),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textLight, fontFamily: 'Poppins', fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Poppins', color: color)),
          ],
        ),
      ),
    );
  }
}
