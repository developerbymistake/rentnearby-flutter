import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../design/design.dart';
import '../../../../screens/profile/profile_rows.dart';
import '../../../../screens/profile_screen.dart';
import '../../../../utils/app_date_format.dart';
import '../../../../widgets/role_option_card.dart';
import '../../../buddy/buddies/controllers/buddy_summary_controller.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../../buddy/shared/widgets/buddy_sheet.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../c/plus/seeker_plan_keys.dart';
import '../../shared/social_formats.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_safety_strings.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/safety_guidelines_sheet.dart';
import '../social_strings_a.dart';
import '../widgets/social_chips_a.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const Key privateKey = ValueKey('settings_private');
  static const Key policyKey = ValueKey('settings_policy');
  static const Key blockedKey = ValueKey('settings_blocked');
  static const Key plusKey = ValueKey('settings_plus');
  static const Key safetyKey = ValueKey('settings_safety_tips');
  static const Key nearbyKey = ValueKey('settings_notify_nearby');
  static const Key logoutKey = ValueKey('settings_logout');
  static const Key deleteKey = ValueKey('settings_delete');
  static const Key verifiedPillKey = ValueKey('settings_phone_verified');
  static const Key profileLoadingKey = ValueKey('settings_profile_loading');
  static const Key profileErrorKey = ValueKey('settings_profile_error');

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final String _tag = 'settings-${identityHashCode(this)}';
  late final SocialSettingsController c = Get.put(SocialSettingsController(), tag: _tag);
  final _auth = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    SeekerPlanKeys.plans?.refreshPlan();
    BuddySummaryController.maybe?.load();
    SocialMeController.maybe?.refreshQuiet();
  }

  @override
  void dispose() {
    Get.delete<SocialSettingsController>(tag: _tag);
    super.dispose();
  }

  Future<void> _set(String key, Object value) async {
    final error = await c.updatePrivacy(key, value);
    if (!mounted) return;
    if (error != null) BuddySnack.show(context, error, danger: true);
  }

  Future<void> _pickPolicy(String current) async {
    final picked = await BuddySheet.show<String>(
      context,
      title: SocialStringsA.whoCanMessage,
      subtitle: SocialStringsA.whoCanMessageLine,
      builder: (ctx) => _PolicySheet(current: current),
    );
    if (picked != null && picked != current) await _set('messagePolicy', picked);
  }

  Widget _section(String label, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(DS.s(22), DS.gv(22), DS.s(22), DS.gv(12)),
            child: Text(label, style: Ink3D.text(12, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8)),
          ),
          WhiteCard3D(child: Column(children: children)),
        ],
      );

  Widget _switch(String key, bool value, {Key? switchKey}) => Obx(() => Switch3D(
        key: switchKey,
        tone: ListingTone.indigo,
        value: value,
        semanticsLabel: key,
        onChanged: c.busy.contains(key) ? null : (v) => _set(key, v),
      ));

  String? _blockedLine() {
    final n = BuddySummaryController.maybe?.summary.value.blocked ?? 0;
    return n > 0 ? SocialStringsA.blockedCount(n) : null;
  }

  Widget _phoneRow() => Obx(() {
        final verified = _auth.profilePhoneVerified.value;
        final locked = _auth.profilePhoneChangeLocked.value;
        return IconRow3D(
          art: ListingArt.key,
          title: '+91 ${SocialFormats.maskPhone(_auth.profilePhone.value)}',
          subtitle: verified ? null : SocialStringsA.notVerified,
          subtitleChild: verified
              ? const Align(alignment: Alignment.centerLeft, child: TagChip(key: SettingsScreen.verifiedPillKey, text: SocialStringsA.verified, kind: TagKind.place, small: true))
              : null,
          trailing: locked
              ? null
              : Tap3D(
                  onTap: ProfileActions.changePhone,
                  label: SocialStringsA.change,
                  exclude: true,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch)),
                    child: Center(widthFactor: 1, child: Text(SocialStringsA.change, style: Ink3D.text(13, FontWeight.w700, ListingTone.indigo.g2))),
                  ),
                ),
        );
      });

  Widget _roleRow() => Obx(() {
        final roleKey = _auth.roleKey.value;
        final u = _auth.user.value;
        final locked = _auth.roleChangeLocked;
        final blockedUntil = u?.roleRequestBlockedUntil;
        final String sub;
        if (locked) {
          sub = RoleVisuals.displayName(roleKey);
        } else if (u?.hasPendingRoleRequest ?? false) {
          sub = SocialStringsA.requestPending;
        } else if (blockedUntil != null) {
          sub = SocialStringsA.tryAgainAfter(AppDateFormat.dateTime(blockedUntil));
        } else if (u?.hasRejectedRoleRequest ?? false) {
          sub = SocialStringsA.requestRejected;
        } else if (!_auth.roleTabActive) {
          sub = SocialStringsA.paused;
        } else {
          sub = SocialStringsA.nowRole(RoleVisuals.displayName(roleKey));
        }
        return IconRow3D(
          art: ListingArt.panda,
          title: locked ? SocialStringsA.currentRole : SocialStringsA.changeRole,
          subtitle: sub,
          divider: true,
          trailing: locked ? null : Icon(Icons.chevron_right_rounded, size: DS.s(22), color: DesignColors.textDisabled),
          onTap: locked ? null : () => Get.toNamed(AppRoutes.roleChange),
        );
      });

  Widget _profileState() {
    final me = SocialMeController.maybe;
    if (me != null && me.failed.value && !me.loading.value) {
      return Padding(
        key: SettingsScreen.profileErrorKey,
        padding: DS.gapInsets(t: 8, b: 8),
        child: StateCard.error(title: SocialStrings.failed, actionLabel: SocialStrings.retry, onAction: me.load),
      );
    }
    return Padding(
      key: SettingsScreen.profileLoadingKey,
      padding: DS.gapInsets(l: 16, t: 12, r: 16, b: 4),
      child: Column(
        children: [
          for (var i = 0; i < 2; i++) ...[if (i > 0) Gap.v(12), SkeletonBox(height: DS.s(44), borderRadius: DS.circular(14))],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chevron = Icon(Icons.chevron_right_rounded, size: DS.s(22), color: DesignColors.textDisabled);
    return BuddyPage(
      title: SocialStringsA.settingsLabel,
      body: Obx(() {
        final me = SocialMeController.maybe?.me.value;
        final p = me?.profile;
        final limits = me?.limits ?? SocialLimits.free;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(SocialStringsA.accountLabel, [
              _phoneRow(),
              _roleRow(),
              IconRow3D(
                key: SettingsScreen.plusKey,
                art: ListingArt.moneyBag,
                title: SocialStringsA.plus,
                subtitle: SeekerPlanKeys.statusLine() ?? (limits.isPlus ? SocialStringsA.plusOn : SocialStringsA.free),
                divider: true,
                trailing: chevron,
                onTap: () => SocialNav.openPlus(from: 'settings'),
              ),
            ]),
            _section(SocialStringsA.privacyLabel, [
              if (p != null) ...[
                IconRow3D(
                  art: ListingArt.locked,
                  title: SocialStringsA.privateProfile,
                  subtitle: SocialStringsA.privateProfileLine,
                  trailing: _switch('isPrivate', p.isPrivate, switchKey: SettingsScreen.privateKey),
                ),
                IconRow3D(
                  key: SettingsScreen.policyKey,
                  art: ListingArt.speechBalloon,
                  title: SocialStringsA.whoCanMessage,
                  subtitle: SocialStringsA.policyLabel(p.messagePolicy),
                  divider: true,
                  trailing: chevron,
                  onTap: () => _pickPolicy(p.messagePolicy),
                ),
              ] else
                _profileState(),
              IconRow3D(
                key: SettingsScreen.blockedKey,
                art: ListingArt.shield,
                title: SocialStringsA.blockedPeople,
                subtitle: _blockedLine(),
                divider: true,
                trailing: chevron,
                onTap: () => Get.toNamed(AppRoutes.buddiesBlocked),
              ),
              IconRow3D(
                key: SettingsScreen.safetyKey,
                art: ListingArt.bulb,
                title: SocialSafetyStrings.tipsRow,
                divider: true,
                trailing: chevron,
                onTap: () => SafetyGuidelinesSheet.showReadOnly(context),
              ),
            ]),
            if (p != null)
              _section(SocialStringsA.notificationsLabel, [
                IconRow3D(art: ListingArt.speechBalloon, title: SocialStringsA.notifyMessages, trailing: _switch('notifyMessages', p.notifyMessages)),
                IconRow3D(art: ListingArt.bell, title: SocialStringsA.notifyFollows, divider: true, trailing: _switch('notifyFollows', p.notifyFollows)),
                IconRow3D(art: ListingArt.luggage, title: SocialStringsA.notifyTrips, divider: true, trailing: _switch('notifyFollowedTrips', p.notifyFollowedTrips)),
                IconRow3D(art: ListingArt.roundPushpin, title: SocialStringsA.notifyNearbyTrips, divider: true, trailing: _switch('notifyNearbyTrips', p.notifyNearbyTrips, switchKey: SettingsScreen.nearbyKey)),
              ]),
            _activity(),
            _section(SocialStringsA.supportLabel, [
              IconRow3D(art: ListingArt.speechBalloon, title: SocialStringsA.contactSupport, onTap: ProfileActions.contactSupport),
              IconRow3D(art: ListingArt.star, title: SocialStringsA.rateApp, divider: true, onTap: ProfileActions.rateApp),
              IconRow3D(art: ListingArt.airplane, title: SocialStringsA.shareApp, divider: true, onTap: ProfileActions.shareApp),
            ]),
            _section(SocialStringsA.legalLabel, [
              IconRow3D(art: ListingArt.clipboard, title: SocialStringsA.privacyPolicy, onTap: ProfileActions.openPrivacy),
              IconRow3D(art: ListingArt.clipboard, title: SocialStringsA.terms, divider: true, onTap: ProfileActions.openTerms),
            ]),
            Padding(
              padding: DS.gapInsets(l: 18, t: 30, r: 18),
              child: GradientPillButton(
                key: SettingsScreen.logoutKey,
                tone: ListingTone.coral,
                danger: true,
                label: SocialStringsA.logout,
                onTap: () => ProfileActions.confirmLogout(context),
              ),
            ),
            Padding(
              padding: DS.gapInsets(t: 14, b: 10),
              child: Center(
                child: TextLink(
                  key: SettingsScreen.deleteKey,
                  label: SocialStringsA.deleteAccount,
                  onTap: _auth.isLoading.value ? null : () => ProfileActions.confirmDeleteAccount(context),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _activity() {
    final rows = <({String art, String title, String route})>[
      if (_auth.canOpenRoute(AppRoutes.myTrips)) (art: ListingArt.luggage, title: SocialStringsA.myTrips, route: AppRoutes.myTrips),
      if (_auth.jobsBrowseEnabled && ProfileRows.showsJobsFeed(_auth.shellKind.value)) (art: ListingArt.briefcase, title: SocialStringsA.jobs, route: AppRoutes.jobs),
      if (_auth.canOpenRoute(AppRoutes.myJourneys)) (art: ListingArt.compass, title: SocialStringsA.myJourneys, route: AppRoutes.myJourneys),
      (art: ListingArt.warning, title: SocialStringsA.myReports, route: AppRoutes.myFiledReports),
    ];
    return _section(SocialStringsA.activityLabel, [
      for (var r = 0; r < rows.length; r++) IconRow3D(art: rows[r].art, title: rows[r].title, divider: r > 0, onTap: () => Get.toNamed(rows[r].route)),
    ]);
  }
}

class _PolicySheet extends StatefulWidget {
  const _PolicySheet({required this.current});

  final String current;

  @override
  State<_PolicySheet> createState() => _PolicySheetState();
}

class _PolicySheetState extends State<_PolicySheet> {
  late String _value = widget.current;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in MessagePolicies.all)
          Tap3D(
            tapKey: ValueKey('policy_$p'),
            onTap: () => setState(() => _value = p),
            label: SocialStringsA.policyLabel(p),
            selected: _value == p,
            exclude: true,
            child: Padding(
              padding: DS.sym(h: 4, v: 12),
              child: Row(
                children: [
                  Icon(_value == p ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      size: DS.s(22), color: _value == p ? BuddyLook.tealEnd : BuddyLook.checkOff),
                  Gap.h(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(SocialStringsA.policyLabel(p), style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                        if (p == MessagePolicies.everyone)
                          Text(SocialStringsA.everyoneLine, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Gap.v(12),
        GradientPillButton(
          key: const ValueKey('policy_save'),
          tone: BuddyLook.teal,
          label: SocialStringsA.save,
          onTap: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}
