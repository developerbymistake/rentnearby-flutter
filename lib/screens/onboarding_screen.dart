import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../design/design.dart';
import '../design/extra/ext_auth.dart';
import '../design/extra/ext_buddy.dart';
import '../features/buddy/buddy_strings.dart';
import '../features/buddy/username_actions.dart';
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
  final _nameFocus = FocusNode();
  static final ListingTone _tone = ListingTone.indigo;
  bool _nameBad = false;
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
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameBad = true);
      AppToast.error('Please enter your full name');
      return;
    }
    if (name.length > 100) {
      setState(() => _nameBad = true);
      AppToast.error('Name cannot exceed 100 characters');
      return;
    }
    await _auth.completePhoneOnboarding(phone: _phone, name: name);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AuthHeroScaffold(
        hero: TemplateEntrance(
          animation: templateInterval(_enter, 0, 2),
          animationController: _enter,
          child: AuthHero(tone: _tone, art: ListingArt.profile, title: 'Complete your profile', subtitle: 'Just one more step', smallTitle: true),
        ),
        card: TemplateEntrance(
          animation: templateInterval(_enter, 1, 2),
          animationController: _enter,
          child: AuthCard(
            children: [
              AuthVerifiedRow(art: ListingArt.key, text: '+91 $_phone'),
              Gap.v(20),
              const AuthFieldLabel(BuddyStrings.usernameLabel),
              Obx(() {
                final username = _auth.signupUsername.value;
                return UsernameLockedPill(
                  username: username,
                  art: ListingArt.key,
                  copyLabel: BuddyStrings.copyUsername,
                  loadingLabel: BuddyStrings.usernameLoading,
                  onCopy: () => UsernameActions.copy(username!),
                );
              }),
              Padding(
                padding: DS.insets(l: 6, t: 6),
                child: Text(BuddyStrings.usernameHelper, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
              ),
              Gap.v(18),
              const AuthFieldLabel('Full Name'),
              AuthPillInput(
                tone: _tone,
                focusNode: _nameFocus,
                bad: _nameBad,
                leadingArt: ListingArt.profile,
                child: TextFormField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                  inputFormatters: noEmojiInputFormatters,
                  style: AuthPillInput.nameStyle,
                  cursorColor: _tone.g2,
                  decoration: AuthPillInput.decoration('Your full name'),
                  onChanged: (_) {
                    if (_nameBad) setState(() => _nameBad = false);
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
              ),
              Gap.v(28),
              Obx(() => GradientPillButton(
                    tone: _tone,
                    label: 'Get Started',
                    onTap: _auth.isLoading.value ? null : _submit,
                    loading: _auth.isLoading.value,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
