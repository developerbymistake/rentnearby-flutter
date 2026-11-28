import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../config/app_tabs.dart';
import '../../../../config/profile_photo_strings.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/profile_photo_controller.dart';
import '../../../../controllers/tab_config_controller.dart';
import '../../../../design/design.dart';
import '../../../../design/extra/ext_buddy.dart';
import '../../../../screens/profile/profile_rows.dart';
import '../../../../screens/profile_screen.dart';
import '../../../../widgets/profile_photo_circle.dart';
import '../../../../widgets/tab_header.dart';
import '../../../buddy/buddy_strings.dart';
import '../../../buddy/username_actions.dart';
import '../../../buddy/widgets/username_qr_sheet.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/travel_level_widgets.dart';
import '../social_strings_a.dart';
import '../widgets/social_section_card.dart';
import 'profile_sections.dart';

class SeekerProfileScreen extends StatelessWidget {
  const SeekerProfileScreen({super.key});

  static const Key settingsKey = TabHeaderIcons.settingsKey;
  static const Key editKey = ValueKey('seeker_profile_edit');
  static const Key myQrKey = ValueKey('seeker_profile_my_qr');
  static const Key copyKey = ValueKey('seeker_profile_copy_username');
  static const Key usernameKey = ValueKey('seeker_profile_username');
  static const Key activityKey = ValueKey('seeker_profile_activity');

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
            settingsOnly: true,
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
          onAction: () => Get.toNamed(AppRoutes.onboarding),
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

  Widget _accountRows(BuildContext context) {
    final username = profile.username ?? '';
    final has = username.isNotEmpty;
    return LabeledRowsSection(children: [
      IconRow3D(
        key: SeekerProfileScreen.usernameKey,
        art: ListingArt.key,
        title: has ? username : BuddyStrings.usernameLoading,
        subtitle: BuddyStrings.myUsername,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BuddyRoundButton(
              key: SeekerProfileScreen.myQrKey,
              icon: Icons.qr_code_2_rounded,
              label: BuddyStrings.showQr,
              onTap: has ? () => UsernameQrSheet.show(context, username: username, name: profile.name) : null,
            ),
            Gap.h(6),
            BuddyRoundButton(
              key: SeekerProfileScreen.copyKey,
              icon: Icons.copy_rounded,
              label: BuddyStrings.copyUsername,
              onTap: has ? () => UsernameActions.copy(username) : null,
            ),
          ],
        ),
      ),
      IconRow3D(
        key: SeekerProfileScreen.editKey,
        art: ListingArt.memo,
        title: SocialStringsA.editTitle,
        divider: true,
        trailing: Icon(Icons.chevron_right_rounded, size: DS.s(22), color: DesignColors.textDisabled),
        onTap: SocialNav.openEditProfile,
      ),
    ]);
  }

  Widget _activity() {
    final auth = Get.find<AuthController>();
    final rows = <({String art, String title, String route})>[
      if (auth.canOpenRoute(AppRoutes.myTrips)) (art: ListingArt.luggage, title: SocialStringsA.myTrips, route: AppRoutes.myTrips),
      if (auth.jobsBrowseEnabled && ProfileRows.showsJobsFeed(auth.shellKind.value)) (art: ListingArt.briefcase, title: SocialStringsA.jobs, route: AppRoutes.jobs),
      if (auth.canOpenRoute(AppRoutes.myJourneys)) (art: ListingArt.compass, title: SocialStringsA.myJourneys, route: AppRoutes.myJourneys),
      (art: ListingArt.warning, title: SocialStringsA.myReports, route: AppRoutes.myFiledReports),
    ];
    return LabeledRowsSection(key: SeekerProfileScreen.activityKey, label: SocialStringsA.activityLabel, children: [
      for (var r = 0; r < rows.length; r++) IconRow3D(art: rows[r].art, title: rows[r].title, divider: r > 0, onTap: () => Get.toNamed(rows[r].route)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileHeroCard(
          person: profile.person,
          gender: profile.gender,
          about: profile.about,
          trips: profile.completedTrips,
          followers: profile.followers,
          following: profile.following,
          photo: _MyPhoto(initial: profile.initial),
          after: LevelPanelCard(trips: profile.completedTrips, level: profile.level, onTap: SocialNav.openTravelLevels),
          onFollowers: () => SocialNav.openPeople(tab: 'followers'),
          onFollowing: () => SocialNav.openPeople(tab: 'following'),
        ),
        _accountRows(context),
        _activity(),
        ProfileTripsSection(title: SocialStringsA.myPublicTrips(profile.publicTrips.length), trips: profile.publicTrips, onBack: SocialMeController.to.refreshQuiet),
        Gap.v(14),
      ],
    );
  }
}

class _MyPhoto extends StatelessWidget {
  const _MyPhoto({required this.initial});

  final String initial;

  static const Key retryKey = ValueKey('seeker_profile_photo_retry');

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final photo = ProfilePhotoController.ensure();
    return Obx(() {
      final busy = photo.busy.value;
      final failed = photo.failed.value && photo.localPath.value != null;
      final circle = SizedBox.square(
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
            if (failed) Positioned(right: 0, bottom: 0, child: ProfileRoundButton(key: retryKey, icon: Icons.refresh_rounded, color: ListingTone.coral.g2)),
          ],
        ),
      );
      if (!failed) return circle;
      return Tap3D(onTap: photo.retryChange, label: ProfilePhotoStrings.tryAgain, exclude: true, child: circle);
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
