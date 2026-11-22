import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/profile_photo_strings.dart';
import '../controllers/auth_controller.dart';
import '../controllers/profile_photo_controller.dart';
import '../design/design.dart';
import '../design/extra/ext_auth.dart';
import '../utils/app_toast.dart';
import '../widgets/profile_photo_circle.dart';

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});
  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> with TickerProviderStateMixin {
  final _auth = Get.find<AuthController>();
  final _photo = ProfilePhotoController.ensure();
  static final ListingTone _tone = ListingTone.indigo;
  bool _photoBad = false;
  late final AnimationController _enter =
      AnimationController(duration: const Duration(milliseconds: 600), vsync: this);

  @override
  void initState() {
    super.initState();
    if (_auth.user.value?.profilePhotoUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _leaveIfStillSet());
    }
  }

  // The stored user may be stale (admin removed the picture): decide on a fresh profile.
  Future<void> _leaveIfStillSet() async {
    try {
      await _auth.refreshProfile();
    } catch (_) {}
    if (!mounted) return;
    if (_auth.user.value?.profilePhotoUrl != null) {
      Get.offAllNamed(_auth.postLoginRoute);
    } else {
      setState(() {});
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
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photo.failed.value && _photo.localPath.value != null) {
      await _continue();
      return;
    }
    if (await _photo.choose(context) && mounted) setState(() => _photoBad = false);
  }

  Future<void> _continue() async {
    if (_photo.active || _auth.isLoggingOut.value) return;
    if (_photo.localPath.value == null) {
      setState(() => _photoBad = true);
      AppToast.error(ProfilePhotoStrings.addTitle);
      return;
    }
    if (!await _photo.online()) return;
    final ok = await _photo.upload();
    if (ok && mounted) Get.offAllNamed(_auth.postLoginRoute);
  }

  @override
  Widget build(BuildContext context) {
    final removed = _auth.user.value?.profilePhotoRemoved ?? false;
    return PopScope(
      canPop: false,
      child: AuthHeroScaffold(
        hero: TemplateEntrance(
          animation: templateInterval(_enter, 0, 2),
          animationController: _enter,
          child: AuthHero(
            tone: _tone,
            art: ListingArt.profile,
            title: ProfilePhotoStrings.addTitle,
            subtitle: removed ? ProfilePhotoStrings.removedSubtitle : 'Just one more step',
            smallTitle: true,
          ),
        ),
        card: TemplateEntrance(
          animation: templateInterval(_enter, 1, 2),
          animationController: _enter,
          child: AuthCard(
            children: [
              ProfilePhotoBlock(controller: _photo, bad: _photoBad, onTap: _pickPhoto),
              Gap.v(20),
              Obx(() => ProfilePhotoSubmitButton(
                    tone: _tone,
                    label: ProfilePhotoStrings.continueLabel,
                    ready: _photo.localPath.value != null,
                    loading: _photo.busy.value,
                    onTap: _continue,
                  )),
              Gap.v(12),
              Obx(() => WhitePillButton(
                    tone: _tone,
                    label: ProfilePhotoStrings.logOut,
                    onTap: _photo.busy.value || _auth.isLoggingOut.value ? null : _auth.logout,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
