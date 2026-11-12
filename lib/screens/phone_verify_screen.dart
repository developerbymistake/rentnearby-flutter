import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import '../controllers/auth_controller.dart';
import '../design/design.dart';
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
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: GateKit.scrim,
      builder: (dialogContext) => GateDialog(
        asset: TravelIcon.star,
        title: _isChange ? 'Number Changed!' : 'Phone Verified!',
        body: _isChange
            ? 'Your mobile number has been updated to +91 ${_phoneCtrl.text}. All future OTPs will be sent to this number.'
            : 'Your mobile number +91 ${_phoneCtrl.text} is now verified. You can post listings on RentNearby.',
        actions: [
          GateButton(label: 'Continue', onPressed: () => Navigator.pop(dialogContext)),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String phone) {
    return showDialog<bool>(
      context: context,
      barrierColor: GateKit.scrim,
      builder: (dialogContext) => GateDialog(
        asset: TravelIcon.chat,
        title: 'Confirm your number',
        body: 'We will send an OTP on WhatsApp to',
        content: Column(
          children: [
            Container(
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
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const TravelIcon(TravelIcon.chat, size: 16),
                const SizedBox(width: 6),
                Text('via WhatsApp',
                    style: FitnessAppTheme.caption
                        .copyWith(color: GateKit.whatsApp, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        horizontalActions: true,
        actions: [
          GateOutlineButton(label: 'Edit', height: 48, onPressed: () => Navigator.pop(dialogContext, false)),
          GateButton(label: 'Confirm', height: 48, onPressed: () => Navigator.pop(dialogContext, true)),
        ],
      ),
    );
  }

  void _showPhoneClaimedDialog(String phone) {
    showDialog(
      context: context,
      builder: (dialogContext) => GateDialog(
        glyph: Icons.warning_amber_rounded,
        gradient: TripEntryStyle.rose,
        title: 'Number Not Available',
        body: 'This number is already registered in our system.\n\nPlease use a different number.',
        actions: [
          GateButton(
            label: 'Use Different Number',
            height: 48,
            onPressed: () {
              Navigator.pop(dialogContext);
              _phoneCtrl.clear();
              setState(() => _otpSent = false);
            },
          ),
        ],
      ),
    );
  }

  void _showMaxAttemptsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => GateDialog(
        glyph: Icons.lock_outline_rounded,
        gradient: TripEntryStyle.rose,
        title: 'Too many attempts',
        body: 'Please go back and try again later.',
        actions: [
          GateButton(
            label: 'Go Back',
            height: 48,
            onPressed: () {
              Navigator.pop(dialogContext);
              Get.back();
            },
          ),
        ],
      ),
    );
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
      child: Scaffold(
        backgroundColor: FitnessAppTheme.background,
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: GateHeroLayout(
              heroHeight: 304,
              overlap: 48,
              hero: TemplateEntrance(
                animation: templateInterval(_enter, 0, 2),
                animationController: _enter,
                child: GateHeroHeader(
                  asset: TravelIcon.checkout,
                  title: _isChange ? 'Change Number' : 'Verify Mobile',
                  titleSize: 24,
                  subtitle: _isChange ? 'Enter your new mobile number' : 'Required to post listings',
                  top: Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: KitMetrics.touch,
                      height: KitMetrics.touch,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        onPressed: () {
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
                        },
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: FitnessAppTheme.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
                child: TemplateEntrance(
                  animation: templateInterval(_enter, 1, 2),
                  animationController: _enter,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
                    padding: const EdgeInsets.all(24),
                    decoration: GateKit.heroCard(),
                    child: GateSwitcher(
                      reverse: !_otpSent,
                      child: _otpSent ? _otpSection() : _phoneSection(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneSection() => TemplateStagger(
        key: const ValueKey('phone'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isChange ? 'Enter your new number' : 'Enter your mobile number',
            style: FitnessAppTheme.headline.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            _isChange ? 'Your old number will be replaced after verification' : 'You\'ll receive an OTP on WhatsApp',
            style: FitnessAppTheme.caption,
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            style: FitnessAppTheme.title.copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(color: FitnessAppTheme.spacer, borderRadius: CardRadius.chip),
                child: Text('+91',
                    style: FitnessAppTheme.body2
                        .copyWith(fontWeight: FontWeight.w700, color: FitnessAppTheme.nearlyDarkBlue)),
              ),
              hintText: 'Enter mobile number',
            ),
          ),
          const SizedBox(height: 24),
          Obx(() => GateButton(
                onPressed: _auth.isLoading.value ? null : _sendOtp,
                isLoading: _auth.isLoading.value,
                label: 'Send OTP',
              )),
        ],
      );

  Widget _otpSection() {
    return TemplateStagger(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          InkResponse(
            radius: 22,
            onTap: () {
              FocusScope.of(context).unfocus();
              _otpCtrl.clear();
              setState(() {
                _otpSent = false;
                _attempts = 0;
              });
            },
            child: const SizedBox(
              width: KitMetrics.touch,
              height: KitMetrics.touch,
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: FitnessAppTheme.nearlyDarkBlue),
            ),
          ),
          const SizedBox(width: 4),
          Text('Enter OTP', style: FitnessAppTheme.headline.copyWith(fontSize: 18)),
        ]),
        const SizedBox(height: 6),
        Text('Sent to +91 ${_phoneCtrl.text}', style: FitnessAppTheme.caption),
        const SizedBox(height: 4),
        Row(
          children: [
            const TravelIcon(TravelIcon.chat, size: 16),
            const SizedBox(width: 6),
            Text('Check your WhatsApp for the OTP',
                style: FitnessAppTheme.caption.copyWith(color: GateKit.whatsApp, fontWeight: FontWeight.w600)),
          ],
        ),
        if (_attempts > 0) ...[
          const SizedBox(height: 6),
          Text('${_maxAttempts - _attempts} attempt${_maxAttempts - _attempts == 1 ? '' : 's'} remaining',
              style: FitnessAppTheme.caption.copyWith(color: PickKit.warn)),
        ],
        const SizedBox(height: 28),
        Center(
          child: Pinput(
            length: 4,
            controller: _otpCtrl,
            focusNode: _otpFocus,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            defaultPinTheme: _defaultTheme,
            focusedPinTheme: _focusedTheme,
            submittedPinTheme: _submittedTheme,
            cursor: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  width: 22,
                  height: 2,
                  decoration: BoxDecoration(
                      color: FitnessAppTheme.nearlyDarkBlue, borderRadius: BorderRadius.circular(2))),
            ]),
            onCompleted: (pin) => _verifyOtp(pin),
          ),
        ),
        const SizedBox(height: 28),
        Obx(() => GateButton(
              onPressed: _auth.isLoading.value ? null : () => _verifyOtp(),
              isLoading: _auth.isLoading.value,
              label: 'Verify Number',
            )),
        const SizedBox(height: 16),
        Center(
          child: Obx(() => GateTextButton(
                label: _resends >= _maxResends ? 'No more resends' : 'Resend OTP (${_maxResends - _resends} left)',
                onPressed: (_auth.isLoading.value || _resends >= _maxResends) ? null : _resendOtp,
              )),
        ),
      ],
    );
  }
}
