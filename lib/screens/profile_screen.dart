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

  static const int _count = 8;
  static const double _heroOverhang = 30;

  static final ListingTone _tone = ListingTone.indigo;
  static final ListingTone _bad = ListingTone.coral;
  static final LinearGradient _logoutGradient = LinearGradient(
    colors: [ListingTone.cC.g2, ListingTone.coral.g2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    return name.trim().characters.first.toUpperCase();
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
      backgroundColor: ListingPalette.indigo.page,
      resizeToAvoidBottomInset: false,
      body: TabEntrance(
        tab: AppTabs.profile,
        child: KitStatusBar(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: StaggerHost(
              count: _count,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hero(),
                  const SizedBox(height: _heroOverhang),
                        item(Obx(() => _auth.isOwner ? _buildPlansCard() : const SizedBox.shrink())),
                        item(_sectionGroup('ACCOUNT', [
                          _accountPhoneTile(),
                          _accountVisibilityTile(),
                          _accountRoleTile(),
                        ])),
                        item(Obx(() {
                          final jobs = _auth.jobsBrowseEnabled;
                          final journeys = _auth.taxisEnabled;
                          return _sectionGroup('ACTIVITY', [
                            if (jobs)
                              IconRow3D(art: ListingArt.luggage, title: 'Jobs', onTap: () => Get.toNamed(AppRoutes.jobs)),
                            if (journeys)
                              IconRow3D(
                                art: ListingArt.compass,
                                title: 'My Journeys',
                                divider: jobs,
                                onTap: () => Get.toNamed(AppRoutes.myJourneys),
                              ),
                            IconRow3D(
                              art: ListingArt.pushpin,
                              title: 'My Reports',
                              divider: jobs || journeys,
                              onTap: () => Get.toNamed(AppRoutes.myFiledReports),
                            ),
                          ]);
                        })),
                        item(_sectionGroup('SUPPORT', [
                          IconRow3D(art: ListingArt.speechBalloon, title: 'Contact Support', onTap: _contactSupport),
                          IconRow3D(art: ListingArt.star, title: 'Rate App', divider: true, onTap: _rateApp),
                          IconRow3D(art: ListingArt.airplane, title: 'Share App', divider: true, onTap: _shareApp),
                        ])),
                        item(_sectionGroup('LEGAL', [
                          IconRow3D(
                            art: ListingArt.clipboard,
                            title: 'Privacy Policy',
                            onTap: () => _openPage(const PrivacyPolicyScreen()),
                          ),
                          IconRow3D(
                            art: ListingArt.clipboard,
                            title: 'Terms of Service',
                            divider: true,
                            onTap: () => _openPage(const TermsOfServiceScreen()),
                          ),
                        ])),
                        item(_logoutButton()),
                        item(Padding(
                          padding: EdgeInsets.fromLTRB(18, 14, 18, BarMetrics.bodyBottomOf(context)),
                          child: Center(
                            child: Obx(() => TextLink(
                                  label: 'Delete Account',
                                  onTap: _auth.isLoading.value ? null : _confirmDeleteAccount,
                                )),
                          ),
                        )),
                ],
              ),
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
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (ctx, a, s, child) => TemplateTransition().buildTransition(ctx, null, null, a, s, child),
    ));
  }

  Widget _hero() {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final art = narrow ? 76.0 : 128.0;
    final halo = narrow ? 84.0 : 136.0;
    final reserve = halo + 16;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 28, reserve, 30),
          decoration: BoxDecoration(
            gradient: _tone.gradient,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            boxShadow: [BoxShadow(color: _tone.haloBase.withValues(alpha: Alpha.scrim), offset: const Offset(0, 8), blurRadius: 20)],
          ),
          child: Obx(() {
            final name = _auth.profileName.value;
            return Row(
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _avatar(name),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Semantics(
                          button: true,
                          label: 'Edit name',
                          excludeSemantics: true,
                          child: PressScale(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _openEditNameSheet,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(color: DesignColors.onPrimary, shape: BoxShape.circle, boxShadow: Ink3D.whiteBtn),
                                child: Icon(Icons.edit_rounded, size: 15, color: _tone.g2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeroName(name.trim().isNotEmpty ? name.trim() : 'Your Profile'),
                      const SizedBox(height: 4),
                      Obx(() => FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '+91 ${_auth.profilePhone.value}',
                              style: Ink3D.text(14, FontWeight.w400, DesignColors.onPrimary.withValues(alpha: Alpha.v90)),
                              maxLines: 1,
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
        Positioned(
          right: 8,
          bottom: -34,
          child: IgnorePointer(
            child: Container(
              width: halo,
              height: halo,
              decoration: BoxDecoration(shape: BoxShape.circle, color: DesignColors.onPrimary.withValues(alpha: Alpha.v18)),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: -30,
          child: IgnorePointer(child: ExcludeSemantics(child: Art3D(asset: ListingArt.backpack, size: art, shadowAlpha: 0.3))),
        ),
      ],
    );
  }

  Widget _avatar(String name) {
    final initials = _initials(name);
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: DesignColors.onPrimary.withValues(alpha: Alpha.v25),
        shape: BoxShape.circle,
        border: Border.all(color: DesignColors.onPrimary.withValues(alpha: Alpha.v60), width: 3),
      ),
      child: Center(
        child: initials.isNotEmpty
            ? Text(initials, maxLines: 1, style: Ink3D.text(28, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0))
            : ClipOval(
                child: Image.asset('assets/images/design/images/userImage.png', width: 54, height: 54, fit: BoxFit.cover)),
      ),
    );
  }

  Widget _gradientPill(String label, VoidCallback onTap) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: PressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                gradient: _tone.gradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: _tone.haloBase.withValues(alpha: Alpha.half), offset: const Offset(1.1, 4), blurRadius: 8)],
              ),
              child: Text(label, maxLines: 1, style: Ink3D.text(14, FontWeight.w700, DesignColors.onPrimary)),
            ),
          ),
        ),
      );

  Widget _planPill(String label, VoidCallback onTap) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 104),
        child: FittedBox(fit: BoxFit.scaleDown, child: _gradientPill(label, onTap)),
      );

  Widget _buildPlansCard() {
    final plans = Get.find<PlanController>();
    final compact = MediaQuery.sizeOf(context).width < 340 || MediaQuery.textScalerOf(context).scale(10) > 11.5;
    return WhiteCard3D(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Obx(() {
        final me = plans.myPlan.value;
        final name = me.planName.toLowerCase().contains('plan') ? me.planName : '${me.planName} plan';
        return _row(
          art: ListingArt.moneyBag,
          title: 'Plans & Billing',
          fitTitle: true,
          bold: true,
          below: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
          onTap: () => Get.toNamed(AppRoutes.plansBilling),
          trailing: me.paymentEnabled && !compact
              ? _planPill(me.hasPaidPlan ? 'Manage' : 'Upgrade', () => Get.toNamed(AppRoutes.plansBilling))
              : const Icon(Icons.chevron_right_rounded, size: 22, color: DesignColors.textDisabled),
        );
      }),
    );
  }

  Widget _sectionGroup(String label, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
          child: Text(label, style: Ink3D.text(12, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8)),
        ),
        WhiteCard3D(child: Column(children: children)),
      ],
    );
  }

  Widget _row({
    required String art,
    required String title,
    Widget? below,
    Widget? trailing,
    VoidCallback? onTap,
    bool divider = false,
    bool fitTitle = false,
    bool bold = false,
  }) {
    final style = Ink3D.text(16, bold ? FontWeight.w700 : FontWeight.w500, Ink3D.title, letterSpacing: 0, height: 1.3);
    final row = Container(
      decoration: divider ? const BoxDecoration(border: Border(top: BorderSide(color: Ink3D.line))) : null,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: _tone.haloBase.withValues(alpha: Alpha.v14), borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                Positioned(
                  left: -2,
                  top: -10,
                  child: ExcludeSemantics(
                    child: Art3D(asset: art, size: 66, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                fitTitle
                    ? FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(title, maxLines: 1, style: style))
                    : Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: style),
                if (below != null) Padding(padding: const EdgeInsets.only(top: 4), child: below),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(button: true, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row));
  }

  Widget _pill(String text, IconData icon, Color color, Color surface) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w600, color, letterSpacing: 0))),
        ]),
      );

  Widget _accountPhoneTile() {
    return Obx(() {
      final verified = _auth.profilePhoneVerified.value;
      final locked = _auth.profilePhoneChangeLocked.value;
      return _row(
        art: ListingArt.key,
        title: '+91 ${_auth.profilePhone.value}',
        fitTitle: true,
        below: verified
            ? _pill('Verified', Icons.verified_rounded, DesignColors.goodDeep, RepliesTone.goodSurface)
            : _pill('Not verified', Icons.warning_amber_rounded, DesignColors.warnDeep, RepliesTone.warnSurface),
        trailing: locked
            ? null
            : Semantics(
                button: true,
                label: 'Change',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openPhoneVerify,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: KitMetrics.touch),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Center(
                        widthFactor: 1,
                        child: Text('Change', maxLines: 1, style: Ink3D.text(13, FontWeight.w700, _tone.g2)),
                      ),
                    ),
                  ),
                ),
              ),
      );
    });
  }

  Widget _accountVisibilityTile() {
    return Obx(() => _row(
          art: ListingArt.star,
          title: 'Contact visible to public',
          below: _auth.isOwner
              ? Text(
                  'Always on for owners',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0, height: 1.35),
                )
              : null,
          divider: true,
          trailing: CupertinoSwitch(
            value: _auth.isOwner || (_auth.user.value?.isContactVisible ?? true),
            onChanged: _auth.isOwner || _auth.isLoading.value ? null : _confirmVisibilityChange,
            activeTrackColor: _tone.g2,
          ),
        ));
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
      return _row(
        art: RoleVisuals.iconAsset(roleKey),
        title: title,
        divider: true,
        below: Text(
          sub,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Ink3D.text(13, amber ? FontWeight.w600 : FontWeight.w400, amber ? DesignColors.warnDeep : Ink3D.grey, letterSpacing: 0, height: 1.35),
        ),
        trailing: locked ? null : const Icon(Icons.chevron_right_rounded, size: 22, color: DesignColors.textDisabled),
        onTap: locked ? null : () => Get.toNamed(AppRoutes.roleChange),
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

  static Widget _fieldBox(Widget field) => Container(
        decoration: BoxDecoration(
          color: DesignColors.onPrimary,
          borderRadius: const BorderRadius.all(Radius.circular(38)),
          boxShadow: Ink3D.softShadow,
        ),
        child: field,
      );

  Future<void> _openEditNameSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: _EditNameSheet(
          tone: _tone,
          initialName: _auth.profileName.value.trim(),
          onSave: (name) async {
            Navigator.pop(sheetCtx);
            final ok = await _auth.updateName(name);
            if (ok && mounted) AppToast.success('Profile updated');
          },
          onCancel: () => Navigator.pop(sheetCtx),
        ),
      ),
    );
  }

  Future<void> _confirmVisibilityChange(bool turningOn) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetCtx) => RepliesEntrance(
        child: _ProfileSheet(
          tone: _tone,
          art: ListingArt.star,
          title: turningOn ? 'Show your contact details?' : 'Hide your contact details?',
          body: turningOn
              ? 'Owners and renters will be able to see your phone number on your listings.'
              : "Owners and renters won't see your phone number on your listings anymore.",
          primaryLabel: turningOn ? 'Yes, show it' : 'Yes, hide it',
          onPrimary: () async {
            Navigator.pop(sheetCtx);
            final ok = await _auth.updateContactVisibility(turningOn);
            if (ok && mounted) AppToast.success('Saved');
          },
          secondaryLabel: 'Cancel',
          onSecondary: () => Navigator.pop(sheetCtx),
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 0),
      child: Semantics(
        button: true,
        label: 'Logout',
        excludeSemantics: true,
        child: PressScale(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _confirmLogout,
            child: Container(
              padding: const EdgeInsets.all(15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _logoutGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: _bad.g2.withValues(alpha: Alpha.v45), offset: const Offset(3, 8), blurRadius: 14)],
              ),
              child: Text('Logout', maxLines: 1, style: Ink3D.text(17, FontWeight.w700, DesignColors.onPrimary)),
            ),
          ),
        ),
      ),
    );
  }

  static Dialog _dialog(Widget child) => Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: child,
      );

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => _dialog(
        RepliesEntrance(
          child: _ProfileSheet(
            tone: _bad,
            art: ListingArt.airplane,
            title: 'Logout?',
            body: 'Are you sure you want to logout?',
            dialog: true,
            primaryLabel: 'Logout',
            onPrimary: () {
              Navigator.pop(ctx);
              _auth.logout();
            },
            secondaryLabel: 'Cancel',
            onSecondary: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _DeleteAccountDialog(
        onConfirm: () {
          Navigator.pop(ctx);
          _doDeleteAccount();
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
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
            decoration: BoxDecoration(color: DesignColors.onPrimary, borderRadius: BorderRadius.circular(32)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3, color: _bad.g2)),
              const SizedBox(height: 20),
              Text('Deleting your account...',
                  style: Ink3D.text(15, FontWeight.w600, Ink3D.title).copyWith(decoration: TextDecoration.none)),
              const SizedBox(height: 6),
              Text('Please do not close the app.',
                  style: Ink3D.text(12, FontWeight.w500, Ink3D.grey).copyWith(decoration: TextDecoration.none)),
            ]),
          ),
        ),
      ),
    );
    await _auth.deleteAccount();
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }
}

