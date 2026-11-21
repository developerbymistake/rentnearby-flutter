import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_insets.dart';
import '../../../config/app_tabs.dart';
import '../../../config/tab_slot.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_trip_replies.dart';
import '../../../widgets/notification_off_banner.dart';
import '../../../widgets/tab_header.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../../stay/enquiries/stay_enquiries_controller.dart';
import '../../trip/trip_strings.dart';
import '../strings/stay_work_strings.dart';
import 'stay_owner_enquiry_card.dart';
import 'stay_quiet_week_banner.dart';
import 'widgets/enquiry_card_parts.dart';

const double _actionFont = 14;

class StayEnquiriesTab extends StatefulWidget {
  const StayEnquiriesTab({super.key});

  static const Map<String, String> bucketArgs = {
    'New': StayEnquiryBucket.newOnes,
    'Offered': StayEnquiryBucket.offered,
    'Confirmed': StayEnquiryBucket.confirmed,
    'Closed': StayEnquiryBucket.closed,
  };

  @override
  State<StayEnquiriesTab> createState() => _StayEnquiriesTabState();
}

class _StayEnquiriesTabState extends State<StayEnquiriesTab> with WidgetsBindingObserver {
  final _ctrl = StayEnquiriesController.ensure();
  final _scroll = ScrollController();
  final _flashKey = GlobalKey();
  final _flashTarget = RxnString();
  Timer? _flashTimer;
  final _highlight = RxnString();
  final _expanded = RxnString();
  Worker? _intentWorker;
  Worker? _focusWorker;

