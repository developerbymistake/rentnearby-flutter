import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_toast.dart';
import '../widgets/gradient_button.dart';

class PhoneVerifyScreen extends StatefulWidget {
  const PhoneVerifyScreen({super.key});
  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  final _auth = Get.find<AuthController>();

  bool _otpSent = false;
  bool _isChange = false;
  int _attempts = 0;
  int _resends = 0;
  static const int _maxAttempts = 3;
  static const int _maxResends = 2;

  late PinTheme _defaultTheme;
  late PinTheme _focusedTheme;
  late PinTheme _submittedTheme;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _isChange = args?['isChange'] as bool? ?? false;
    if (!_isChange) {
      // Verifying existing number — pre-fill
      final existing = _auth.user.value?.phoneNumber ?? '';
      if (existing.isNotEmpty) _phoneCtrl.text = existing;
    }
    // isChange == true → empty field, user enters new number
  }

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
    FocusScope.of(context).unfocus();

    // Guard: if changing number but entered same verified number
    if (_isChange &&
        phone == (_auth.user.value?.phoneNumber ?? '') &&
        (_auth.user.value?.isPhoneVerified ?? false)) {
      AppToast.warning('This is already your verified number. Enter a different number to change it.');
      return;
    }

    // Confirm dialog
    final confirmed = await _showConfirmDialog(phone);
    if (confirmed != true) return;

    final error = await _auth.sendPhoneOtp(phone);
    if (error == null) {
      setState(() => _otpSent = true);
    } else if (error == 'phone_claimed') {
      _showPhoneClaimedDialog(phone);
    } else {
      AppToast.error(error);
    }
  }

  Future<void> _resendOtp() async {
    if (_resends >= _maxResends) {
      AppToast.warning('Maximum resends reached. Please try a different number.');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    _otpCtrl.clear();
    final error = await _auth.sendPhoneOtp(phone);
    if (error == null) {
      setState(() => _resends++);
      AppToast.success('OTP resent to +91 $phone');
    } else if (error == 'phone_claimed') {
      _showPhoneClaimedDialog(phone);
    } else {
      AppToast.error(error);
    }
  }

  Future<void> _verifyOtp([String? pin]) async {
    final otp = pin ?? _otpCtrl.text;
    if (otp.length != 4) {
      AppToast.error('Enter the 4-digit OTP');
      return;
    }
    final ok = await _auth.verifyPhoneOtp(_phoneCtrl.text.trim(), otp);
    if (ok) {
      Get.back(result: true);
    } else {
      _attempts++;
      _otpCtrl.clear();
      if (_attempts >= _maxAttempts) {
        _showMaxAttemptsDialog();
      }
    }
  }

  Future<bool?> _showConfirmDialog(String phone) {
    return showDialog<bool>(
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
              const Text('Confirm your number',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text('We will send an OTP to',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: Text('+91 $phone',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1.5)),
              ),
              const SizedBox(height: 24),
              Row(children: [
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
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
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
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhoneClaimedDialog(String phone) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Number Not Available',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 10),
            Text('This number is already registered in our system.\n\nPlease use a different number.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _phoneCtrl.clear();
                  setState(() => _otpSent = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Use Different Number',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showMaxAttemptsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded, color: AppColors.error, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Too many attempts',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 10),
            const Text('Please go back and try again later.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Get.back();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Go Back',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
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
          _otpCtrl.clear();
          setState(() { _otpSent = false; _attempts = 0; });
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              height: screenH * 0.45,
              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            ),
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, top: 4),
                        child: IconButton(
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            Get.back();
                          },
                          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    SizedBox(height: screenH * 0.02),
                    Column(children: [
                      const Icon(Icons.phone_android_rounded, size: 40, color: Colors.white),
                      const SizedBox(height: 10),
                      Text(
                        _isChange ? 'Change Number' : 'Verify Mobile',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isChange ? 'Enter your new mobile number' : 'Required to post listings',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70),
                      ),
                    ]),
                    SizedBox(height: screenH * 0.04),
                    Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 10))],
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                          child: _otpSent ? _otpSection() : _phoneSection(),
                        ),
                      ),
                    const SizedBox(height: 24),
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
          Text(
            _isChange ? 'Enter your new number' : 'Enter your mobile number',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
          const SizedBox(height: 6),
          Text(
            _isChange ? 'Your old number will be replaced after verification' : 'You\'ll receive an OTP to verify',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
                child: const Text('+91',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
              hintText: 'Enter mobile number',
            ),
          ),
          const SizedBox(height: 24),
          Obx(() => GradientButton(
                onPressed: _auth.isLoading.value ? null : _sendOtp,
                isLoading: _auth.isLoading.value,
                label: 'Send OTP',
              )),
        ],
      );

  Widget _otpSection() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              _otpCtrl.clear();
              setState(() { _otpSent = false; _attempts = 0; });
            },
            child: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          const Text('Enter OTP',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        ]),
        const SizedBox(height: 6),
        Text('Sent to +91 ${_phoneCtrl.text}',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
        if (_attempts > 0) ...[
          const SizedBox(height: 6),
          Text('${_maxAttempts - _attempts} attempt${_maxAttempts - _attempts == 1 ? '' : 's'} remaining',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.warning)),
        ],
        const SizedBox(height: 28),
        Center(
          child: Pinput(
            length: 4,
            controller: _otpCtrl,
            focusNode: _otpFocus,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            defaultPinTheme: _defaultTheme,
            focusedPinTheme: _focusedTheme,
            submittedPinTheme: _submittedTheme,
            cursor: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(margin: const EdgeInsets.only(bottom: 9), width: 22, height: 2,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
            ]),
            onCompleted: (pin) => _verifyOtp(pin),
          ),
        ),
        const SizedBox(height: 28),
        Obx(() => GradientButton(
              onPressed: _auth.isLoading.value ? null : () => _verifyOtp(),
              isLoading: _auth.isLoading.value,
              label: 'Verify Number',
            )),
        const SizedBox(height: 16),
        Center(
          child: Obx(() => TextButton(
            onPressed: (_auth.isLoading.value || _resends >= _maxResends) ? null : _resendOtp,
            child: Text(
              _resends >= _maxResends ? 'No more resends' : 'Resend OTP (${_maxResends - _resends} left)',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: _resends >= _maxResends ? AppColors.textLight : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )),
        ),
      ],
    );
  }
}
