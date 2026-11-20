import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../buddy_navigation.dart';
import '../../shared/buddy_look.dart';
import '../../shared/models/person_models.dart';
import '../../shared/widgets/buddy_bottom_bar.dart';
import '../../shared/widgets/buddy_confirm_box.dart';
import '../../shared/widgets/buddy_page.dart';
import '../../shared/widgets/buddy_snack.dart';
import '../../shared/widgets/segment_tabs.dart';
import '../../sharing/data/trip_members_api.dart';
import '../../username_actions.dart';
import '../../widgets/username_qr_sheet.dart';
import '../buddies_strings.dart';
import '../buddy_me.dart';
import '../controllers/buddies_controller.dart';
import '../controllers/buddy_find_controller.dart';
import '../controllers/buddy_requests_controller.dart';
import '../controllers/buddy_summary_controller.dart';
import '../data/buddies_api.dart';
import '../models/buddy_models.dart';
import '../widgets/block_dialog.dart';
import '../widgets/buddies_header_menu.dart';
import '../widgets/buddy_menu_sheet.dart';
import '../widgets/find_tab.dart';
import '../widgets/my_buddies_tab.dart';
import '../widgets/person_menu_sheet.dart';
import '../widgets/report_sheet.dart';
import '../widgets/requests_tab.dart';
import '../widgets/trip_pick_sheet.dart';

class BuddiesScreen extends StatefulWidget {
  const BuddiesScreen({super.key, this.tab = 'buddies', this.query, this.source, this.api = const BuddiesApi(), this.tripApi = const TripMembersApi()});

  final String tab;
  final String? query;
  final String? source;
  final BuddiesApi api;
  final TripMembersApi tripApi;

  static int tabIndex(String tab) => switch (tab) {
        'requests' => 1,
        'find' => 2,
        _ => 0,
      };

  @override
  State<BuddiesScreen> createState() => _BuddiesScreenState();
}

class _BuddiesScreenState extends State<BuddiesScreen> {
  late final String _tag = 'buddies-${identityHashCode(this)}';
  late final BuddiesController _buddies;
  late final BuddyRequestsController _requests;
  late final BuddyFindController _find;

  @override
  void initState() {
    super.initState();
    final q = widget.query;
    final start = q != null && q.isNotEmpty ? 2 : BuddiesScreen.tabIndex(widget.tab);
    _buddies = Get.put(BuddiesController(api: widget.api, initialTab: start), tag: _tag);
    _requests = Get.put(BuddyRequestsController(api: widget.api), tag: _tag);
    _find = Get.put(BuddyFindController(api: widget.api), tag: _tag);
    _find.onNote = _snack;
    _requests.onNote = _snack;
    _requests.onAccepted = _accepted;
    if (q != null && q.isNotEmpty) {
      _find.search(raw: q, source: widget.source == BuddySource.qr ? BuddySource.qr : BuddySource.search);
    }
  }

  @override
  void dispose() {
    BuddySnack.hide();
    Get.delete<BuddiesController>(tag: _tag);
    Get.delete<BuddyRequestsController>(tag: _tag);
    Get.delete<BuddyFindController>(tag: _tag);
    super.dispose();
  }

  void _snack(String text, {bool danger = false}) {
    if (!mounted) return;
    BuddySnack.show(context, text, icon: danger ? BuddiesStrings.alertMark : BuddySnack.tick, danger: danger, bottom: _buddies.tab.value == 0 ? 104 : 24);
  }

  void _accepted(BuddyPerson p) {
    _buddies.tab.value = 0;
    _buddies.load();
    _snack(BuddiesStrings.nowYourBuddy(p.name));
  }

