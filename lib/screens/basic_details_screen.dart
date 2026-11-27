import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../config/basic_details_strings.dart';
import '../config/profile_photo_strings.dart';
import '../controllers/auth_controller.dart';
import '../controllers/profile_photo_controller.dart';
import '../design/design.dart';
import '../design/extra/ext_auth.dart';
import '../design/extra/ext_buddy.dart';
import '../features/buddy/buddy_strings.dart';
import '../features/buddy/username_actions.dart';
import '../features/owner_core/onboarding/onboarding_exit.dart';
import '../features/social/a/onboarding/onboarding_controller.dart' show ProfileRules;
import '../features/social/a/onboarding/onboarding_steps.dart';
import '../features/social/a/social_strings_a.dart';
import '../utils/app_toast.dart';
import '../utils/input_formatters.dart';

// New user after OTP: the account is made here (name only), then postLoginRoute.
class BasicDetailsScreen extends StatefulWidget {
  const BasicDetailsScreen({super.key});
  @override
  State<BasicDetailsScreen> createState() => _BasicDetailsScreenState();
}

class _BasicDetailsScreenState extends State<BasicDetailsScreen> {
  final _auth = Get.find<AuthController>();
  final _photo = ProfilePhotoController.ensure();
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _scroll = ScrollController();
  static final ListingTone _tone = ListingTone.indigo;
  bool _nameBad = false;
  bool _created = false;
  bool _uploadFailed = false;
  bool _submitting = false;
  late final String _phone;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final phone = args is Map ? args['phone'] : null;
    _phone = phone is String ? phone : '';
    if (_phone.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => Get.offAllNamed(AppRoutes.login));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_created && _photo.failed.value && _photo.localPath.value != null) {
      await _submit();
      return;
    }
    await _photo.choose(context);
  }

  void _skipPhoto() {
    if (_photo.active) return;
    _photo.discard();
    Get.offAllNamed(_auth.postLoginRoute);
  }

  // Before the account exists the only way out is back to login; after it, the menu offers Log out.
  void _leave() {
    if (_created || _submitting || _auth.isLoading.value) return;
    Get.offAllNamed(AppRoutes.login);
  }

  Future<void> _submit() async {
    if (_submitting || _auth.isLoading.value || _photo.active) return;
    _submitting = true;
    try {
      await _submitOnce();
    } finally {
      _submitting = false;
    }
  }

  Future<void> _submitOnce() async {
    FocusScope.of(context).unfocus();
    if (_created) {
      if (_photo.localPath.value == null) {
        Get.offAllNamed(_auth.postLoginRoute);
      } else if (await _photo.online()) {
        await _upload();
      }
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameBad = true);
      AppToast.error(BasicDetailsStrings.nameRequired);
      return;
    }
    if (name.length > ProfileRules.nameMax) {
      setState(() => _nameBad = true);
      AppToast.error(BasicDetailsStrings.nameTooLong);
      return;
    }
    if (_photo.localPath.value != null && !await _photo.online()) return;
    final ok = await _auth.createOnboardingAccount(phone: _phone, name: name);
    if (!ok || !mounted) return;
    setState(() => _created = true);
    if (_photo.localPath.value == null) {
      Get.offAllNamed(_auth.postLoginRoute);
    } else {
      await _upload();
    }
  }

  Future<void> _upload() async {
    final ok = await _photo.upload();
    if (!mounted) return;
    if (ok) {
      Get.offAllNamed(_auth.postLoginRoute);
    } else if (!_uploadFailed) {
      setState(() => _uploadFailed = true);
    }
  }

  Widget _card() => OnboardingCard(
        children: [
          OnboardingPhotoRow(controller: _photo, onTap: _pickPhoto),
          Gap.v(20),
          AuthVerifiedRow(art: ListingArt.key, text: '+91 $_phone'),
          const OnboardingFieldLabel(BuddyStrings.usernameLabel),
          Obx(() {
            final username = _auth.signupUsername.value ?? _auth.user.value?.username;
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
          const OnboardingFieldLabel(BasicDetailsStrings.fullName),
          AuthPillInput(
            tone: _tone,
            focusNode: _nameFocus,
            bad: _nameBad,
            locked: _created,
            leadingArt: ListingArt.profile,
            child: TextFormField(
              key: const ValueKey('bd_name'),
              controller: _nameCtrl,
              focusNode: _nameFocus,
              readOnly: _created,
              textCapitalization: TextCapitalization.words,
              maxLength: ProfileRules.nameMax,
              inputFormatters: noEmojiInputFormatters,
              style: _created ? AuthPillInput.nameStyle.copyWith(color: Ink3D.sub) : AuthPillInput.nameStyle,
              cursorColor: _tone.g2,
              decoration: AuthPillInput.decoration(BasicDetailsStrings.fullNameHint),
              onChanged: (_) {
                if (_nameBad) setState(() => _nameBad = false);
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
        ],
      );

  Widget _bottom() => ValueListenableBuilder<TextEditingValue>(
        valueListenable: _nameCtrl,
        builder: (_, v, _) {
          final name = v.text.trim();
          return Obx(() {
            final busy = _photo.busy.value;
            return OnboardingBottom(
              label: _uploadFailed ? ProfilePhotoStrings.tryAgain : BasicDetailsStrings.button,
              enabled: _created || (name.isNotEmpty && name.length <= ProfileRules.nameMax),
              loading: _auth.isLoading.value || busy,
              onTap: _submit,
              link: _created && _uploadFailed ? AuthTextLink(tone: _tone, label: SocialStringsA.skipForNow, onTap: busy ? null : _skipPhoto) : null,
            );
          });
        },
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: AuthInk.page,
          body: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(bottom: DS.s(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OnboardingHeader(
                          title: BasicDetailsStrings.title,
                          subtitle: BasicDetailsStrings.subtitle,
                          showSteps: false,
                          onBack: _created ? null : _leave,
                          onMenu: _created ? (r) => OnboardingExit.openMenu(context, isDraft: false, hasDraft: false, anchor: r) : null,
                        ),
                        Padding(
                          padding: EdgeInsets.only(top: DS.gv(OnboardingHeader.cardGap)),
                          child: _card(),
                        ),
                      ],
                    ),
                  ),
                ),
                _bottom(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
