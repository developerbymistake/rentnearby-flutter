// Custom map pin widget — currently unused (using BitmapDescriptor.defaultMarkerWithHue instead)
// Kept for future custom marker implementation via BitmapDescriptor.fromAssetImage
import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class PriceMapPin extends StatelessWidget {
  final String price;
  const PriceMapPin({super.key, required this.price});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Text(price,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
        ),
        CustomPaint(size: const Size(12, 6), painter: _PinTailPainter()),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
