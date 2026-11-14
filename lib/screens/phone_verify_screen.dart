import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import '../controllers/auth_controller.dart';
import '../design/design.dart';
import '../design/extra/ext_auth.dart';
import '../utils/app_toast.dart';

class PhoneVerifyScreen extends StatefulWidget {
  const PhoneVerifyScreen({super.key});
  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen> with TickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  final _phoneFocus = FocusNode();
  static final ListingTone _tone = ListingTone.indigo;
  bool _phoneBad = false;
  final _auth = Get.find<AuthController>();
  late final AnimationController _enter =
      AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

  bool _otpSent = false;
  bool _isChange = false;
  int _attempts = 0;
  int _resends = 0;
  static const int _maxAttempts = 3;
  static const int _maxResends = 1;

  late PinTheme _defaultTheme;
  late PinTheme _focusedTheme;
  late PinTheme _submittedTheme;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _isChange = args?['isChange'] as bool? ?? false;
    if (!_isChange) {
      final existing = _auth.user.value?.phoneNumber ?? '';
      if (existing.isNotEmpty) _phoneCtrl.text = existing;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KitMotion.reduce(context)) {
      _enter.value = 1;
    } else if (!_enter.isAnimating && _enter.value == 0) {
      _enter.forward();
    }
    final boxSize = AuthPins.boxSize(context);
    _defaultTheme = AuthPins.base(boxSize);
    _focusedTheme = AuthPins.focused(_tone, boxSize);
    _submittedTheme = AuthPins.submitted(_tone, boxSize);
  }

  @override
  void dispose() {
    _enter.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      setState(() => _phoneBad = true);
      AppToast.error('Enter a valid 10-digit number');
      return;
    }
    FocusScope.of(context).unfocus();

    if (_isChange &&
        phone == (_auth.user.value?.phoneNumber ?? '') &&
        (_auth.user.value?.isPhoneVerified ?? false)) {
      AppToast.warning('This is already your verified number. Enter a different number to change it.');
      return;
    }

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
      await _showSuccessDialog();
      Get.back(result: true);
    } else {
      _attempts++;
      _otpCtrl.clear();
      if (_attempts >= _maxAttempts) {
        _showMaxAttemptsDialog();
      }
    }
  }

  Future<void> _showSuccessDialog() {
    return Dialog3D.show<void>(
      context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog3D(
        tone: ListingTone.forest,
        art: ListingArt.star,
        title: _isChange ? 'Number Changed!' : 'Phone Verified!',
        body: _isChange
            ? 'Your mobile number has been updated to +91 ${_phoneCtrl.text}. All future OTPs will be sent to this number.'
            : 'Your mobile number +91 ${_phoneCtrl.text} is now verified. You can post listings on RentNearby.',
        primaryLabel: 'Continue',
        onPrimary: () => Navigator.pop(dialogContext),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String phone) {
    return Dialog3D.show<bool>(
      context,
      builder: (dialogContext) => Dialog3D(
        tone: _tone,
        art: ListingArt.speechBalloon,
        title: 'Confirm your number',
        body: 'We will send an OTP on WhatsApp to',
        content: AuthDialogNumber(tone: _tone, text: '+91 $phone', viaArt: ListingArt.speechBalloon, viaText: 'via WhatsApp'),
        secondaryLabel: 'Edit',
        onSecondary: () => Navigator.pop(dialogContext, false),
        primaryLabel: 'Confirm',
        onPrimary: () => Navigator.pop(dialogContext, true),
      ),
    );
  }

  void _showPhoneClaimedDialog(String phone) {
    Dialog3D.show<void>(
      context,
      builder: (dialogContext) => Dialog3D(
        tone: ListingTone.coral,
        art: ListingArt.pushpin,
        title: 'Number Not Available',
        body: 'This number is already registered in our system.\n\nPlease use a different number.',
        primaryLabel: 'Use Different Number',
        onPrimary: () {
          Navigator.pop(dialogContext);
          _phoneCtrl.clear();
          setState(() => _otpSent = false);
        },
      ),
    );
  }

  void _showMaxAttemptsDialog() {
    Dialog3D.show<void>(
      context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog3D(
        tone: ListingTone.coral,
        art: ListingArt.key,
        title: 'Too many attempts',
        body: 'Please go back and try again later.',
        primaryLabel: 'Go Back',
        onPrimary: () {
          Navigator.pop(dialogContext);
          Get.back();
        },
      ),
    );
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_otpSent) {
      _otpCtrl.clear();
      setState(() {
        _otpSent = false;
        _attempts = 0;
      });
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_otpSent,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _otpSent) {
          _otpCtrl.clear();
          setState(() {
            _otpSent = false;
            _attempts = 0;
          });
        }
      },
      child: AuthHeroScaffold(
        hero: TemplateEntrance(
          animation: templateInterval(_enter, 0, 2),
          animationController: _enter,
          child: AuthHero(
            tone: _tone,
            art: ListingArt.key,
            title: _isChange ? 'Change Number' : 'Verify Mobile',
            subtitle: _isChange ? 'Enter your new mobile number' : 'Required to post listings',
            smallTitle: true,
            onBack: _back,
          ),
        ),
        card: TemplateEntrance(
          animation: templateInterval(_enter, 1, 2),
          animationController: _enter,
          child: GateSwitcher(
            reverse: !_otpSent,
            child: _otpSent ? _otpSection() : _phoneSection(),
          ),
        ),
      ),
    );
  }

  Widget _phoneSection() => AuthCard(
        key: const ValueKey('phone'),
        children: [
          AuthHeading(_isChange ? 'Enter your new number' : 'Enter your mobile number', tone: _tone),
          AuthCaption(
            _isChange ? 'Your old number will be replaced after verification' : 'You\'ll receive an OTP on WhatsApp',
            lines: 2,
          ),
          const AuthGap(28),
          AuthPillInput(
            tone: _tone,
            focusNode: _phoneFocus,
            bad: _phoneBad,
            prefix: AuthCountryCode(tone: _tone),
            child: TextFormField(
              controller: _phoneCtrl,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              style: AuthPillInput.textStyle,
              cursorColor: _tone.g2,
              decoration: AuthPillInput.decoration('Enter mobile number'),
              onChanged: (_) {
                if (_phoneBad) setState(() => _phoneBad = false);
              },
            ),
          ),
          const AuthGap(24),
          Obx(() => GradientPillButton(
                tone: _tone,
                label: 'Send OTP',
                onTap: _auth.isLoading.value ? null : _sendOtp,
                loading: _auth.isLoading.value,
              )),
        ],
      );

  Widget _otpSection() {
    final left = _maxAttempts - _attempts;
    return AuthCard(
      key: const ValueKey('otp'),
      children: [
        AuthHeading(
          'Enter OTP',
          tone: _tone,
          onBack: () {
            FocusScope.of(context).unfocus();
            _otpCtrl.clear();
            setState(() {
              _otpSent = false;
              _attempts = 0;
            });
          },
        ),
        AuthCaption('Sent to +91 ${_phoneCtrl.text}'),
        const AuthArtLine(art: ListingArt.speechBalloon, text: 'Check your WhatsApp for the OTP'),
        AuthWarnLine(_attempts > 0 ? '$left attempt${left == 1 ? '' : 's'} remaining' : null),
        const AuthGap(20),
        Center(
          child: Pinput(
            length: 4,
            controller: _otpCtrl,
            focusNode: _otpFocus,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            separatorBuilder: (_) => const SizedBox(width: 12),
            defaultPinTheme: _defaultTheme,
            focusedPinTheme: _focusedTheme,
            submittedPinTheme: _submittedTheme,
            cursor: AuthPins.cursor(_tone),
            onCompleted: (pin) => _verifyOtp(pin),
          ),
        ),
        const AuthGap(24),
        Obx(() => GradientPillButton(
              tone: _tone,
              label: 'Verify Number',
              onTap: _auth.isLoading.value ? null : () => _verifyOtp(),
              loading: _auth.isLoading.value,
            )),
        Obx(() => AuthTextLink(
              tone: _tone,
              label: _resends >= _maxResends ? 'No more resends' : 'Resend OTP (${_maxResends - _resends} left)',
              onTap: (_auth.isLoading.value || _resends >= _maxResends) ? null : _resendOtp,
            )),
      ],
    );
  }
}
