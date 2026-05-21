import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class PaymentSuccessDialog extends StatefulWidget {
  final String planType;
  final int daysValid;
  final int maxRooms;
  final int maxPlots;
  final bool isPlot;
  final VoidCallback onDismiss;

  const PaymentSuccessDialog({
    required this.planType,
    required this.daysValid,
    required this.maxRooms,
    this.maxPlots = 0,
    this.isPlot = false,
    required this.onDismiss,
    Key? key,
  }) : super(key: key);

  @override
  State<PaymentSuccessDialog> createState() => _PaymentSuccessDialogState();
}

class _PaymentSuccessDialogState extends State<PaymentSuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _progressCtrl;
  int _seconds = 3;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _dismiss();
      }
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
    final isPaid = widget.planType == 'PAID';
    final color = isPaid
        ? AppColors.primary
        : (widget.isPlot ? const Color(0xFF92400E) : const Color(0xFF10B981));
    final lightColor = isPaid
        ? const Color(0xFFEFF6FF)
        : (widget.isPlot ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5));

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
              scale: CurvedAnimation(
                parent: _scaleCtrl,
                curve: Curves.elasticOut,
              ),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(color: lightColor, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 38, color: color),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isPaid ? 'Payment Successful!' : 'Plan Activated!',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: lightColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Text(
                '${widget.planType} Plan',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _statBox(
                  icon: Icons.calendar_today_rounded,
                  label: 'Duration',
                  value: '${widget.daysValid} days',
                  color: color,
                  lightColor: lightColor,
                ),
                const SizedBox(width: 10),
                widget.isPlot
                    ? _statBox(
                        icon: Icons.landscape_rounded,
                        label: 'Plots',
                        value: '${widget.maxPlots} plot${widget.maxPlots > 1 ? 's' : ''}',
                        color: color,
                        lightColor: lightColor,
                      )
                    : _statBox(
                        icon: Icons.home_rounded,
                        label: 'Rooms',
                        value: '${widget.maxRooms} room${widget.maxRooms > 1 ? 's' : ''}',
                        color: color,
                        lightColor: lightColor,
                      ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: lightColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 7, color: color),
                  const SizedBox(width: 7),
                  Text(
                    widget.isPlot ? 'Plot is live' : 'Listing is live',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _progressCtrl,
              builder: (_, __) => ClipRRect(
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
            Text(
              'Closing in ${_seconds}s',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _dismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Explore',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
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
        decoration: BoxDecoration(
          color: lightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textLight,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
