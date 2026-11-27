import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_routes.dart';
import '../config/tab_shell.dart';
import '../controllers/auth_controller.dart';
import '../controllers/plan_controller.dart';
import '../design/design.dart';
import '../features/owner_core/data/owner_api.dart';
import '../features/owner_core/data/owner_result.dart';
import '../features/owner_core/session/owner_session_hooks.dart';
import '../screens/profile_screen.dart';
import '../utils/account_delete_message.dart';
import '../utils/app_toast.dart';

abstract final class AccountBlockerStrings {
  static const title = 'Cannot delete yet';
  static const subtitle = 'Sort these out first, then try again.';
  static const close = 'Close';
  static const openEnquiry = 'Open enquiry';
  static const openBooking = 'Open booking';
  static const openRequest = 'Open request';
  static const turnOff = 'Turn off';
  static const settleUp = 'Settle up';
  static const confirmedBooking = 'Confirmed booking';
  static const newEnquiry = 'New enquiry';
  static const acceptingOn = 'Accepting guests is on';
  static const availableOn = 'Available now is on';
  static const activeBooking = 'Active booking';
  static const travellerChoseYou = 'Traveller chose you';
  static const offlineFirst = 'Take your listing offline first.';
  static const confirmOrDecline = 'Confirm or decline the trip first.';
  static const couldNotTurnOff = 'Could not turn it off. Please try again.';
  static const cancelFirst = 'Cancel your subscription first';
  static const cancelSub = 'Your plan renews automatically. Cancel it in Google Play, then come back and delete your account.';
  static const manageInPlay = 'Manage in Google Play';
  static const cannotCancel = 'Cannot cancel? Contact support';
  static const justCancelled = 'Just cancelled? Try again in a minute.';
  static const cancelledNow = 'Subscription cancelled. You can delete your account now.';
}

abstract final class AccountBlockerActions {
  static const openEnquiry = 'OpenEnquiry';
  static const openTripReplies = 'OpenTripReplies';
  static const openTaxiBooking = 'OpenTaxiBooking';
  static const openTaxiStatus = 'OpenTaxiStatus';
  static const openTaxiOffer = 'OpenTaxiOffer';
  static const openTrip = 'OpenTrip';
  static const goOffline = 'GoOffline';
  static const settleUp = 'SettleUp';
  static const managePlay = 'ManagePlay';
  static const activeSubscription = 'ActiveSubscription';

  static String? buttonOf(AccountDeleteBlock b) => switch (b.action) {
        openEnquiry || openTripReplies => AccountBlockerStrings.openEnquiry,
        openTaxiBooking => AccountBlockerStrings.openBooking,
        openTaxiStatus => b.code == 'ActiveTaxiBooking' ? AccountBlockerStrings.openBooking : AccountBlockerStrings.openRequest,
        openTaxiOffer || openTrip => AccountBlockerStrings.openRequest,
        goOffline => AccountBlockerStrings.turnOff,
        settleUp => AccountBlockerStrings.settleUp,
        managePlay => AccountBlockerStrings.manageInPlay,
        _ => null,
      };

  static String titleOf(AccountDeleteBlock b) {
    final host = b.side == 'Host' || b.side == 'Driver';
    switch (b.code) {
      case 'ActiveStayBooking' when host:
        return AccountBlockerStrings.confirmedBooking;
      case 'OpenStayEnquiry' when host:
        return AccountBlockerStrings.newEnquiry;
      case 'ActiveTaxiBooking' when host:
        return AccountBlockerStrings.activeBooking;
      case 'SelectedTaxiOffer':
        return AccountBlockerStrings.travellerChoseYou;
      case activeSubscription:
        return AccountBlockerStrings.cancelFirst;
      case 'LiveListing':
        return b.args['listingKind'] == 'Taxi' ? AccountBlockerStrings.availableOn : AccountBlockerStrings.acceptingOn;
    }
    return AccountDeleteMessage.lineOf(b);
  }

  static String? subOf(AccountDeleteBlock b) {
    final title = titleOf(b);
    switch (b.code) {
      case 'LiveListing':
        return AccountBlockerStrings.offlineFirst;
      case 'SelectedTaxiOffer':
        return AccountBlockerStrings.confirmOrDecline;
      case activeSubscription:
        return b.message.contains(AccountBlockerStrings.justCancelled)
            ? '${AccountBlockerStrings.cancelSub}\n${AccountBlockerStrings.justCancelled}'
            : AccountBlockerStrings.cancelSub;
    }
    final line = b.message.isNotEmpty ? b.message : AccountDeleteMessage.lineOf(b);
    return line == title ? null : line;
  }
}

class AccountBlockersSheet extends StatefulWidget {
  const AccountBlockersSheet({super.key, required this.blocks});

  final List<AccountDeleteBlock> blocks;

  static Future<void> show(BuildContext context, List<AccountDeleteBlock> blocks) =>
      SheetFrame.show<void>(context, builder: (_) => AccountBlockersSheet(blocks: blocks));

