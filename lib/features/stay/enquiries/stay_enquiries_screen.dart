import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/browse_item.dart';
import '../../../widgets/empty_state_view.dart';
import '../../../widgets/selectable_chip.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/trip_strings_h4.dart';
import '../../trip/utils/trip_format.dart';
import '../../trip/widgets/trip_shimmers.dart';
import '../../trip/widgets/trip_status.dart';
import '../../trip/widgets/trip_status_card.dart';
import '../setup/stay_option_sets.dart';
import 'stay_enquiries_controller.dart';
import 'stay_enquiry_actions.dart';
import 'stay_enquiry_button.dart';
import 'stay_enquiry_format.dart';
import 'stay_enquiry_strings.dart';

class StayEnquiriesScreen extends StatefulWidget {
  const StayEnquiriesScreen({super.key});

  @override
  State<StayEnquiriesScreen> createState() => _StayEnquiriesScreenState();
}

class _StayEnquiriesScreenState extends State<StayEnquiriesScreen> with WidgetsBindingObserver {
  final _ctrl = StayEnquiriesController.ensure();
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  final _highlight = RxnString();
  String? _targetId;
  Worker? _focusWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    final args = Get.arguments;
    _targetId = args is Map ? args['enquiryId']?.toString() : null;
    _ctrl.focusId.value = null;
    if (_ctrl.stay.value == null) _ctrl.ensureStay();
    _focusWorker = ever<String?>(_ctrl.focusId, (id) {
      if (id == null || !mounted) return;
      _ctrl.focusId.value = null;
      _flash(id);
    });
    _init();
  }

  @override
  void dispose() {
    _focusWorker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ctrl.refreshList();
  }

  Future<void> _init() async {
    final id = _targetId;
    _ctrl.bucket.value = StayEnquiryBucket.newOnes;
    if (id != null) {
      final bucket = await _ctrl.bucketFor(id);
      if (bucket != null) _ctrl.bucket.value = bucket;
    }
    await _ctrl.load();
    if (id == null || !mounted) return;
    _flash(id);
  }

  void _flash(String id) {
    _highlight.value = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 300));
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _highlight.value == id) _highlight.value = null;
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _ctrl.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(children: [
        _header(),
        _chips(),
        Obx(() => Get.find<AuthController>().staysEnabled ? const SizedBox.shrink() : _pausedNote()),
        Expanded(child: Obx(_body)),
      ]),
    );
  }

  Widget _header() => Container(
        decoration: const BoxDecoration(gradient: StayColors.gradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 20, 18),
            child: Row(children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(TripStrings.enquiries,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                  Obx(() {
                    final name = _ctrl.stay.value?.name;
                    return Text(name == null || name.isEmpty ? TripStrings.tripEnquiry : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.white70));
                  }),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _chips() {
    return Obx(() {
      final c = _ctrl.counts.value;
      final selected = _ctrl.bucket.value;
      final labels = {
        StayEnquiryBucket.newOnes: c.newCount > 0 ? TripStrings.newChip(c.newCount) : TripStrings.newPill,
        StayEnquiryBucket.offered: TripStrings.offeredChip,
        StayEnquiryBucket.confirmed: TripStrings.confirmedChip,
        StayEnquiryBucket.closed: TripStrings.closedChip,
      };
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final key in StayEnquiryBucket.all)
              SelectableChip(
                label: labels[key]!,
                selected: selected == key,
                activeColor: StayColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onTap: () => _ctrl.selectBucket(key),
              ),
          ]),
        ),
      );
    });
  }

  Widget _pausedNote() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
          child: const Text(TripStrings.pausedHere,
              style: TextStyle(fontSize: 12, color: AppColors.warningText, fontWeight: FontWeight.w500)),
        ),
      );

  Widget _body() {
    final items = _ctrl.items;
    final loading = _ctrl.loading.value;
    final failed = _ctrl.failed.value;
    final bucket = _ctrl.bucket.value;
    final highlight = _highlight.value;
    final bottom = AppInsets.bottomViewPadding(context) + 16;

    if (loading && items.isEmpty) {
      return _column(ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => TripShimmers.rowBox(height: 150, radius: 18),
      ));
    }
    if (items.isEmpty) {
      final empty = failed && _ctrl.executionDisabled.value
          ? EmptyStateView(
              icon: Iconsax.pause_circle,
              title: TripStrings.plannerOff,
              subtitle: TripStrings.plannerOffSubtitle,
              palette: StayColors.palette,
            )
          : failed
          ? EmptyStateView(
              icon: Iconsax.wifi_square,
              title: TripStrings.couldNotLoad,
              subtitle: TripStrings.checkConnection,
              onRetry: _ctrl.load,
              retryLabel: TripStrings.retry,
              palette: StayColors.palette,
            )
          : EmptyStateView(
              icon: Iconsax.message_question,
              title: _emptyTitle(bucket),
              subtitle: TripStrings.noEnquiriesSub,
              palette: StayColors.palette,
            );
      return RefreshIndicator(
        color: StayColors.accent,
        onRefresh: _ctrl.refreshList,
        child: _column(ListView(physics: const AlwaysScrollableScrollPhysics(), children: [empty])),
      );
    }
    final footer = _ctrl.loadingMore.value || _ctrl.loadMoreFailed.value ? 1 : 0;
    return RefreshIndicator(
      color: StayColors.accent,
      onRefresh: _ctrl.refreshList,
      child: _column(ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
        itemCount: items.length + footer,
        itemBuilder: (_, i) {
          if (i >= items.length) return _footer();
          final e = items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: KeyedSubtree(
              key: _keys.putIfAbsent(e.id, () => GlobalKey()),
              child: _EnquiryCard(enquiry: e, highlighted: highlight == e.id, ctrl: _ctrl),
            ),
          );
        },
      )),
    );
  }

  Widget _column(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: child),
      );

  Widget _footer() {
    if (_ctrl.loadMoreFailed.value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: _ctrl.loadMore,
            child: const Text('${StayEnquiryStrings.retryMore} · ${TripStrings.retry}'),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: StayColors.accent)),
      ),
    );
  }

  String _emptyTitle(String bucket) => switch (bucket) {
        StayEnquiryBucket.offered => TripStrings.noOffers,
        StayEnquiryBucket.confirmed => TripStrings.noConfirmed,
        StayEnquiryBucket.closed => TripStrings.nothingClosed,
        _ => TripStrings.noEnquiries,
      };
}