class _EditNameSheet extends StatefulWidget {
  const _EditNameSheet({
    required this.tone,
    required this.initialName,
    required this.onSave,
    required this.onCancel,
  });

  final ListingTone tone;
  final String initialName;
  final ValueChanged<String> onSave;
  final VoidCallback onCancel;

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _ctrl.text.trim().isNotEmpty;
    return RepliesEntrance(
      child: _ProfileSheet(
        tone: widget.tone,
        art: ListingArt.backpack,
        title: 'Edit name',
        primaryLabel: 'Save',
        onPrimary: canSave ? () => widget.onSave(_ctrl.text.trim()) : null,
        secondaryLabel: 'Cancel',
        onSecondary: widget.onCancel,
        extra: Padding(
          padding: const EdgeInsets.only(top: 18),
          child: _ProfileScreenState._fieldBox(TextFormField(
            controller: _ctrl,
            autofocus: true,
            maxLength: 100,
            inputFormatters: noEmojiInputFormatters,
            style: Ink3D.text(16, FontWeight.w500, Ink3D.title, letterSpacing: 0),
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              hintStyle: Ink3D.text(16, FontWeight.w400, Ink3D.hint, letterSpacing: 0),
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            ),
            onChanged: (_) => setState(() {}),
          )),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.onConfirm, required this.onCancel});

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = _ctrl.text.trim() == 'DELETE';
    return _ProfileScreenState._dialog(
      RepliesEntrance(
        child: _ProfileSheet(
          tone: _ProfileScreenState._bad,
          art: ListingArt.clipboard,
          title: 'Delete Account',
          dialog: true,
          primaryLabel: 'Delete Account',
          onPrimary: canDelete ? widget.onConfirm : null,
          secondaryLabel: 'Cancel',
          onSecondary: widget.onCancel,
          extra: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: _ProfileScreenState._bad.tint, borderRadius: BorderRadius.circular(16)),
                child: Text(
                  'This will permanently delete your account, listings, photos and plan. This cannot be undone.',
                  style: Ink3D.text(13, FontWeight.w500, _ProfileScreenState._bad.text, height: 1.5, letterSpacing: 0),
                ),
              ),
              const SizedBox(height: 18),
              Text('Type DELETE to confirm', style: Ink3D.text(13, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
              const SizedBox(height: 8),
              _ProfileScreenState._fieldBox(TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.characters,
                style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: 'DELETE',
                  hintStyle: Ink3D.text(15, FontWeight.w400, Ink3D.hint, letterSpacing: 2),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(38), borderSide: BorderSide(color: _ProfileScreenState._bad.g2, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroName extends StatelessWidget {
  const _HeroName(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const base = 22.0;
      var size = base;
      final scaler = MediaQuery.textScalerOf(context);
      var longest = 0.0;
      for (final w in text.split(RegExp(r'\s+'))) {
        final tp = TextPainter(
          text: TextSpan(text: w, style: Ink3D.text(base, FontWeight.w700, DesignColors.onPrimary)),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        if (tp.width > longest) longest = tp.width;
        tp.dispose();
      }
      final room = c.maxWidth - 6;
      if (longest > room && c.maxWidth.isFinite) size = (base * room / longest).clamp(8.0, base);
      return Text(
        text,
        style: Ink3D.text(size, FontWeight.w700, DesignColors.onPrimary, height: 1.25),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    });
  }
}

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({
    required this.tone,
    required this.art,
    required this.title,
    this.body = '',
    this.extra,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.dialog = false,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String body;
  final Widget? extra;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final bool dialog;

  static const double _artRoom = 56;
  static const BorderRadius _primaryRadius =
      BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomRight: Radius.circular(20), bottomLeft: Radius.circular(8));

  Widget _button(String label, VoidCallback? onTap, {required bool primary}) {
    return Padding(
      padding: EdgeInsets.only(top: primary ? 22 : 12),
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: PressScale(
            enabled: onTap != null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                constraints: BoxConstraints(minHeight: primary ? 54 : 50, minWidth: double.infinity),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                alignment: Alignment.center,
                decoration: primary
                    ? BoxDecoration(
                        borderRadius: _primaryRadius,
                        gradient: tone.gradient,
                        boxShadow: onTap == null
                            ? null
                            : [BoxShadow(color: tone.haloBase.withValues(alpha: Alpha.half), offset: const Offset(1.1, 6), blurRadius: 14)],
                      )
                    : BoxDecoration(color: DesignColors.onPrimary, borderRadius: BorderRadius.circular(18), boxShadow: Ink3D.softShadow),
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(primary ? 17 : 16, FontWeight.w700, primary ? DesignColors.onPrimary : tone.text)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = dialog ? 0.0 : MediaQuery.viewPaddingOf(context).bottom;
    final radius = dialog ? BorderRadius.circular(32) : const BorderRadius.vertical(top: Radius.circular(32));
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _artRoom),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: DesignColors.onPrimary,
              borderRadius: radius,
              boxShadow: [BoxShadow(color: TemplateTokens.black.withValues(alpha: Alpha.soft), offset: const Offset(0, -4), blurRadius: 24)],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(22, 66, 22, 22 + bottom),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Ink3D.text(22, FontWeight.w700, Ink3D.title, height: 1.3)),
                        if (body.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(body,
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Ink3D.text(15, FontWeight.w400, Ink3D.copy, height: 1.45, letterSpacing: 0)),
                          ),
                        ?extra,
                        _button(primaryLabel, onPrimary, primary: true),
                        _button(secondaryLabel, onSecondary, primary: false),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Art3D(asset: art, size: 104, halo: 112, haloColor: tone.haloBase.withValues(alpha: Alpha.v18), shadowAlpha: 0.3),
            ),
          ),
        ),
      ],
    );
  }
}
