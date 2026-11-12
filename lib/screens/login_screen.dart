import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../design/design.dart';
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
    final boxSize = ((MediaQuery.of(context).size.width - 56 - 36) / 4).clamp(56.0, 72.0);
    _defaultTheme = GatePinThemes.base(boxSize);
    _focusedTheme = GatePinThemes.focused(boxSize);
    _submittedTheme = GatePinThemes.submitted(boxSize);
  }

  @override
  void dispose() {
    _enter.dispose();
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GateDialog(
        glyph: Icons.lock_outline_rounded,
        gradient: TripEntryStyle.rose,
        title: 'Too Many Attempts',
        body: 'Please try again with your phone number.',
        actions: [
          GateButton(
            label: 'Go Back',
            height: 48,
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _otpSent = false;
                _otpCtrl.clear();
                _attempts = 0;
              });
            },
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String phone) => showDialog<bool>(
        context: context,
        barrierColor: GateKit.scrim,
        builder: (dialogContext) => GateDialog(
          asset: TravelIcon.chat,
          title: 'Confirm your number',
          body: 'We will send an OTP via WhatsApp to',
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(color: FitnessAppTheme.background, borderRadius: CardRadius.chip),
            child: Text(
              '+91 $phone',
              style: FitnessAppTheme.title.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: FitnessAppTheme.nearlyDarkBlue,
                letterSpacing: 1.5,
              ),
            ),
          ),
          horizontalActions: true,
          actions: [
            GateOutlineButton(label: 'Edit', height: 48, onPressed: () => Navigator.pop(dialogContext, false)),
            GateButton(
              label: 'Confirm',
              height: 48,
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();
                _auth.isLoading.value = true;
                Navigator.pop(dialogContext, true);
              },
            ),
          ],
        ),
      );

  void _openLegal(Widget page) => Navigator.of(context).push(GetPageRoute<void>(
        page: () => page,
        customTransition: TemplateTransition(),
        transitionDuration: templateTransitionDuration,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FitnessAppTheme.background,
      body: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: GateHeroLayout(
            heroHeight: 256,
            overlap: 48,
            hero: TemplateEntrance(
              animation: templateInterval(_enter, 0, 3),
              animationController: _enter,
              child: const GateHeroHeader(
                asset: TravelIcon.place,
                title: 'Bakhli',
                titleSize: 34,
                subtitle: 'Plan your next trip',
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
              child: TemplateEntrance(
                animation: templateInterval(_enter, 2, 3),
                animationController: _enter,
                child: GateSwitcher(
                  reverse: !_otpSent,
                  child: _otpSent ? _buildOtpCard() : _buildPhoneCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Key key, List<Widget> children) {
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: GateKit.heroCard(),
      child: TemplateStagger(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildPhoneCard() {
    final linkStyle = FitnessAppTheme.caption.copyWith(
      color: FitnessAppTheme.nearlyDarkBlue,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: FitnessAppTheme.nearlyDarkBlue,
    );
    return _card(const ValueKey('phone'), [
      Text('Welcome to Bakhli', style: FitnessAppTheme.headline.copyWith(fontSize: 18)),
      const SizedBox(height: 4),
      Text('Enter your mobile number to continue', style: FitnessAppTheme.caption),
      const SizedBox(height: 24),
      TextFormField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: FitnessAppTheme.title.copyWith(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          counterText: '',
          hintText: 'Mobile number',
          prefixIcon: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(color: FitnessAppTheme.spacer, borderRadius: CardRadius.chip),
              child: Text(
                '+91',
                style: FitnessAppTheme.body2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: FitnessAppTheme.nearlyDarkBlue,
                ),
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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
            width: 24,
            height: 24,
            child: Checkbox(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              activeColor: FitnessAppTheme.nearlyDarkBlue,
              side: BorderSide(color: FitnessAppTheme.grey.withValues(alpha: Alpha.half)),
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
                  style: FitnessAppTheme.caption.copyWith(height: 1.5),
                  children: [
                    const TextSpan(text: 'I agree to the '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () => _openLegal(const TermsOfServiceScreen()),
                        child: Text('Terms of Service', style: linkStyle),
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () => _openLegal(const PrivacyPolicyScreen()),
                        child: Text('Privacy Policy', style: linkStyle),
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
      Obx(() => GateButton(
            label: 'Send OTP',
            onPressed: (_auth.isLoading.value || !_agreed) ? null : _sendOtp,
            isLoading: _auth.isLoading.value,
          )),
    ]);
  }

  Widget _buildOtpCard() {
    return _card(const ValueKey('otp'), [
      Row(
        children: [
          InkResponse(
            radius: 22,
            onTap: () => setState(() {
              _otpSent = false;
              _otpCtrl.clear();
              _attempts = 0;
            }),
            child: const SizedBox(
              width: KitMetrics.touch,
              height: KitMetrics.touch,
              child: Icon(Icons.arrow_back_ios_new_rounded, color: FitnessAppTheme.nearlyDarkBlue, size: 18),
            ),
          ),
          const SizedBox(width: 4),
          Text('Verify OTP', style: FitnessAppTheme.headline.copyWith(fontSize: 18)),
        ],
      ),
      const SizedBox(height: 6),
      Text('OTP sent via WhatsApp to', style: FitnessAppTheme.caption),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(color: FitnessAppTheme.spacer, borderRadius: CardRadius.chip),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android_rounded, size: 14, color: FitnessAppTheme.nearlyDarkBlue),
            const SizedBox(width: 6),
            Text(
              '+91 $_phone',
              style: FitnessAppTheme.body2.copyWith(
                fontWeight: FontWeight.w600,
                color: FitnessAppTheme.nearlyDarkBlue,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
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
      Obx(() => GateButton(
            label: 'Verify',
            onPressed: _auth.isLoading.value ? null : () => _verifyOtp(_otpCtrl.text),
            isLoading: _auth.isLoading.value,
          )),
      const SizedBox(height: 12),
      Center(
        child: Obx(() => GateTextButton(
              label: _resends >= _maxResends ? 'No more resends' : 'Resend OTP (${_maxResends - _resends} left)',
              fontSize: 13,
              weight: FontWeight.w500,
              onPressed: _auth.isLoading.value || _resends >= _maxResends ? null : _resendOtp,
            )),
      ),
    ]);
  }
}
