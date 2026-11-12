import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import '../config/app_routes.dart';
import '../config/app_tabs.dart';
import '../controllers/auth_controller.dart';
import '../controllers/plan_controller.dart';
import '../utils/app_date_format.dart';
import '../utils/app_toast.dart';
import '../utils/input_formatters.dart';
import '../widgets/role_option_card.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = Get.find<AuthController>();

  static const String _d = 'assets/images/design/travel3d/';
  static const int _count = 8;

  static const _pairs = <(Color, Color)>[
    (DesignColors.skyDeepStart, DesignColors.lunchEnd),
    (DesignColors.sunriseDeep, DesignColors.sunriseDeepEnd),
    (DesignColors.roseDeepStart, DesignColors.roseDeep),
    (DesignColors.duskDeepStart, DesignColors.dinnerStart),
  ];

  static final TextStyle _rowTitle = TypeTokens.style(14, FontWeight.w600, color: DesignColors.textStrong, letterSpacing: 0.2);
  static final TextStyle _sheetTitle = TypeTokens.style(18, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.2);
  static final TextStyle _body = TypeTokens.style(14, FontWeight.w500, color: DesignColors.textGrey, height: 1.5);
  static const BorderRadius _dialogShape = CardRadius.hero;
  static const RoundedRectangleBorder _sheetShape = RoundedRectangleBorder(borderRadius: CardRadius.sheet);
  static const KitTone _badTone = KitTone.danger;

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  Future<void> _shareApp() async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Plan trips, find stays and taxis near you.\n'
            'https://play.google.com/store/apps/details?id=com.rentnearby.rentnearby',
        subject: 'Plan your next trip.',
      ),
    );
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse('market://details?id=com.rentnearby.rentnearby');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=com.rentnearby.rentnearby'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'supportbakhli@gmail.com',
      query: 'subject=Bakhli Support Request',
    );
    if (!await launchUrl(uri)) {
      AppToast.error('Could not open email app. Please email supportbakhli@gmail.com');
    }
  }

  @override
  Widget build(BuildContext context) {
    var i = 0;
    Widget item(Widget w) => StaggerItem(index: i++, child: w);
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      resizeToAvoidBottomInset: false,
      body: TabEntrance(
        tab: AppTabs.profile,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: StaggerHost(
            count: _count,
            child: Column(
              children: [
                item(_hero()),
                item(Obx(() => _auth.isOwner ? _buildPlansCard() : const SizedBox(height: KitMetrics.sectionGap))),
                item(_sectionGroup('ACCOUNT', [
                  _accountPhoneTile(),
                  _divider(),
                  _accountVisibilityTile(),
                  _divider(),
                  _accountRoleTile(),
                ])),
                item(_sectionGroup('ACTIVITY', [
                  Obx(() => _auth.jobsBrowseEnabled
                      ? Column(children: [
                          _legalTile(asset: '${_d}luggage.png', pair: 1, label: 'Jobs', onTap: () => Get.toNamed(AppRoutes.jobs)),
                          _divider(),
                        ])
                      : const SizedBox.shrink()),
                  Obx(() => _auth.taxisEnabled
                      ? Column(children: [
                          _legalTile(asset: '${_d}compass.png', pair: 0, label: 'My Journeys', onTap: () => Get.toNamed(AppRoutes.myJourneys)),
                          _divider(),
                        ])
                      : const SizedBox.shrink()),
                  _legalTile(asset: '${_d}pushpin.png', pair: 2, label: 'My Reports', onTap: () => Get.toNamed(AppRoutes.myFiledReports)),
                ])),
                item(_sectionGroup('SUPPORT', [
                  _legalTile(asset: '${_d}speech_balloon.png', pair: 0, label: 'Contact Support', onTap: _contactSupport),
                  _divider(),
                  _legalTile(asset: '${_d}star.png', pair: 1, label: 'Rate App', onTap: _rateApp),
                  _divider(),
                  _legalTile(asset: '${_d}airplane.png', pair: 3, label: 'Share App', onTap: _shareApp),
                ])),
                item(_sectionGroup('LEGAL', [
                  _legalTile(
                    asset: '${_d}key.png',
                    pair: 0,
                    label: 'Privacy Policy',
                    onTap: () => _openPage(const PrivacyPolicyScreen()),
                  ),
                  _divider(),
                  _legalTile(
                    asset: '${_d}clipboard.png',
                    pair: 1,
                    label: 'Terms of Service',
                    onTap: () => _openPage(const TermsOfServiceScreen()),
                  ),
                ])),
                item(_logoutButton()),
                item(Padding(
                  padding: EdgeInsets.fromLTRB(KitMetrics.gutter, 0, KitMetrics.gutter,
                      BarMetrics.bodyBottomOf(context)),
                  child: Obx(() => TextLink(
                        label: 'Delete Account',
                        onTap: _auth.isLoading.value ? null : _confirmDeleteAccount,
                      )),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPage(Widget page) {
    Get.key.currentState?.push(PageRouteBuilder<void>(
      transitionDuration: templateTransitionDuration,
      reverseTransitionDuration: templateTransitionDuration,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (ctx, a, s, child) => TemplateTransition().buildTransition(ctx, null, null, a, s, child),
    ));
  }

  Widget _divider() => const Divider(height: 1, indent: 68, color: DesignColors.dividerSoft);

  Widget _hero() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 120),
      margin: EdgeInsets.fromLTRB(KitMetrics.gutter, MediaQuery.of(context).padding.top + 16, KitMetrics.gutter, KitMetrics.sectionGap),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[DesignColors.primary, DesignColors.statusOwn],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: CardRadius.hero,
        boxShadow: ShadowTokens.glow(DesignColors.primary),
      ),
      child: Obx(() {
        final name = _auth.profileName.value;
        return Row(
          children: [
            _avatarFallback(name),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name.trim().isNotEmpty ? name.trim() : 'Your Profile',
                          style: TypeTokens.style(22, FontWeight.w700, color: DesignColors.surface),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PressScale(
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _openEditNameSheet,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(color: DesignColors.whiteSoft, shape: BoxShape.circle),
                            child: const Icon(Icons.edit, size: 14, color: DesignColors.surface),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Obx(() => Text(
                        '+91 ${_auth.profilePhone.value}',
                        style: TypeTokens.onGradientBody.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _avatarFallback(String name) {
    final initials = _initials(name);
    return Container(
      width: 84,
      height: 84,
      decoration: const BoxDecoration(color: DesignColors.whiteSoft, shape: BoxShape.circle),
      child: Center(
        child: initials.isNotEmpty
            ? Text(initials, style: TypeTokens.style(30, FontWeight.w700, color: DesignColors.surface))
            : ClipOval(
                child: Image.asset('assets/images/design/images/userImage.png', width: 64, height: 64, fit: BoxFit.cover)),
      ),
    );
  }

  Widget _tileIcon(String asset, int pair) {
    final (start, end) = _pairs[pair % _pairs.length];
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: KitMetrics.tileSmall,
        gradient: LinearGradient(colors: [start, end], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Image.asset(asset),
    );
  }

  Widget _chevron() => const Icon(Icons.chevron_right_rounded, size: 22, color: DesignColors.textDisabled);

  Widget _buildPlansCard() {
    final plans = Get.find<PlanController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 0, KitMetrics.gutter, KitMetrics.sectionGap),
      child: SectionTile(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        onTap: () => Get.toNamed(AppRoutes.plansBilling),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: KitMetrics.tileSmall,
                gradient: const LinearGradient(
                    colors: [DesignColors.sunriseDeep, DesignColors.sunriseDeepEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Image.asset(TravelIcon.money),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plans & Billing',
                      style: TypeTokens.style(11, FontWeight.w600, color: DesignColors.sunriseDeepEnd, letterSpacing: 0.2)),
                  const SizedBox(height: 2),
                  Obx(() => Text(plans.myPlan.value.planName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _rowTitle)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Obx(() {
              final me = plans.myPlan.value;
              if (!me.paymentEnabled) return _chevron();
              return PillAction(
                label: me.hasPaidPlan ? 'Manage' : 'Upgrade',
                filled: true,
                height: 36,
                onTap: () => Get.toNamed(AppRoutes.plansBilling),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _sectionGroup(String label, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 0, KitMetrics.gutter, KitMetrics.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label,
                style: TypeTokens.style(12, FontWeight.w700, color: TypeTokens.secondary, letterSpacing: 0.8)),
          ),
          SectionTile(
            padding: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, IconData icon, Color color, Color surface) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: surface, borderRadius: CardRadius.pill),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(text, style: TypeTokens.style(11, FontWeight.w600, color: color)),
        ]),
      );

  Widget _accountPhoneTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _tileIcon('${_d}round_pushpin.png', 0),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() => Text('+91 ${_auth.profilePhone.value}', style: _rowTitle)),
                const SizedBox(height: 4),
                Obx(() {
                  final verified = _auth.profilePhoneVerified.value;
                  return verified
                      ? _pill('Verified', Icons.verified_rounded, DesignColors.goodDeep, RepliesTone.goodSurface)
                      : _pill('Not verified', Icons.warning_amber_rounded, DesignColors.warnDeep, RepliesTone.warnSurface);
                }),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Obx(() {
            if (!_auth.profilePhoneChangeLocked.value) {
              return TextLink(label: 'Change', onTap: _openPhoneVerify);
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _accountVisibilityTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _tileIcon(TravelIcon.map, 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Contact visible to public', style: _rowTitle),
              const SizedBox(height: 2),
              Obx(() => Text(_auth.isOwner ? 'Always on for owners' : 'Show call & WhatsApp on your listings',
                  style: TypeTokens.caption)),
            ]),
          ),
          Obx(() => CupertinoSwitch(
                value: _auth.isOwner || (_auth.user.value?.isContactVisible ?? true),
                onChanged: _auth.isOwner || _auth.isLoading.value ? null : _confirmVisibilityChange,
                activeTrackColor: DesignColors.primary,
              )),
        ],
      ),
    );
  }

  Widget _accountRoleTile() {
    return Obx(() {
      final roleKey = _auth.roleKey.value;
      final u = _auth.user.value;
      final locked = _auth.roleChangeLocked;
      final blockedUntil = u?.roleRequestBlockedUntil;
      final String title;
      final String sub;
      var amber = false;
      if (locked) {
        title = 'Current role';
        sub = RoleVisuals.displayName(roleKey);
      } else {
        title = 'Change role';
        if (u?.hasPendingRoleRequest ?? false) {
          sub = 'Request pending';
          amber = true;
        } else if (blockedUntil != null) {
          sub = 'Try again after ${AppDateFormat.dateTime(blockedUntil)}';
          amber = true;
        } else if (u?.hasRejectedRoleRequest ?? false) {
          sub = 'Request rejected';
          amber = true;
        } else if (!_auth.roleTabActive) {
          sub = 'Paused';
          amber = true;
        } else {
          sub = 'Now: ${RoleVisuals.displayName(roleKey)}';
        }
      }
      final tone = RoleOptionCard.toneOf(roleKey);
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: locked ? null : () => Get.toNamed(AppRoutes.roleChange),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(borderRadius: KitMetrics.tileSmall, gradient: tone.gradient),
                  child: Image.asset(RoleVisuals.iconAsset(roleKey)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _rowTitle),
                      const SizedBox(height: 2),
                      Text(sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(11, FontWeight.w500,
                              color: amber ? DesignColors.warnDeep : TypeTokens.secondary)),
                    ],
                  ),
                ),
                if (!locked) _chevron(),
              ],
            ),
          ),
        ),
      );
    });
  }

  Future<void> _openPhoneVerify() async {
    final result = await Get.toNamed(
      AppRoutes.phoneVerify,
      arguments: {'isChange': _auth.user.value?.isPhoneVerified ?? false},
    );
    if (result == true) {
      await _auth.refreshProfile();
    }
  }

  Widget _grabber() => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: DesignColors.tint(DesignColors.textGrey, Alpha.half), borderRadius: CardRadius.pill),
        ),
      );

  Widget _ghostButton(String label, VoidCallback onTap) =>
      SecondaryButton(label: label, onPressed: onTap, neutral: true);

  Widget _fieldBox(Widget field) => Container(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(38)),
          boxShadow: ShadowTokens.elev1,
        ),
        child: field,
      );

  Widget _halo(String asset, Color tone, {double size = 60}) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.2),
        decoration: BoxDecoration(color: DesignColors.tint(tone, Alpha.tint), shape: BoxShape.circle),
        child: Image.asset(asset),
      );

  Future<void> _openEditNameSheet() async {
    final ctrl = TextEditingController(text: _auth.profileName.value.trim());
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DesignColors.surface,
      shape: _sheetShape,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(KitMetrics.gutter, 20, KitMetrics.gutter, 24 + MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: StatefulBuilder(builder: (sheetCtx, setSheetState) {
          final canSave = ctrl.text.trim().isNotEmpty;
          return RepliesEntrance(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _grabber(),
                const SizedBox(height: 20),
                Text('Edit name', style: _sheetTitle),
                const SizedBox(height: 16),
                _fieldBox(TextFormField(
                  controller: ctrl,
                  autofocus: true,
                  maxLength: 100,
                  inputFormatters: noEmojiInputFormatters,
                  style: TypeTokens.style(16, FontWeight.w400, color: DesignColors.textStrong),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(10),
                      child: ClipOval(child: Image.asset('assets/images/design/images/userImage.png', width: 24, height: 24)),
                    ),
                    hintText: 'Enter your full name',
                    hintStyle: TypeTokens.style(16, FontWeight.w400, color: DesignColors.textMuted),
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  onChanged: (_) => setSheetState(() {}),
                )),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _ghostButton('Cancel', () => Navigator.pop(sheetCtx))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Save',
                      onPressed: canSave
                          ? () async {
                              final name = ctrl.text.trim();
                              Navigator.pop(sheetCtx);
                              final ok = await _auth.updateName(name);
                              if (ok && mounted) AppToast.success('Profile updated');
                            }
                          : null,
                    ),
                  ),
                ]),
              ],
            ),
          );
        }),
      ),
    ).whenComplete(() => ctrl.dispose());
  }

  Future<void> _confirmVisibilityChange(bool turningOn) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: DesignColors.surface,
      shape: _sheetShape,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(KitMetrics.gutter, 20, KitMetrics.gutter, 24 + MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: RepliesEntrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grabber(),
              const SizedBox(height: 20),
              _halo(TravelIcon.map, DesignColors.primary, size: 56),
              const SizedBox(height: 14),
              Text(turningOn ? 'Show your contact details?' : 'Hide your contact details?', style: _sheetTitle),
              const SizedBox(height: 8),
              Text(
                turningOn
                    ? 'Owners and renters will be able to see your call and WhatsApp number on your listings.'
                    : "Owners and renters won't see your call or WhatsApp number on your listings anymore.",
                style: _body,
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _ghostButton('Cancel', () => Navigator.pop(sheetCtx))),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: turningOn ? 'Yes, show it' : 'Yes, hide it',
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      final ok = await _auth.updateContactVisibility(turningOn);
                      if (ok && mounted) AppToast.success('Saved');
                    },
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legalTile({required String asset, required int pair, required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: DesignColors.splash,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            _tileIcon(asset, pair),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: _rowTitle)),
            _chevron(),
          ]),
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 0, KitMetrics.gutter, KitMetrics.cardGap),
      child: SectionTile(
        onTap: _confirmLogout,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: RepliesTone.bad, size: 18),
            const SizedBox(width: 8),
            Text('Logout', style: TypeTokens.style(16, FontWeight.w600, color: RepliesTone.bad)),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: const RoundedRectangleBorder(borderRadius: _dialogShape),
        backgroundColor: DesignColors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: RepliesEntrance(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _halo('${_d}airplane.png', RepliesTone.bad),
              const SizedBox(height: 16),
              Text('Logout?', style: _sheetTitle),
              const SizedBox(height: 8),
              Text('Are you sure you want to logout?', style: _body, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _ghostButton('Cancel', () => Navigator.pop(ctx))),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: 'Logout',
                    tone: _badTone,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _auth.logout();
                    },
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setDialogState) {
        final canDelete = confirmCtrl.text.trim() == 'DELETE';
        return Dialog(
          shape: const RoundedRectangleBorder(borderRadius: _dialogShape),
          backgroundColor: DesignColors.surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: RepliesEntrance(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _halo('assets/images/design/fitness_app/burned.png', RepliesTone.bad)),
                  const SizedBox(height: 16),
                  Center(child: Text('Delete Account', style: _sheetTitle)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: RepliesTone.badSurface,
                      borderRadius: CardRadius.tile,
                      border: Border.all(color: DesignColors.tint(RepliesTone.bad, Alpha.soft)),
                    ),
                    child: Text(
                      'This will permanently delete your account, listings, photos and plan. This cannot be undone.',
                      style: TypeTokens.style(12, FontWeight.w500, color: RepliesTone.bad, height: 1.55),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Type DELETE to confirm',
                      style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.textGrey)),
                  const SizedBox(height: 8),
                  _fieldBox(TextField(
                    controller: confirmCtrl,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    textCapitalization: TextCapitalization.characters,
                    style: TypeTokens.style(15, FontWeight.w600, color: DesignColors.textStrong, letterSpacing: 2),
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      hintStyle: TypeTokens.style(15, FontWeight.w400, color: DesignColors.textMuted, letterSpacing: 2),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(38),
                          borderSide: const BorderSide(color: RepliesTone.bad, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                  )),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(child: _ghostButton('Cancel', () => Navigator.pop(ctx))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Delete Account',
                        tone: _badTone,
                        onPressed: canDelete
                            ? () {
                                Navigator.pop(ctx);
                                _doDeleteAccount();
                              }
                            : null,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      }),
    ).whenComplete(() => confirmCtrl.dispose());
  }

  Future<void> _doDeleteAccount() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: DesignColors.scrim,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            decoration: BoxDecoration(color: DesignColors.surface, borderRadius: _dialogShape),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3, color: RepliesTone.bad)),
              const SizedBox(height: 20),
              Text('Deleting your account...',
                  style: TypeTokens.style(15, FontWeight.w600, color: DesignColors.textStrong)
                      .copyWith(decoration: TextDecoration.none)),
              const SizedBox(height: 6),
              Text('Please do not close the app.',
                  style: TypeTokens.style(12, FontWeight.w500, color: DesignColors.textSecondary)
                      .copyWith(decoration: TextDecoration.none)),
            ]),
          ),
        ),
      ),
    );
    await _auth.deleteAccount();
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }
}