  @override
  State<AccountBlockersSheet> createState() => _AccountBlockersSheetState();
}

class _AccountBlockersSheetState extends State<AccountBlockersSheet> with WidgetsBindingObserver {
  late final List<AccountDeleteBlock> _rows = List.of(widget.blocks);
  // Keyed by the block, not the row index: removing a row never moves a spinner (FX-27).
  final Set<String> _busy = {};

  static String _keyOf(AccountDeleteBlock b) => '${b.code}:${b.targetId ?? ''}:${b.args['listingKind'] ?? ''}';

  bool _recheck = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Google Play: one plan refresh; once auto-renew is off the row goes and deletion can be tried again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _recheck) {
      _recheck = false;
      _afterManage();
    }
  }

  Future<void> _manage() async {
    if (!Get.isRegistered<PlanController>()) return;
    _recheck = true;
    await Get.find<PlanController>().openManageSubscription();
  }

  Future<void> _afterManage() async {
    if (!Get.isRegistered<PlanController>()) return;
    final plan = Get.find<PlanController>();
    await plan.refreshPlan(force: true);
    if (!mounted) return;
    final play = plan.myPlan.value.play;
    if (play != null && play.autoRenewEnabled) return;
    setState(() => _rows.removeWhere((r) => r.code == AccountBlockerActions.activeSubscription));
    AppToast.info(AccountBlockerStrings.cancelledNow);
    if (_rows.isEmpty) Navigator.of(context).pop();
  }

  Future<void> _turnOff(AccountDeleteBlock b) async {
    final key = _keyOf(b);
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    final taxi = b.args['listingKind'] == 'Taxi';
    final r = await OwnerApi.put<void>(
      taxi ? '/taxis/me/availability' : '/stays/me/accepting',
      taxi ? {'isAvailable': false} : {'acceptingGuests': false},
      (_) {},
    );
    if (!mounted) return;
    setState(() => _busy.remove(key));
    if (r is OwnerOk<void>) {
      setState(() => _rows.remove(b));
      try {
        await OwnerSessionHooks.refreshHome();
      } catch (_) {}
      if (_rows.isEmpty && mounted) Navigator.of(context).pop();
    } else {
      final msg = r is OwnerRefused<void> ? r.message : null;
      AppToast.error(msg ?? AccountBlockerStrings.couldNotTurnOff);
    }
  }

  void _open(AccountDeleteBlock b) {
    final route = b.route;
    Navigator.of(context).pop();
    if (route == null) return;
    final auth = Get.find<AuthController>();
    final tab = TabShell.tabForRoute(auth.shellKind.value, route, b.args);
    if (tab != null) {
      auth.openTab(tab, intent: b.args);
      return;
    }
    if (route == AppRoutes.main) return;
    if (!auth.canOpenRoute(route)) return;
    Get.toNamed(route, arguments: b.args);
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      tone: ListingTone.indigo,
      art: ListingArt.warning,
      title: AccountBlockerStrings.title,
      subtitle: AccountBlockerStrings.subtitle,
      footer: SecondaryButton(
        label: AccountBlockerStrings.close,
        neutral: true,
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap.v(8),
          Container(
            decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: DS.shadows(ShadowTokens.elev1)),
            child: Column(
              children: [
                for (var i = 0; i < _rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: DS.s(14), endIndent: DS.s(14), color: Ink3D.line),
                  _BlockRow(
                    block: _rows[i],
                    busy: _busy.contains(_keyOf(_rows[i])),
                    onPressed: AccountBlockerActions.buttonOf(_rows[i]) == null
                        ? null
                        : () {
                            final b = _rows[i];
                            if (b.action == AccountBlockerActions.goOffline) {
                              _turnOff(b);
                            } else if (b.action == AccountBlockerActions.managePlay) {
                              _manage();
                            } else {
                              _open(b);
                            }
                          },
                  ),
                  if (_rows[i].code == AccountBlockerActions.activeSubscription)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: ProfileActions.contactSupport,
                        child: Text(AccountBlockerStrings.cannotCancel, style: Ink3D.text(12, FontWeight.w600, ListingTone.indigo.text, letterSpacing: 0)),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Gap.v(10),
        ],
      ),
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({required this.block, required this.busy, this.onPressed});

  final AccountDeleteBlock block;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final title = AccountBlockerActions.titleOf(block);
    final sub = AccountBlockerActions.subOf(block);
    final button = AccountBlockerActions.buttonOf(block);
    return Padding(
      padding: DS.sym(h: 14, v: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Ink3D.text(13.5, FontWeight.w700, Ink3D.title, height: 1.35, letterSpacing: 0)),
                if (sub != null) Text(sub, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, height: 1.4, letterSpacing: 0)),
              ],
            ),
          ),
          if (button != null) ...[
            Gap.h(10),
            PrimaryButton(label: button, compact: true, expand: false, loading: busy, onPressed: onPressed),
          ],
        ],
      ),
    );
  }
}
