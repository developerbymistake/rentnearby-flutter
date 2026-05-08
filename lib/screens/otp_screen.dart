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
  bool _agreed = false;

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      AppToast.error('Enter a valid 10-digit number');
      return;
    }
    FocusScope.of(context).unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirm your number',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              'We will send an OTP to',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+91 $phone',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Is this the correct number?',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Edit', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Yes, Send OTP', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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

  void _showTerms() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 4),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Terms of Service',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMedium),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _termSection(
                      Icons.home_rounded,
                      'What RentNearBy Does',
                      'RentNearBy connects people looking for rental rooms with room owners. Our goal is to make finding a home near you simple and transparent.',
                    ),
                    _termSection(
                      Icons.visibility_rounded,
                      'Your Information is Publicly Visible',
                      'When you post a room, the details you provide — photos, address, rent amount, and your contact number — are visible to all users of the app. This is how tenants can reach you directly. By posting, you agree that this information may be seen by anyone using RentNearBy.',
                    ),
                    _termSection(
                      Icons.phone_rounded,
                      'Your Contact Number',
                      'Your mobile number is used to log in and is displayed on your listings so tenants can contact you. Since it is publicly visible on your listings, you should only register with a number you are comfortable sharing.',
                    ),
                    _termSection(
                      Icons.location_on_rounded,
                      'Location Access',
                      'RentNearBy uses your device location only to show rooms near you. Your live location is not stored on our servers or shared with other users.',
                    ),
                    _termSection(
                      Icons.person_rounded,
                      'Your Responsibility',
                      'You are responsible for the accuracy of any information you post. Room details, photos, and pricing must be truthful. Misleading listings may be removed. RentNearBy is a platform only and is not responsible for any disputes between tenants and room owners.',
                    ),
                    _termSection(
                      Icons.security_rounded,
                      'Your Agreement',
                      'By using RentNearBy, you confirm that the information you provide is accurate and that you consent to your listing details being publicly visible to all users. You can delete your listing at any time from the My Rooms section.',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'These terms keep the platform safe and transparent for both tenants and room owners.',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom button
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('Got it, Continue',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _termSection(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
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
    final screenH = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Stack(
        children: [
          // Gradient header — scales with screen height
          Container(
            height: screenH * 0.42,
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: screenH * 0.05),
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
                  SizedBox(height: screenH * 0.04),
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
                            color: AppColors.primary.withValues(alpha: 0.12),
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
                  const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          // Mandatory checkbox
          GestureDetector(
            onTap: () => setState(() => _agreed = !_agreed),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22, height: 22,
                  child: Checkbox(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v ?? false),
                    activeColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: AppColors.textLight, width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _showTerms,
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium, height: 1.5),
                        children: [
                          const TextSpan(text: 'I have read and agree to the '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Obx(() => GradientButton(
                onPressed: (_agreed && !_auth.isLoading.value) ? _sendOtp : null,
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
                onTap: () {
                  FocusScope.of(context).unfocus();
                  for (final c in _otpControllers) { c.clear(); }
                  setState(() => _otpSent = false);
                },
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
