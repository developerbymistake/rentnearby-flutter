import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../design/design.dart';
import '../utils/app_toast.dart';
import '../utils/input_formatters.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _auth = Get.find<AuthController>();
  final _nameCtrl = TextEditingController();
  late final String _phone;
  late final AnimationController _enter =
      AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    _phone = args['phone'] as String;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KitMotion.reduce(context)) {
      _enter.value = 1;
    } else if (!_enter.isAnimating && _enter.value == 0) {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppToast.error('Please enter your full name');
      return;
    }
    if (name.length > 100) {
      AppToast.error('Name cannot exceed 100 characters');
      return;
    }
    await _auth.completePhoneOnboarding(phone: _phone, name: name);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
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
                animation: templateInterval(_enter, 0, 2),
                animationController: _enter,
                child: const GateHeroHeader(
                  imageProvider: AssetImage(PickKit.userImage),
                  title: 'Complete your profile',
                  titleSize: 22,
                  subtitle: 'Just one more step',
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: 32 + MediaQuery.paddingOf(context).bottom),
                child: TemplateEntrance(
                  animation: templateInterval(_enter, 1, 2),
                  animationController: _enter,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
                    padding: const EdgeInsets.all(24),
                    decoration: GateKit.heroCard(),
                    child: TemplateStagger(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: FitnessAppTheme.background,
                            borderRadius: CardRadius.chip,
                            border: Border.all(color: FitnessAppTheme.grey.withValues(alpha: Alpha.soft)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_android_rounded,
                                  color: FitnessAppTheme.nearlyDarkBlue, size: 18),
                              const SizedBox(width: 12),
                              Text('+91 $_phone',
                                  style: FitnessAppTheme.title.copyWith(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: const BoxDecoration(
                                    color: PickKit.goodTint, borderRadius: CardRadius.chip),
                                child: Text('Verified',
                                    style: FitnessAppTheme.caption.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: PickKit.goodDark)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Full Name',
                                style: FitnessAppTheme.body2.copyWith(
                                    fontWeight: FontWeight.w500, color: FitnessAppTheme.lightText)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameCtrl,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 100,
                              inputFormatters: noEmojiInputFormatters,
                              style: FitnessAppTheme.body1,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.person_outline_rounded,
                                    color: FitnessAppTheme.nearlyBlue, size: 20),
                                hintText: 'Your full name',
                                counterText: '',
                              ),
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Obx(() => GateButton(
                              onPressed: _auth.isLoading.value ? null : _submit,
                              isLoading: _auth.isLoading.value,
                              label: 'Get Started',
                            )),
                      ],
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
}
