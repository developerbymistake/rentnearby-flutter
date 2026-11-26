import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../config/profile_photo_strings.dart';
import '../controllers/auth_controller.dart';
import '../controllers/profile_photo_controller.dart';
import '../design/design.dart';
import '../design/extra/ext_auth.dart';
import '../design/extra/ext_buddy.dart';
import '../features/buddy/buddy_strings.dart';
import '../features/buddy/username_actions.dart';
import '../features/owner_core/onboarding/onboarding_exit.dart';
import '../features/social/a/onboarding/onboarding_controller.dart';
import '../features/social/a/onboarding/onboarding_steps.dart';
import '../features/social/a/social_strings_a.dart';
import '../features/social/shared/social_formats.dart';
import '../utils/app_toast.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _auth = Get.find<AuthController>();
  final _photo = ProfilePhotoController.ensure();
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _aboutCtrl = TextEditingController();
  final _scroll = ScrollController();
  late final String _tag = 'onboarding-${identityHashCode(this)}';
  late final OnboardingController _c;
  bool _created = false;
  bool _uploadFailed = false;
  Worker? _aboutWorker;

  @override
  void initState() {
    super.initState();
    final raw = Get.arguments;
    final args = raw is Map ? raw : const {};
    final phone = args['phone'];
    final existing = args['existing'] == true || phone is! String;
    _c = Get.put(OnboardingController(existing: existing, phone: phone is String ? phone : null), tag: _tag);
    _nameCtrl.text = _c.name.value;
    _aboutCtrl.text = _c.about.value;
    _aboutWorker = ever<String>(_c.about, (v) {
      if (_aboutCtrl.text != v) _aboutCtrl.text = v;
    });
  }

  @override
  void dispose() {
    _aboutWorker?.dispose();
    Get.delete<OnboardingController>(tag: _tag);
    _nameCtrl.dispose();
    _nameFocus.dispose();
    _aboutCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  // Opened from Profile (pushed over another page): step 1 Back leaves. As the login gate nothing is below.
  bool get _canLeave => _c.existing && !_created && Navigator.of(context).canPop();

  void _back() {
    FocusScope.of(context).unfocus();
    if (_c.back()) {
      _top();
    } else if (_canLeave && !_c.submitting.value) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickPhoto() async {
    await _photo.choose(context);
  }

  void _skipPhoto() {
    if (_photo.active) return;
    Get.offAllNamed(_auth.postLoginRoute);
  }

  Widget? _bottomLink() {
    if (_created && _uploadFailed) {
      return AuthTextLink(tone: ListingTone.indigo, label: SocialStringsA.skipForNow, onTap: _photo.busy.value ? null : _skipPhoto);
    }
    return null;
  }

  Future<void> _primary() async {
    FocusScope.of(context).unfocus();
    if (!_c.isLast) {
      if (_c.next()) _top();
      return;
    }
    if (_c.submitting.value || _auth.isLoading.value || _photo.active) return;
    if (_created) {
      await _uploadThenGo();
      return;
    }
    if (_photo.localPath.value != null && !await _photo.online()) return;
    final ok = await _c.finish();
    if (!mounted) return;
    if (!ok) {
      final e = _c.error.value;
      if (e != null) AppToast.error(e);
      return;
    }
    setState(() => _created = true);
    await _uploadThenGo();
  }

  Future<void> _uploadThenGo() async {
    if (_photo.localPath.value == null) {
      Get.offAllNamed(_auth.postLoginRoute);
      return;
    }
    if (!await _photo.online()) return;
    final ok = await _photo.upload();
    if (!mounted) return;
    if (ok) {
      Get.offAllNamed(_auth.postLoginRoute);
    } else if (!_uploadFailed) {
      setState(() => _uploadFailed = true);
    }
  }

  Widget _identity() => Obx(() {
        final phone = _c.existing ? _auth.profilePhone.value : (_c.phone ?? '');
        final username = _c.existing ? _auth.user.value?.username : _auth.signupUsername.value;
        return OnboardingIdentityChips(
          phone: phone.isEmpty ? null : '+91 ${SocialFormats.maskPhone(phone)}',
          username: username,
          idPill: (compact) => UsernameLockedPill(
            username: username,
            art: ListingArt.key,
            compact: compact,
            copyLabel: BuddyStrings.copyUsername,
            loadingLabel: BuddyStrings.usernameLoading,
            onCopy: () => UsernameActions.copy(username!),
          ),
        );
      });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: AuthInk.page,
          body: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Obx(() {
              final step = _c.step.value;
              final last = step == OnboardingController.stepCount - 1;
              return Column(
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
                            step: step,
                            onBack: step > 0 || _canLeave ? _back : null,
                            onMenu: _canLeave ? null : (r) => OnboardingExit.openMenu(context, isDraft: true, hasDraft: false, anchor: r),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: DS.gv(OnboardingHeader.cardGap)),
                            child: switch (step) {
                              0 => OnboardingStepYou(
                                  c: _c,
                                  photo: _photo,
                                  onPhoto: _pickPhoto,
                                  nameCtrl: _nameCtrl,
                                  nameFocus: _nameFocus,
                                  phoneLine: _identity(),
                                ),
                              1 => OnboardingStepStyle(c: _c),
                              _ => OnboardingStepAbout(c: _c, aboutCtrl: _aboutCtrl, photoUrl: _auth.user.value?.profilePhotoUrl),
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Obx(() => OnboardingBottom(
                        label: last ? (_uploadFailed ? ProfilePhotoStrings.tryAgain : SocialStringsA.finish) : SocialStringsA.next,
                        enabled: _created || _c.canNext,
                        loading: _c.submitting.value || _auth.isLoading.value || _photo.busy.value,
                        hint: _created ? null : _c.missingHint,
                        onTap: _primary,
                        link: _bottomLink(),
                      )),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
