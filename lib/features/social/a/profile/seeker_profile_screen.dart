import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../config/app_tabs.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/profile_photo_controller.dart';
import '../../../../controllers/tab_config_controller.dart';
import '../../../../design/design.dart';
import '../../../../screens/profile_screen.dart';
import '../../../../widgets/profile_photo_circle.dart';
import '../../../../widgets/tab_header.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_strings.dart';
import '../social_strings_a.dart';
import 'profile_sections.dart';

class SeekerProfileScreen extends StatelessWidget {
  const SeekerProfileScreen({super.key});

  static const Key settingsKey = TabHeaderIcons.settingsKey;
  static const Key editKey = ValueKey('seeker_profile_edit');

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      if (!auth.canUseTravellerFeatures || SocialMeController.maybe == null) return const ProfileScreen();
      final title = Get.isRegistered<TabConfigController>()
          ? Get.find<TabConfigController>().displayNameForIndex(AppTabs.profile, SocialStringsA.profileTitle)
          : SocialStringsA.profileTitle;
      return Scaffold(
        backgroundColor: ListingPalette.indigo.page,
        resizeToAvoidBottomInset: false,
        body: TabEntrance(
          tab: AppTabs.profile,
          child: TabHeaderFrame(
            title: title,
            subtitle: SocialStringsA.profileSub,
            color: ListingPalette.indigo.page,
            onSettings: SocialNav.openSettings,
            child: const _ProfileBody(),
          ),
        ),
      );
    });
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody();

  @override
  Widget build(BuildContext context) {
    final c = SocialMeController.to;
    return Obx(() {
      final me = c.me.value;
      final profile = me?.profile;
      if (me == null && c.loading.value) return const _ProfileSkeleton();
      if (me == null) {
        return StateCard.error(
          title: SocialStringsA.profileLoadFailed,
          actionLabel: SocialStrings.retry,
          onAction: c.load,
        );
      }
      if (profile == null) {
        return StateCard(
          title: SocialStringsA.obTitle,
          asset: ListingArt.memo,
          actionLabel: SocialStringsA.next,
          onAction: () => Get.toNamed(AppRoutes.onboarding, arguments: const {'existing': true}),
        );
      }
      return RefreshIndicator(
        onRefresh: c.refreshQuiet,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.only(bottom: BarMetrics.bodyBottomOf(context)),
          child: _ProfileContent(profile: profile),
        ),
      );
    });
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile});

  final MyProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileHeroCard(
          person: profile.person,
          gender: profile.gender,
          trips: profile.trips,
          followers: profile.followers,
          following: profile.following,
          photo: _MyPhoto(initial: profile.initial),
          onFollowers: () => SocialNav.openPeople(tab: 'followers'),
          onFollowing: () => SocialNav.openPeople(tab: 'following'),
        ),
        Padding(
          padding: DS.gapInsets(l: 18, t: 22, r: 18),
          child: GradientPillButton(
            key: SeekerProfileScreen.editKey,
            tone: ListingTone.indigo,
            label: SocialStringsA.editProfileBtn,
            onTap: SocialNav.openEditProfile,
          ),
        ),
        Gap.v(22),
        ProfileChipsSection(about: profile.about, interests: profile.interests, places: profile.places, skills: profile.skills),
        ProfileTripsSection(title: SocialStringsA.myPublicTrips(profile.publicTrips.length), trips: profile.publicTrips),
        Gap.v(14),
      ],
    );
  }
}

class _MyPhoto extends StatelessWidget {
  const _MyPhoto({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final photo = ProfilePhotoController.ensure();
    return Obx(() {
      final busy = photo.busy.value;
      final failed = photo.failed.value && photo.localPath.value != null;
      return Semantics(
        button: true,
        label: SocialStringsA.changePhoto,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: busy ? null : () => failed ? photo.retryChange() : photo.change(context),
          child: SizedBox.square(
            dimension: DS.s(76),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ProfilePhotoCircle(
                  size: DS.s(72),
                  url: auth.user.value?.profilePhotoUrl,
                  localPath: busy ? photo.localPath.value : null,
                  placeholderPath: photo.placeholderPath,
                  busy: busy,
                  failed: failed,
                  ringColor: DesignColors.onPrimary.withValues(alpha: Alpha.v60),
                  ringWidth: DS.s(3),
                  failColor: ListingTone.coral.g1,
                  fallback: ColoredBox(
                    color: DesignColors.onPrimary.withValues(alpha: Alpha.v25),
                    child: Center(child: Text(initial, maxLines: 1, style: Ink3D.text(28, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0))),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: ProfileRoundButton(icon: failed ? Icons.refresh_rounded : Icons.edit_rounded, color: failed ? ListingTone.coral.g2 : ListingTone.indigo.g2),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.gapInsets(l: 18, t: 4, r: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonBox(height: DS.s(180), borderRadius: DS.circular(32)),
            Gap.v(22),
            SkeletonBox(height: DS.s(50), borderRadius: DS.circular(25)),
            Gap.v(22),
            SkeletonBox(height: DS.s(220), borderRadius: DS.circular(28)),
          ],
        ),
      );
}
