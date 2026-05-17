import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class PaymentSuccessDialog extends StatefulWidget {
  final String planType;
  final int daysValid;
  final int maxRooms;
  final VoidCallback onDismiss;

  const PaymentSuccessDialog({
    required this.planType,
    required this.daysValid,
    required this.maxRooms,
    required this.onDismiss,
    Key? key,
  }) : super(key: key);

  @override
  State<PaymentSuccessDialog> createState() => _PaymentSuccessDialogState();
}

class _PaymentSuccessDialogState extends State<PaymentSuccessDialog>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _countdownController;
  int _countdownSeconds = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _countdownController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _controller.forward();

    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          Navigator.pop(context);
          widget.onDismiss();
        }
      }
    });

    _countdownController.forward();

    // Manual countdown for display
    for (int i = 3; i > 0; i--) {
      Future.delayed(Duration(seconds: 4 - i), () {
        if (mounted) {
          setState(() => _countdownSeconds = i - 1);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color planColor = widget.planType == 'FREE' ? Colors.green : Colors.blue;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: planColor.withOpacity(0.3),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [planColor, planColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: Tween<double>(begin: 0, end: 1).animate(
                        CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.planType == 'FREE' ? 'Plan Activated!' : 'Payment Successful!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Text(
                      'Your ${widget.planType} Plan is Live!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: planColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: planColor.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Valid For',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${widget.daysValid} days',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Poppins',
                                        color: planColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1.5,
                                height: 60,
                                color: planColor.withOpacity(0.2),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rooms Allowed',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${widget.maxRooms} room${widget.maxRooms > 1 ? 's' : ''}',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Poppins',
                                        color: planColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.green),
                                const SizedBox(width: 8),
                                Text(
                                  'Your listing is now live!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Closing in ${_countdownSeconds}s',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDismiss();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: planColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.home_rounded, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Go to My Listings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
