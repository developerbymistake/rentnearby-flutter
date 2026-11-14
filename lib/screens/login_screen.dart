import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../design/design.dart';
import '../design/extra/ext_auth.dart';
import '../utils/app_toast.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  final _phoneFocus = FocusNode();
  static final ListingTone _tone = ListingTone.indigo;
  static const double _cardHeight = 346;
  bool _phoneBad = false;
  final _auth = Get.find<AuthController>();
  late final AnimationController _enter =
      AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

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
  void initState() {
    super.initState();
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

    if (result == null) return;

    if (result == 'onboarding') {
      Get.toNamed(AppRoutes.onboarding, arguments: {'phone': _phone});
      return;
    }

    setState(() {
      _attempts++;
      _otpCtrl.clear();
    });
    AppToast.error(result);
    if (_attempts >= _maxAttempts) {
      _showMaxAttemptsDialog();
    } else {
      _otpFocus.requestFocus();
    }
  }

  void _showMaxAttemptsDialog() {
    Dialog3D.show<void>(
      context,
      barrierDismissible: false,
      builder: (_) => Dialog3D(
        tone: ListingTone.coral,
        art: ListingArt.key,
        title: 'Too Many Attempts',
        body: 'Please try again with your phone number.',
        primaryLabel: 'Go Back',
        onPrimary: () {
          Navigator.pop(context);
          setState(() {
            _otpSent = false;
            _otpCtrl.clear();
            _attempts = 0;
          });
        },
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String phone) => Dialog3D.show<bool>(
        context,
        builder: (dialogContext) => Dialog3D(
          tone: _tone,
          art: ListingArt.speechBalloon,
          title: 'Confirm your number',
          body: 'We will send an OTP via WhatsApp to',
          content: AuthDialogNumber(tone: _tone, text: '+91 $phone'),
          secondaryLabel: 'Edit',
          onSecondary: () => Navigator.pop(dialogContext, false),
          primaryLabel: 'Confirm',
          onPrimary: () {
            FocusScope.of(dialogContext).unfocus();
            _auth.isLoading.value = true;
            Navigator.pop(dialogContext, true);
          },
        ),
      );

  void _openLegal(Widget page) => Navigator.of(context).push(GetPageRoute<void>(
        page: () => page,
        customTransition: TemplateTransition(),
        transitionDuration: templateTransitionDuration,
      ));

  @override
  Widget build(BuildContext context) {
    return AuthHeroScaffold(
      hero: TemplateEntrance(
        animation: templateInterval(_enter, 0, 3),
        animationController: _enter,
        child: AuthHero(tone: _tone, art: ListingArt.panda, title: 'Bakhli', subtitle: 'Plan your next trip'),
      ),
      card: TemplateEntrance(
        animation: templateInterval(_enter, 2, 3),
        animationController: _enter,
        child: GateSwitcher(
          reverse: !_otpSent,
          child: _otpSent ? _buildOtpCard() : _buildPhoneCard(),
        ),
      ),
    );
  }

  Widget _buildPhoneCard() {
    return AuthCard(
      key: const ValueKey('phone'),
      fixedHeight: _cardHeight,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeading('Welcome to Bakhli', tone: _tone),
            const AuthCaption('Enter your mobile number to continue'),
          ],
        ),
        const AuthGap(16),
        AuthPillInput(
          tone: _tone,
          focusNode: _phoneFocus,
          bad: _phoneBad,
          prefix: AuthCountryCode(tone: _tone),
          child: TextFormField(
            controller: _phoneCtrl,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AuthPillInput.textStyle,
            cursorColor: _tone.g2,
            decoration: AuthPillInput.decoration('Mobile number'),
            onChanged: (v) {
              if (_phoneBad) setState(() => _phoneBad = false);
              if (v.length == 10) FocusManager.instance.primaryFocus?.unfocus();
            },
            onFieldSubmitted: (_) => _sendOtp(),
          ),
        ),
        const AuthGap(16),
        AuthAgreeRow(
          tone: _tone,
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v),
          onTerms: () => _openLegal(const TermsOfServiceScreen()),
          onPrivacy: () => _openLegal(const PrivacyPolicyScreen()),
        ),
        const AuthGap(16),
        Obx(() => GradientPillButton(
              tone: _tone,
              label: 'Send OTP',
              onTap: (_auth.isLoading.value || !_agreed) ? null : _sendOtp,
              loading: _auth.isLoading.value,
            )),
      ],
    );
  }

  Widget _buildOtpCard() {
    return AuthCard(
      key: const ValueKey('otp'),
      fixedHeight: _cardHeight,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeading(
              'Verify OTP',
              tone: _tone,
              onBack: () => setState(() {
                _otpSent = false;
                _otpCtrl.clear();
                _attempts = 0;
              }),
            ),
            const AuthCaption('OTP sent via WhatsApp to'),
            AuthNumberChip(tone: _tone, art: ListingArt.speechBalloon, text: '+91 $_phone'),
          ],
        ),
        const AuthGap(16),
        Center(
          child: Pinput(
            controller: _otpCtrl,
            focusNode: _otpFocus,
            length: 4,
            separatorBuilder: (_) => const SizedBox(width: 12),
            defaultPinTheme: _defaultTheme,
            focusedPinTheme: _focusedTheme,
            submittedPinTheme: _submittedTheme,
            cursor: AuthPins.cursor(_tone),
            hapticFeedbackType: HapticFeedbackType.lightImpact,
            autofillHints: const [AutofillHints.oneTimeCode],
            onCompleted: _verifyOtp,
          ),
        ),
        const AuthGap(16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(() => GradientPillButton(
                  tone: _tone,
                  label: 'Verify',
                  onTap: _auth.isLoading.value ? null : () => _verifyOtp(_otpCtrl.text),
                  loading: _auth.isLoading.value,
                )),
            Obx(() => AuthTextLink(
                  tone: _tone,
                  label: _resends >= _maxResends ? 'No more resends' : 'Resend OTP (${_maxResends - _resends} left)',
                  onTap: _auth.isLoading.value || _resends >= _maxResends ? null : _resendOtp,
                )),
          ],
        ),
      ],
    );
  }
}