  AuthController? get _auth => Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    if (_ctrl.stay.value == null) _ctrl.ensureStay();
    final auth = _auth;
    if (auth != null) {
      _intentWorker = ever<TabIntent?>(auth.tabIntent, (i) {
        if (i != null && i.index == AppTabs.centre && mounted) _apply(auth.takeIntent(AppTabs.centre));
      });
    }
    _focusWorker = ever<String?>(_ctrl.focusId, (id) {
      if (id == null || !mounted) return;
      _ctrl.focusId.value = null;
      _flash(id);
    });
    _apply(auth?.takeIntent(AppTabs.centre));
  }

  @override
  void dispose() {
    _intentWorker?.dispose();
    _focusWorker?.dispose();
    _flashTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ctrl.refreshList();
  }

  Future<void> _apply(TabIntent? intent) async {
    final args = intent?.args ?? const <String, dynamic>{};
    final id = args['enquiryId']?.toString();
    final bucketArg = args['bucket']?.toString();
    var bucket = StayEnquiriesTab.bucketArgs[bucketArg] ?? (StayEnquiryBucket.all.contains(bucketArg) ? bucketArg : null);
    if (bucket == null && id != null && id.isNotEmpty) bucket = await _ctrl.bucketFor(id);
    if (!mounted) return;
    _ctrl.bucket.value = bucket ?? StayEnquiryBucket.newOnes;
    await _ctrl.load();
    if (!mounted || id == null || id.isEmpty) return;
    _expanded.value = id;
    _flash(id);
  }

  void _flash(String id) {
    _flashTarget.value = id;
    _highlight.value = id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(id, 3));
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _highlight.value == id) _highlight.value = null;
    });
  }

  void _reveal(String id, int tries) {
    if (!mounted || _flashTarget.value != id) return;
    final ctx = _flashKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 300));
      return;
    }
    final index = _ctrl.items.indexWhere((e) => e.id == id);
    if (index < 0 || tries <= 0 || !_scroll.hasClients) return;
    final p = _scroll.position;
    final perRow = (p.maxScrollExtent + p.viewportDimension) / _ctrl.items.length;
    _scroll.jumpTo((index * perRow).clamp(0.0, p.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(id, tries - 1));
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _ctrl.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final look = OwnerLook.stay;
    return Material(
      color: look.page,
      child: Obx(() {
        final name = _ctrl.stay.value?.name;
        return TabHeaderFrame(
          title: StayWorkStrings.enquiries,
          subtitle: name == null || name.isEmpty ? TripStrings.tripEnquiry : name,
          color: look.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const NotificationOffBanner(),
              _pills(),
              if (_auth case final auth?) Obx(() => auth.staysEnabled ? const SizedBox.shrink() : RepliesBanner(art: ListingArt.calendar, text: TripStrings.pausedHere)),
              Obx(() => _ctrl.stale.value && _ctrl.items.isNotEmpty ? const OwnerStaleLine() : const SizedBox.shrink()),
              Expanded(child: Obx(_body)),
            ],
          ),
        );
      }),
    );
  }

  Widget _pills() {
    return Obx(() {
      final c = _ctrl.counts.value;
      final selected = _ctrl.bucket.value;
      final looks = <String, (String, String, int)>{
        StayEnquiryBucket.newOnes: (ListingArt.speechBalloon, StayWorkStrings.bucketNew, c.newCount),
        StayEnquiryBucket.offered: (ListingArt.moneyBag, StayWorkStrings.bucketOffered, c.offered),
        StayEnquiryBucket.confirmed: (ListingArt.key, StayWorkStrings.bucketConfirmed, c.confirmed),
        StayEnquiryBucket.closed: (ListingArt.clipboard, StayWorkStrings.bucketClosed, 0),
      };
      Widget pill(String key) {
        final (art, label, count) = looks[key]!;
        final on = selected == key;
        final text = on ? StayWorkStrings.withCount(label, count) : label;
        return BucketPill(art: art, label: text, selected: on, semantics: count > 0 ? '$label, $count' : label, onTap: () => _ctrl.selectBucket(key));
      }

      final keys = StayEnquiryBucket.all;
      return Padding(
        padding: DS.gapInsets(l: 14, t: 8, r: 14, b: 2),
        child: Column(
          children: [
            for (var r = 0; r < keys.length; r += 2) ...[
              if (r > 0) Gap.v(10),
              Row(children: [
                Expanded(child: pill(keys[r])),
                Gap.h(12),
                Expanded(child: pill(keys[r + 1])),
              ]),
            ],
          ],
        ),
      );
    });
  }

  Widget _body() {
    final items = _ctrl.items;
    final loading = _ctrl.loading.value;
    final failed = _ctrl.failed.value;
    final bucket = _ctrl.bucket.value;
    final views = _ctrl.views;
    final flashTarget = _flashTarget.value;
    final bottom = AppInsets.bottomViewPadding(context) + DS.s(16);

    if (loading && items.isEmpty) return const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: OwnerSkeletonList(rows: 3));
    if (items.isEmpty) {
      final Widget empty;
      if (failed && _ctrl.executionDisabled.value) {
        empty = _EmptyBlock(art: ListingArt.clipboard, title: StayWorkStrings.plannerOff, message: StayWorkStrings.plannerOffSub);
      } else if (failed) {
        empty = _EmptyBlock(art: ListingArt.worldMap, title: OwnerSharedStrings.couldNotLoad, action: OwnerSharedStrings.tryAgain, onAction: _ctrl.load);
      } else {
        empty = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _EmptyBlock(art: ListingArt.clipboard, title: StayWorkStrings.noEnquiries, message: StayWorkStrings.noEnquiriesSub),
            if (bucket == StayEnquiryBucket.newOnes && (_auth?.staysEnabled ?? true) && (_ctrl.stay.value?.isApproved ?? false)) const StayQuietWeekBanner(),
          ],
        );
      }
      return RefreshIndicator(
        color: ListingTone.forest.g2,
        onRefresh: _ctrl.refreshList,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), padding: EdgeInsets.only(bottom: bottom), children: [empty]),
      );
    }
    final footer = _ctrl.loadingMore.value || _ctrl.loadMoreFailed.value ? 1 : 0;
    return RefreshIndicator(
      color: ListingTone.forest.g2,
      onRefresh: _ctrl.refreshList,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.only(bottom: bottom),
        itemCount: items.length + footer,
        itemBuilder: (_, i) {
          if (i >= items.length) return _footer();
          final e = items[i];
          final view = views[e.id] ?? _ctrl.viewOf(e.id);
          return KeyedSubtree(
            key: e.id == flashTarget ? _flashKey : ValueKey('row_${e.id}'),
            child: Obx(() => StayOwnerEnquiryCard(
                  key: ValueKey('${bucket}_${e.id}'),
                  enquiry: e,
                  view: view,
                  ctrl: _ctrl,
                  highlighted: _highlight.value == e.id,
                  expanded: _expanded.value == e.id,
                )),
          );
        },
      ),
    );
  }

  Widget _footer() {
    if (_ctrl.loadMoreFailed.value) {
      return Center(
        child: TextButton(onPressed: _ctrl.loadMore, child: Text(OwnerSharedStrings.tryAgain, style: Ink3D.text(13, FontWeight.w700, ListingTone.forest.text))),
      );
    }
    return Padding(padding: EdgeInsets.symmetric(vertical: DS.gv(16)), child: Center(child: KitDots(color: ListingTone.forest.g2)));
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.art, required this.title, this.message, this.action, this.onAction});

  final String art;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: DS.gapInsets(l: 26, t: 30, r: 26, b: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Art3D(asset: art, size: 44)),
          Gap.v(10),
          Text(title, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          if (message != null)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(4)),
              child: Text(message!, textAlign: TextAlign.center, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, height: 1.35, letterSpacing: 0)),
            ),
          if (action != null) ...[
            Gap.v(14),
            GradientPillButton(tone: ListingTone.forest, label: action, expand: false, height: 44, fontSize: _actionFont, onTap: onAction),
          ],
        ],
      ),
    );
  }
}
