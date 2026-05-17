import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:animate_do/animate_do.dart';
import 'package:pinput/pinput.dart';
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
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  final _auth = Get.find<AuthController>();
  bool _otpSent = false;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
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
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_android_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirm your number',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'We will send an OTP to',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+91 $phone',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Is this the correct number?',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Edit',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Confirm',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    final ok = await _auth.sendOtp(phone);
    if (ok) setState(() => _otpSent = true);
  }

  Future<void> _resendOtp() async {
    final phone = _phoneController.text.trim();
    FocusScope.of(context).unfocus();
    _otpController.clear();
    final ok = await _auth.sendOtp(phone);
    if (ok) AppToast.success('OTP resent to +91 $phone');
  }

  Future<void> _verifyOtp([String? pin]) async {
    final otp = pin ?? _otpController.text;
    if (otp.length != 4) {
      AppToast.error('Enter the 4-digit OTP');
      return;
    }
    final ok = await _auth.verifyOtp(_phoneController.text.trim(), otp);
    if (ok) Get.offAllNamed(AppRoutes.main);
  }

  Future<bool> _showTerms() async {
    final result = await showModalBottomSheet<bool>(
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
                      'What Bakhli Does',
                      'Bakhli is a room listing platform built to help people find rental rooms near them — faster and without the hassle of brokers. We simply connect room owners with people looking for a place to stay. Our goal is to make the process easier, more direct, and more transparent for everyone.',
                    ),
                    _termSection(
                      Icons.handshake_rounded,
                      'Our Role & Limitations',
                      'Bakhli serves as a connecting platform and directory — we are not a rental agent, broker, or guarantor of any kind. While we strive to provide the best possible experience, we are unable to guarantee that a listed room will be rented or that every user will find a suitable room. Any arrangement, agreement, or interaction between a room owner and a tenant is entirely between those two individuals. Bakhli is not a party to any such arrangement and holds no responsibility for its outcome.',
                    ),
                    _termSection(
                      Icons.visibility_rounded,
                      'Your Information is Publicly Visible',
                      'When you post a room, the details you provide — photos, address, rent amount, and your contact number — are visible to all users of the app. This is how tenants can reach you directly. By posting, you agree that this information may be seen by anyone using Bakhli.',
                    ),
                    _termSection(
                      Icons.phone_rounded,
                      'Your Contact Number',
                      'Your mobile number is used to log in and is displayed on your listings so tenants can contact you directly. Since it is publicly visible, we kindly request that you register with a number you are comfortable sharing.',
                    ),
                    _termSection(
                      Icons.location_on_rounded,
                      'Location Access',
                      'Bakhli uses your device location only to show rooms near you. Your live location is never stored on our servers or shared with other users.',
                    ),
                    _termSection(
                      Icons.fact_check_rounded,
                      'Listing Accuracy & Our Limits',
                      'All listings on Bakhli are created and managed by individual users. While we encourage honesty and accuracy, we are not in a position to independently verify every listing. Bakhli and its team will not be held responsible for any inaccurate, misleading, or fraudulent content submitted by users. We kindly request that you report any suspicious listing through the app so we can take appropriate action.',
                    ),
                    _termSection(
                      Icons.security_rounded,
                      'Your Agreement',
                      'By using Bakhli, you confirm that the information you provide is accurate and that you consent to your listing details being visible to all users of the platform. You may remove your listing at any time from the My Rooms section. Continued use of the platform indicates your acceptance of these terms.',
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
                              'Bakhli is built to help people find and list rooms easily. It does not make any guarantees or claims of any kind.',
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
                onTap: () => Navigator.pop(context, true),
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
    return result == true;
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

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return PopScope(
      canPop: !_otpSent,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _otpSent) {
          FocusScope.of(context).unfocus();
          _otpController.clear();
          setState(() => _otpSent = false);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Gradient header — scales with screen height
            Container(
              height: screenH * 0.52,
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            ),
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: screenH * 0.06),
                    // Header
                    FadeInDown(
                      duration: const Duration(milliseconds: 600),
                      child: const Column(
                        children: [
                          Icon(Icons.location_on_rounded, size: 48, color: Colors.white),
                          SizedBox(height: 12),
                          Text('Bakhli',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 36,
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
                    SizedBox(height: screenH * 0.12),
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
              hintText: 'Enter mobile number',
            ),
          ),
          const SizedBox(height: 20),
          // Mandatory checkbox
          GestureDetector(
            onTap: () async {
              if (_agreed) {
                setState(() => _agreed = false);
              } else {
                final ok = await _showTerms();
                if (ok && mounted) setState(() => _agreed = true);
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22, height: 22,
                  child: Checkbox(
                    value: _agreed,
                    onChanged: (v) async {
                      if (v == true) {
                        final ok = await _showTerms();
                        if (ok && mounted) setState(() => _agreed = true);
                      } else {
                        setState(() => _agreed = false);
                      }
                    },
                    activeColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    side: const BorderSide(color: AppColors.textLight, width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final ok = await _showTerms();
                      if (ok && mounted) setState(() => _agreed = true);
                    },
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium, height: 1.5),
                        children: [
                          const TextSpan(text: 'I have read and agree to the\n'),
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

  Widget _otpSection() {
    final screenW = MediaQuery.of(context).size.width;
    final boxSize = ((screenW - 56 - 36) / 4).clamp(56.0, 72.0);

    final defaultTheme = PinTheme(
      width: boxSize,
      height: boxSize + 8,
      textStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: boxSize * 0.38,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
    );

    final focusedTheme = defaultTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
    );

    final submittedTheme = defaultTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
      ),
    );

    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                _otpController.clear();
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
        const SizedBox(height: 28),
        Center(
          child: Pinput(
            length: 4,
            controller: _otpController,
            focusNode: _otpFocusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            defaultPinTheme: defaultTheme,
            focusedPinTheme: focusedTheme,
            submittedPinTheme: submittedTheme,
            cursor: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  width: 22, height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            onCompleted: (pin) => _verifyOtp(pin),
          ),
        ),
        const SizedBox(height: 28),
        Obx(() => GradientButton(
              onPressed: _auth.isLoading.value ? null : () => _verifyOtp(),
              isLoading: _auth.isLoading.value,
              label: 'Verify & Login',
            )),
        const SizedBox(height: 16),
        Center(
          child: Obx(() => TextButton(
            onPressed: _auth.isLoading.value ? null : _resendOtp,
            child: const Text('Resend OTP',
                style: TextStyle(fontFamily: 'Poppins', color: AppColors.primary, fontWeight: FontWeight.w600)),
          )),
        ),
      ],
    );
  }
}
