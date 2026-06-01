import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/gradient_button.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  final _auth = Get.find<AuthController>();

  bool _otpSent = false;
  bool _agreed = false;
  String _phone = '';
  int _attempts = 0;
  int _resends = 0;
  static const int _maxAttempts = 3;
  static const int _maxResends = 1;

  late PinTheme _defaultTheme;
  late PinTheme _focusedTheme;
  late PinTheme _submittedTheme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final boxSize = ((MediaQuery.of(context).size.width - 56 - 36) / 4).clamp(56.0, 72.0);
    _defaultTheme = PinTheme(
      width: boxSize, height: boxSize + 8,
      textStyle: TextStyle(fontFamily: 'Poppins', fontSize: boxSize * 0.38, fontWeight: FontWeight.w700, color: AppColors.primary),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider, width: 1.5)),
    );
    _focusedTheme = _defaultTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
    );
    _submittedTheme = _defaultTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      AppToast.error('Enter a valid 10-digit number');
      return;
    }
    if (!_agreed) {
      AppToast.warning('Please accept the Terms of Service and Privacy Policy');
      return;
    }
    FocusScope.of(context).unfocus();

    final confirmed = await _showConfirmDialog(phone);
    if (confirmed != true || !mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final ok = await _auth.sendLoginOtp(phone);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _phone = phone;
        _otpSent = true;
        _attempts = 0;
        _resends = 0;
        _otpCtrl.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _otpFocus.requestFocus());
    }
  }

  Future<void> _resendOtp() async {
    if (_resends >= _maxResends) {
      AppToast.warning('Maximum resends reached. Please use a different number.');
      return;
    }
    _otpCtrl.clear();
    final ok = await _auth.sendLoginOtp(_phone);
    if (!mounted) return;
    if (ok) setState(() => _resends++);
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length != 4) return;
    FocusScope.of(context).unfocus();

    final result = await _auth.verifyLoginOtp(_phone, otp);
    if (!mounted) return;

    if (result == null) return; // logged in, navigated

    if (result == 'onboarding') {
      Get.toNamed(AppRoutes.onboarding, arguments: {'phone': _phone});
      return;
    }

    // Error
    setState(() {
      _attempts++;
      _otpCtrl.clear();
    });
    AppToast.error(result);
    if (_attempts >= _maxAttempts) _showMaxAttemptsDialog();
    else _otpFocus.requestFocus();
  }

  void _showMaxAttemptsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Too Many Attempts', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text('Please try again with your phone number.', style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              setState(() { _otpSent = false; _otpCtrl.clear(); _attempts = 0; });
            },
            child: const Text('Go Back', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String phone) => showDialog<bool>(
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
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
              child: const Icon(Icons.chat_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),
            const Text('Confirm your number', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text('We will send an OTP via WhatsApp to', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Text('+91 $phone', style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1.5)),
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
                    child: const Text('Edit', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                    child: ElevatedButton(
                      onPressed: () {
                          FocusScope.of(context).unfocus();
                          _auth.isLoading.value = true;
                          Navigator.pop(context, true);
                        },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Confirm', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Stack(
        children: [
          Container(height: screenH * 0.45, decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                children: [
                  SizedBox(height: screenH * 0.05),
                  const Column(
                    children: [
                      Icon(Icons.location_on_rounded, size: 44, color: Colors.white),
                      SizedBox(height: 10),
                      Text('Bakhli', style: TextStyle(fontFamily: 'Poppins', fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Discover your new address', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                  SizedBox(height: screenH * 0.08),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _otpSent ? _buildOtpCard() : _buildPhoneCard(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneCard() {
    return Container(
      key: const ValueKey('phone'),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome to Bakhli', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 4),
          const Text('Enter your mobile number to continue', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
          const SizedBox(height: 24),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Mobile number',
              hintStyle: const TextStyle(fontFamily: 'Poppins', color: AppColors.textHint, fontWeight: FontWeight.w400),
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: const Text('+91', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
            onChanged: (v) {
              if (v.length == 10) FocusManager.instance.primaryFocus?.unfocus();
            },
            onFieldSubmitted: (_) => _sendOtp(),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24, height: 24,
                child: Checkbox(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight, height: 1.5),
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => Get.to(() => const TermsOfServiceScreen(), transition: Transition.rightToLeft, duration: const Duration(milliseconds: 300)),
                            child: const Text('Terms of Service', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: AppColors.primary)),
                          ),
                        ),
                        const TextSpan(text: ' and '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => Get.to(() => const PrivacyPolicyScreen(), transition: Transition.rightToLeft, duration: const Duration(milliseconds: 300)),
                            child: const Text('Privacy Policy', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: AppColors.primary)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Obx(() => GradientButton(
            label: 'Send OTP',
            onPressed: (_auth.isLoading.value || !_agreed) ? null : _sendOtp,
            isLoading: _auth.isLoading.value,
          )),
        ],
      ),
    );
  }

  Widget _buildOtpCard() {
    return Container(
      key: const ValueKey('otp'),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() { _otpSent = false; _otpCtrl.clear(); _attempts = 0; }),
                child: const Icon(Icons.arrow_back_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Verify OTP', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 8),
          Text('OTP sent via WhatsApp to +91 $_phone', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
          const SizedBox(height: 28),
          Center(
            child: Pinput(
              controller: _otpCtrl,
              focusNode: _otpFocus,
              length: 4,
              defaultPinTheme: _defaultTheme,
              focusedPinTheme: _focusedTheme,
              submittedPinTheme: _submittedTheme,
              hapticFeedbackType: HapticFeedbackType.lightImpact,
              autofillHints: const [AutofillHints.oneTimeCode],
              onCompleted: _verifyOtp,
            ),
          ),
          const SizedBox(height: 24),
          Obx(() => GradientButton(
            label: 'Verify',
            onPressed: _auth.isLoading.value ? null : () => _verifyOtp(_otpCtrl.text),
            isLoading: _auth.isLoading.value,
          )),
          const SizedBox(height: 12),
          Center(
            child: Obx(() => TextButton(
              onPressed: _auth.isLoading.value || _resends >= _maxResends ? null : _resendOtp,
              child: Text(
                _resends >= _maxResends ? 'No more resends' : 'Resend OTP (${_maxResends - _resends} left)',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _resends >= _maxResends ? AppColors.textHint : AppColors.primary,
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }
}
