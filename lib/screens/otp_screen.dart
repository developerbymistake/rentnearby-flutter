import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/gradient_button.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(4, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(4, (_) => FocusNode());
  final _auth = Get.find<AuthController>();
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      AppToast.error('Enter a valid 10-digit number');
      return;
    }
    final ok = await _auth.sendOtp(phone);
    if (ok) setState(() => _otpSent = true);
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 4) {
      AppToast.error('Enter the 4-digit OTP');
      return;
    }
    final ok = await _auth.verifyOtp(_phoneController.text.trim(), otp);
    if (ok) Get.offAllNamed(AppRoutes.main);
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty && index < 3) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient header
          Container(
            height: 300,
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Header
                  FadeInDown(
                    duration: const Duration(milliseconds: 600),
                    child: const Column(
                      children: [
                        Icon(Icons.location_on_rounded, size: 48, color: Colors.white),
                        SizedBox(height: 12),
                        Text('RentNearBy',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                        SizedBox(height: 4),
                        Text('Sign in to find rooms near you',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Colors.white70,
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Card
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.12),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: _otpSent ? _otpSection() : _phoneSection(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: Text('By continuing, you agree to our Terms of Service',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textHint,
                        )),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneSection() => Column(
        key: const ValueKey('phone'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter your mobile number',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              )),
          const SizedBox(height: 6),
          const Text('We\'ll send you a verification code',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
          const SizedBox(height: 28),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('+91',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
              hintText: '10-digit mobile number',
            ),
          ),
          const SizedBox(height: 28),
          Obx(() => GradientButton(
                onPressed: _auth.isLoading.value ? null : _sendOtp,
                isLoading: _auth.isLoading.value,
                label: 'Send OTP',
              )),
        ],
      );

  Widget _otpSection() => Column(
        key: const ValueKey('otp'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _otpSent = false),
                child: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Text('Verify OTP',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text('Sent to +91 ${_phoneController.text}',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) => _otpBox(i)),
          ),
          const SizedBox(height: 32),
          Obx(() => GradientButton(
                onPressed: _auth.isLoading.value ? null : _verifyOtp,
                isLoading: _auth.isLoading.value,
                label: 'Verify & Login',
              )),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: _sendOtp,
              child: const Text('Resend OTP',
                  style: TextStyle(fontFamily: 'Poppins', color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );

  Widget _otpBox(int index) => SizedBox(
        width: 58,
        height: 58,
        child: TextFormField(
          controller: _otpControllers[index],
          focusNode: _otpFocusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (v) => _onOtpChanged(v, index),
        ),
      );
}