class _EnquiryCard extends StatelessWidget {
  const _EnquiryCard({required this.enquiry, required this.highlighted, required this.ctrl});

  final TripEnquiryModel enquiry;
  final bool highlighted;
  final StayEnquiriesController ctrl;

  static const int _maxChips = 6;

  @override
  Widget build(BuildContext context) {
    final e = enquiry;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.all(highlighted ? 2 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: highlighted ? StayColors.accent : Colors.transparent,
      ),
      child: TripStatusCard(
        status: e.display,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(StayEnquiryFormat.guest(e),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ),
            if ((e.traveller.id ?? '').isNotEmpty) _menu(context, e),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (e.isUrgent && e.isUnconfirmed) const TripStatusPill(TripDisplayStatus.asked, label: TripStrings.urgent),
            TripStatusPill(e.display, ownerSide: true),
          ]),
          const SizedBox(height: 8),
          Text(StayEnquiryFormat.summary(e),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4)),
          ..._chipsRow(e),
          ..._detail(e),
          ..._advanceLine(e),
          ..._actions(context, e),
        ]),
      ),
    );
  }

  Widget _menu(BuildContext context, TripEnquiryModel e) => SizedBox(
        width: 44,
        height: 44,
        child: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          tooltip: '',
          icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMedium),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (_) => StayEnquiryActions.reportTraveller(context, e),
          itemBuilder: (_) => const [
            PopupMenuItem<String>(
                value: 'report', height: 44, child: Text(TripStrings.reportTraveller, style: TextStyle(fontSize: 13))),
          ],
        ),
      );

  List<Widget> _chipsRow(TripEnquiryModel e) {
    final all = StayEnquiryFormat.chips(e);
    if (all.isEmpty) return const [];
    final shown = all.take(_maxChips).toList();
    final extra = all.length - shown.length;
    return [
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in shown) _chip(s),
        if (extra > 0) _chip(StayEnquiryStrings.moreChips(extra)),
      ]),
    ];
  }

  Widget _chip(String text) => Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppColors.neutralChip, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.neutralChipText)),
      );

  List<Widget> _detail(TripEnquiryModel e) {
    final lines = <String>[];
    final pb = e.phoneBooking;
    switch (e.display) {
      case TripDisplayStatus.confirmedByYou:
        if (pb != null) {
          lines.add(pb.agreedTotal > 0
              ? TripStrings.saysYouAgreed(BrowseItem.inr(pb.agreedTotal), e.datesLabel)
              : TripStrings.saysYouBooked(e.datesLabel));
          if (pb.roomName.isNotEmpty) lines.add('${TripStrings.room}: ${pb.roomName}');
        }
      case TripDisplayStatus.offered:
        final o = e.openOffer;
        if (o != null) lines.add(StayEnquiryStrings.offerPrice(BrowseItem.inr(o.total)));
      case TripDisplayStatus.confirmedByBoth:
        final t = e.agreedTotal ?? pb?.agreedTotal;
        if (t != null) lines.add('${TripStrings.total} ${BrowseItem.inr(t)}');
      default:
    }
    final counterPrice = e.pendingCounter?.pricePerNight;
    if (counterPrice != null) {
      lines.add(TripStringsH4.proposesPerRoom(StayEnquiryFormat.guest(e), BrowseItem.inr(counterPrice)));
    }
    final change = e.pendingChange;
    if (change != null) {
      final a = change.checkIn;
      final b = change.checkOut;
      lines.add('${TripStrings.changeRequest} · ${a != null && b != null ? TripFormat.dayMonthRange(a, b) : TripStrings.notAcceptedYet}');
    } else if (e.pendingRevised != null && e.display == TripDisplayStatus.confirmedByBoth) {
      lines.add('${TripStrings.revisedOffer} · ${TripStrings.notAcceptedYet}');
    }
    if (e.hostConfirm.answeredByLink) lines.add(StayEnquiryStrings.answeredByLink);
    if (lines.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      for (final l in lines)
        Text(l,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
    ];
  }

  static bool _checkInOpen(TripEnquiryModel e) {
    final cin = e.checkIn;
    if (cin == null) return false;
    final now = DateTime.now();
    return !DateTime(cin.year, cin.month, cin.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  List<Widget> _advanceLine(TripEnquiryModel e) {
    if (e.display != TripDisplayStatus.confirmedByBoth || !e.advance.hasRequest) return const [];
    final label = TripStatusVisuals.advanceLabel(e.advance);
    if (label.isEmpty) return const [];
    return [
      const SizedBox(height: 6),
      Text(label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: TripStatusVisuals.advanceText(e.advance.status))),
    ];
  }

  List<Widget> _actions(BuildContext context, TripEnquiryModel e) {
    final buttons = <Widget>[];
    final canOverride = e.hostConfirm.canOverride(DateTime.now());
    Widget btn(String label, StayEnquiryButtonKind kind, Future<bool> Function() run, {IconData? icon}) {
      return Obx(() => StayEnquiryButton(
            label: label,
            kind: kind,
            icon: icon,
            busy: ctrl.busyIds.contains(e.id),
            onTap: () => run(),
          ));
    }

    final chat = e.conversationId != null
        ? StayEnquiryButton(label: TripStrings.chat, icon: Iconsax.message, onTap: () => _openChat(e))
        : null;

    switch (e.display) {
      case TripDisplayStatus.asked:
      case TripDisplayStatus.offered:
        if (chat != null) buttons.add(chat);
        final counter = e.pendingCounter;
        if (counter != null) {
          buttons.add(btn(TripStrings.acceptPrice, StayEnquiryButtonKind.positive,
              () => StayEnquiryActions.sendOffer(context, e, counter: counter)));
          buttons.add(btn(TripStrings.sendDifferentOffer, StayEnquiryButtonKind.plain, () => StayEnquiryActions.sendOffer(context, e)));
        } else {
          final label = e.display == TripDisplayStatus.asked ? TripStrings.sendOffer : TripStrings.sendNewOffer;
          buttons.add(btn(label, StayEnquiryButtonKind.primary, () => StayEnquiryActions.sendOffer(context, e)));
        }
        buttons.add(btn(TripStrings.notAvailableAction, StayEnquiryButtonKind.negative, () => StayEnquiryActions.notAvailable(context, e)));
      case TripDisplayStatus.confirmedByYou:
        if (chat != null) buttons.add(chat);
        buttons.add(btn(TripStrings.yesConfirm, StayEnquiryButtonKind.positive, () => StayEnquiryActions.hostConfirm(context, e, confirm: true)));
        buttons.add(btn(TripStrings.notMe, StayEnquiryButtonKind.negative, () => StayEnquiryActions.hostConfirm(context, e, confirm: false)));
      case TripDisplayStatus.confirmedByBoth:
        if (chat != null) buttons.add(chat);
        final adv = e.advance;
        final change = e.pendingChange;
        final canRevise = e.pendingRevised == null && change == null && _checkInOpen(e);
        if (change != null) {
          buttons.add(btn(TripStrings.acceptChange, StayEnquiryButtonKind.positive,
              () => StayEnquiryActions.acceptChange(context, e, change.id)));
          buttons.add(btn(TripStrings.sendDifferentOffer, StayEnquiryButtonKind.plain,
              () => StayEnquiryActions.revisedOffer(context, e, changeRequest: change)));
          if (adv.isPending || adv.isProofSent) {
            buttons.add(btn(TripStrings.markAdvanceReceived, StayEnquiryButtonKind.positive, () => StayEnquiryActions.markReceived(context, e)));
            buttons.add(btn(TripStrings.notYet, StayEnquiryButtonKind.plain, () => StayEnquiryActions.notYet(context, e)));
          }
        } else if (adv.isPending || adv.isProofSent) {
          buttons.add(btn(TripStrings.markAdvanceReceived, StayEnquiryButtonKind.positive, () => StayEnquiryActions.markReceived(context, e)));
          buttons.add(btn(TripStrings.notYet, StayEnquiryButtonKind.plain, () => StayEnquiryActions.notYet(context, e)));
          buttons.add(btn(TripStrings.askAgain, StayEnquiryButtonKind.plain, () => StayEnquiryActions.askAdvance(context, e)));
        } else if (!adv.hasRequest) {
          buttons.add(btn(TripStrings.askForAdvance, StayEnquiryButtonKind.primary, () => StayEnquiryActions.askAdvance(context, e)));
        }
        if (canRevise && !(adv.isPending || adv.isProofSent)) {
          buttons.add(btn(TripStrings.revisedOffer, StayEnquiryButtonKind.plain, () => StayEnquiryActions.revisedOffer(context, e)));
        }
        if (canOverride && !adv.hasRequest) {
          buttons.add(btn(TripStrings.notMe, StayEnquiryButtonKind.negative, () => StayEnquiryActions.hostConfirm(context, e, confirm: false)));
        }
        if (!StayEnquiryBucket.hasEnded(e)) {
          buttons.add(btn(TripStrings.cancelBooking, StayEnquiryButtonKind.negative, () => StayEnquiryActions.cancel(context, e)));
        }
      case TripDisplayStatus.holdExpired:
        if (_checkInOpen(e)) {
          if (chat != null) buttons.add(chat);
          buttons.add(btn(TripStrings.markAdvanceReceived, StayEnquiryButtonKind.positive, () => StayEnquiryActions.markReceived(context, e)));
          if ((e.traveller.phone ?? '').isNotEmpty) {
            buttons.add(StayEnquiryButton(label: TripStrings.callGuest, onTap: () => StayEnquiryActions.callGuest(e)));
          }
        }
      case TripDisplayStatus.notMe:
        if (canOverride) {
          buttons.add(btn(TripStrings.yesConfirm, StayEnquiryButtonKind.positive, () => StayEnquiryActions.hostConfirm(context, e, confirm: true)));
        }
      default:
    }
    if (buttons.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: buttons),
    ];
  }

  void _openChat(TripEnquiryModel e) {
    Get.toNamed(AppRoutes.chatConversation, arguments: {
      'conversationId': e.conversationId,
      'enquiryId': e.id,
      'listingType': 'Stay',
      'stayTypeId': ctrl.stay.value?.stayTypeId,
      'otherPartyId': e.traveller.id ?? '',
      'otherPartyName': StayEnquiryFormat.guest(e),
      'listingTitle': e.listingName,
      'area': null,
      'isOwner': true,
      'status': 'Active',
      'isBlockedByMe': false,
    });
  }
}
