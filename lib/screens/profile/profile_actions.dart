part of '../profile_screen.dart';

abstract final class ProfileActions {
  static const String supportEmail = 'supportbakhli@gmail.com';
  static const String _storeId = 'com.rentnearby.rentnearby';

  static Future<void> shareApp() async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Plan trips, find stays and taxis near you.\n'
            'https://play.google.com/store/apps/details?id=$_storeId',
        subject: 'Plan your next trip.',
      ),
    );
  }

  static Future<void> rateApp() async {
    final uri = Uri.parse('market://details?id=$_storeId');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(
        Uri.parse('https://play.google.com/store/apps/details?id=$_storeId'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  static Future<void> contactSupport() async {
    final uri = Uri(scheme: 'mailto', path: supportEmail, query: 'subject=Bakhli Support Request');
    if (!await launchUrl(uri)) {
      AppToast.error('Could not open email app. Please email $supportEmail');
    }
  }

  static void openPage(Widget page) {
    Get.key.currentState?.push(PageRouteBuilder<void>(
      transitionDuration: templateTransitionDuration,
      reverseTransitionDuration: templateTransitionDuration,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (ctx, a, s, child) => TemplateTransition().buildTransition(ctx, null, null, a, s, child),
    ));
  }

  static void openPrivacy() => openPage(const PrivacyPolicyScreen());

  static void openTerms() => openPage(const TermsOfServiceScreen());

  static Future<void> changePhone() async {
    final auth = Get.find<AuthController>();
    final result = await Get.toNamed(
      AppRoutes.phoneVerify,
      arguments: {'isChange': auth.user.value?.isPhoneVerified ?? false},
    );
    if (result == true) await auth.refreshProfile();
  }

  static Future<void> confirmLogout(BuildContext context) async {
    if (!await LogoutGuard.check(context)) return;
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _ProfileScreenState._dialog(
        RepliesEntrance(
          child: _ProfileSheet(
            tone: _ProfileScreenState._bad,
            art: ListingArt.airplane,
            title: 'Logout?',
            body: 'Are you sure you want to logout?',
            dialog: true,
            primaryLabel: 'Logout',
            onPrimary: () {
              Navigator.pop(ctx);
              Get.find<AuthController>().logout();
            },
            secondaryLabel: 'Cancel',
            onSecondary: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
  }

  static void confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _DeleteAccountDialog(
        onConfirm: () {
          Navigator.pop(ctx);
          _deleteAccount(context);
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  static Future<void> _deleteAccount(BuildContext context) async {
    final bad = _ProfileScreenState._bad;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: DesignColors.scrim,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: DS.sym(h: 36, v: 32),
            decoration: BoxDecoration(color: DesignColors.onPrimary, borderRadius: DS.circular(32)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: DS.s(48), height: DS.s(48), child: CircularProgressIndicator(strokeWidth: 3, color: bad.g2)),
              Gap.v(20),
              Text('Deleting your account...', style: Ink3D.text(15, FontWeight.w600, Ink3D.title).copyWith(decoration: TextDecoration.none)),
              Gap.v(6),
              Text('Please do not close the app.', style: Ink3D.text(12, FontWeight.w500, Ink3D.grey).copyWith(decoration: TextDecoration.none)),
            ]),
          ),
        ),
      ),
    );
    final blocked = await Get.find<AuthController>().deleteAccountBlocks();
    if (!context.mounted) return;
    if (Navigator.canPop(context)) Navigator.pop(context);
    if (blocked != null && blocked.isNotEmpty) AccountBlockersSheet.show(context, blocked);
  }
}