  void _goFind() {
    _buddies.tab.value = 2;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _find.boxEnabled) _find.focus.requestFocus();
    });
  }

  void _afterBlocked(BuddyPerson p, {bool snack = true}) {
    _buddies.dropPerson(p.userId);
    _requests.personBlocked(p.userId);
    _find.personBlocked(p.userId);
    BuddySummaryController.maybe?.load();
    if (snack) _snack(BuddiesStrings.blocked(p.name));
  }

  Future<void> _block(BuddyPerson p, String ctx) async {
    final ok = await BlockDialog.show(context, person: p, contextName: ctx, api: widget.api);
    if (ok) _afterBlocked(p);
  }

  Future<void> _report(BuddyPerson p, String ctx) async {
    final r = await ReportDialog.show(context, person: p, contextName: ctx, api: widget.api);
    if (r == null) return;
    if (r == ReportOutcome.reportedAndBlocked) _afterBlocked(p, snack: false);
    _snack(BuddiesStrings.reportSent);
  }

  Future<void> _openBuddy(BuddyPerson p) async {
    final a = await BuddyMenuSheet.show(context, p);
    if (!mounted || a == null) return;
    switch (a) {
      case BuddyMenuAction.invite:
        final r = await TripPickSheet.show(context, p, api: widget.tripApi);
        if (!mounted) return;
        switch (r) {
          case TripPickResult.invited:
            _snack(BuddiesStrings.inviteSentTo(p.name));
          case TripPickResult.planATrip:
            BuddyNavigation.openPlanATrip();
          case TripPickResult.buddyGone:
            _buddies.load();
          case null:
            break;
        }
      case BuddyMenuAction.remove:
        final ok = await BuddyConfirmBox.ask(
          context,
          art: BuddyArt.bust,
          title: BuddiesStrings.removeTitle(p.name),
          body: BuddiesStrings.removeBody,
          confirmLabel: BuddiesStrings.remove,
          confirmKind: ConfirmKind.danger,
        );
        if (!ok || !mounted) return;
        if (await _buddies.remove(p.userId)) {
          _find.personRemoved(p.userId);
          _snack(BuddiesStrings.removed(p.name));
        }
      case BuddyMenuAction.block:
        await _block(p, BuddyContext.buddy);
      case BuddyMenuAction.report:
        await _report(p, BuddyContext.buddy);
    }
  }

  Future<void> _openRequestMenu(ReceivedRequest r) async {
    final a = await PersonMenuSheet.show(context, r.person);
    if (!mounted || a == null) return;
    switch (a) {
      case PersonMenuAction.block:
        await _block(r.person, BuddyContext.request);
      case PersonMenuAction.report:
        await _report(r.person, BuddyContext.request);
    }
  }

  Future<void> _scan() async {
    final u = await BuddyNavigation.openScan();
    if (!mounted) return;
    if (u == null) {
      _find.focus.requestFocus();
      return;
    }
    await _find.searchScanned(u);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.metrics.extentAfter > 200) return false;
    switch (_buddies.tab.value) {
      case 0:
        _buddies.loadMore();
      case 1:
        _requests.loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final me = BuddyMe.read();
    final summary = BuddySummaryController.maybe;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Obx(() {
        final tab = _buddies.tab.value;
        final s = summary?.summary.value ?? BuddySummary.empty;
        final count = _buddies.state.value == BuddyListState.ready ? _buddies.count.value : s.buddies;
        return BuddyPage(
          title: BuddiesStrings.title,
          subtitle: BuddiesStrings.subtitle,
          onBack: Get.back,
          trailing: [BuddiesHeaderMenu(blockedCount: () => summary?.summary.value.blocked ?? 0, onBlocked: BuddyNavigation.openBlocked)],
          top: SegmentTabs(
            labels: [BuddiesStrings.myBuddiesCount(count), BuddiesStrings.tabRequests, BuddiesStrings.tabFind],
            selected: tab,
            tone: BuddyLook.teal,
            counts: {1: s.receivedPending},
            onTap: (i) => _buddies.tab.value = i,
          ),
          body: switch (tab) {
            1 => RequestsTab(controller: _requests, onMenu: _openRequestMenu),
            2 => FindTab(
                controller: _find,
                me: me,
                onScan: _scan,
                onMyQr: () => UsernameQrSheet.show(context, username: me.username ?? '', name: me.name),
                onOpenBuddy: _openBuddy,
              ),
            _ => MyBuddiesTab(
                controller: _buddies,
                me: me,
                onCopy: () => UsernameActions.copy(me.username ?? ''),
                onOpenBuddy: (b) => _openBuddy(b.person),
              ),
          },
          bottomBar: tab == 0
              ? BuddyBottomBar(children: [GradientPillButton(tone: BuddyLook.teal, label: BuddiesStrings.findABuddy, onTap: _goFind)])
              : null,
        );
      }),
    );
  }
}
