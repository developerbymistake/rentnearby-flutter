import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../trip/utils/taxi_result.dart';
import 'controllers/driver_ready_controller.dart';
import 'controllers/driver_requests_controller.dart';
import 'data/driver_request_repository.dart';
import 'models/driver_request_models.dart';
import 'strings/driver_requests_strings.dart';
import 'widgets/driver_offer_card.dart';
import 'widgets/driver_ready_strip.dart';

class DriverRequestsScreen extends StatefulWidget {
  const DriverRequestsScreen({
    super.key,
    this.controller,
    this.onOpenOffer,
    this.onBack,
    this.ready,
    this.onOpenReady,
    this.tick = const Duration(seconds: 1),
  });

  final DriverRequestsController? controller;
  final DriverReadyController? ready;
  final VoidCallback? onOpenReady;
  final void Function(String offerId)? onOpenOffer;
  final VoidCallback? onBack;
  final Duration tick;

  @override
  State<DriverRequestsScreen> createState() => _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends State<DriverRequestsScreen> {
  static const double _maxWidth = 640;
  static const double _buttonFont = 14;
  static const double _buttonHeight = 44;

  late final DriverRequestsController _c = widget.controller ?? DriverRequestsController.to;
  final Set<String> _expiredSeen = {};
  Timer? _timer;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.tick, (_) => _onTick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_c.reloadList());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    var reload = false;
    var counting = false;
    for (final o in _c.items) {
      if (o.state != OfferState.ringing && o.state != OfferState.selected) continue;
      counting = true;
      if (_c.remaining(o) == Duration.zero && _expiredSeen.add('${o.offerId}:${o.state.wire}')) reload = true;
    }
    if (reload) unawaited(_c.reloadList());
    if (counting) setState(() {});
  }

  void _back() => (widget.onBack ?? () => Get.back())();

  bool _enabled(DriverOffer o) =>
      !_c.isBusy(DriverRequestAction.accept, o.offerId) && !_c.isBusy(DriverRequestAction.decline, o.offerId);

  static String? _messageOf(TaxiResult<DriverOffer> r) => switch (r) {
        TaxiOk<DriverOffer>() => null,
        TaxiOfferMissed<DriverOffer>() => DriverRequestsStrings.actionMissed,
        TaxiDatesAlreadyBooked<DriverOffer>() => DriverRequestsStrings.actionDatesBooked,
        TaxiPaused<DriverOffer>() => DriverRequestsStrings.actionPaused,
        TaxiOffline<DriverOffer>() => DriverRequestsStrings.actionOffline,
        _ => DriverRequestsStrings.actionFailed,
      };

  Future<void> _act(Future<TaxiResult<DriverOffer>> Function() call) async {
    if (_notice != null) setState(() => _notice = null);
    final r = await call();
    if (!mounted) return;
    setState(() => _notice = _messageOf(r));
  }

  Future<void> _refresh() async {
    if (_notice != null) setState(() => _notice = null);
    await _c.reloadList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: ModuleHeader(
              title: DriverRequestsStrings.title,
              subtitle: DriverRequestsStrings.subtitle,
              autoHeight: true,
              tone: KitTone.brand,
              gradient: ListingTone.indigo.gradient,
              onBack: _back,
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: DriverReadyStrip(key: const ValueKey('requests_ready_strip'), controller: widget.ready, onOpen: widget.onOpenReady),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxWidth),
                child: RefreshIndicator(
                  color: DesignColors.primary,
                  onRefresh: _refresh,
                  child: Obx(() => ListView(
                        key: const ValueKey('requests_list'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: DS.insets(l: 18, t: 16, r: 18, b: 28),
                        children: _children(),
                      )),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _children() {
    final items = _c.items.toList();
    final loaded = _c.loaded.value;
    final paused = _c.paused.value;
    final listFailed = _c.hasFailed(DriverRequestAction.list);
    final loading = _c.isBusy(DriverRequestAction.list);
    if (items.isEmpty) {
      if (paused) return [_stateView(ListingArt.warning, DriverRequestsStrings.pausedTitle, DriverRequestsStrings.pausedLine, 'requests_paused')];
      if (!loaded && listFailed && !loading) {
        return [
          _stateView(ListingArt.warning, DriverRequestsStrings.errorTitle, DriverRequestsStrings.errorLine, 'requests_error', retry: true),
        ];
      }
      if (!loaded) return [_loadingView()];
      return [
        if (listFailed && !loading) _banner(DriverRequestsStrings.refreshFailed, 'requests_refresh_failed'),
        _stateView(ListingArt.taxi, DriverRequestsStrings.emptyTitle, DriverRequestsStrings.emptyLine, 'requests_empty'),
      ];
    }
    final fresh = [for (final o in items) if (o.bucket == OfferBucket.newOffers) o];
    final booked = [for (final o in items) if (o.bucket == OfferBucket.booked) o];
    final earlier = [for (final o in items) if (o.bucket != OfferBucket.newOffers && o.bucket != OfferBucket.booked) o];
    final notice = _notice;
    return [
      if (paused) _banner(DriverRequestsStrings.pausedBanner, 'requests_paused_banner'),
      if (!paused && listFailed && !loading) _banner(DriverRequestsStrings.refreshFailed, 'requests_refresh_failed'),
      if (notice != null) _banner(notice, 'requests_notice'),
      ..._group(DriverRequestsStrings.groupNew, 'requests_group_new', fresh),
      ..._group(DriverRequestsStrings.groupBooked, 'requests_group_booked', booked),
      ..._group(DriverRequestsStrings.groupEarlier, 'requests_group_earlier', earlier),
      if (_c.hasMore) ...[
        Gap.v(4),
        WhitePillButton(
          key: const ValueKey('requests_more'),
          tone: ListingTone.indigo,
          label: _c.isBusy(DriverRequestAction.more) ? DriverRequestsStrings.loadingMore : DriverRequestsStrings.showMore,
          onTap: _c.isBusy(DriverRequestAction.more) ? null : () => unawaited(_c.loadMore()),
          height: _buttonHeight,
          fontSize: _buttonFont,
        ),
      ],
    ];
  }

  List<Widget> _group(String title, String key, List<DriverOffer> offers) {
    if (offers.isEmpty) return const [];
    return [
      Padding(
        padding: EdgeInsets.only(top: DS.gv(8), bottom: DS.gv(10)),
        child: Text(title, key: ValueKey(key), style: Ink3D.text(20, FontWeight.w700, Ink3D.title)),
      ),
      for (final o in offers)
        Padding(
          padding: EdgeInsets.only(bottom: DS.gv(14)),
          child: DriverOfferCard(
            offer: o,
            timeLeft: o.state == OfferState.ringing || o.state == OfferState.selected
                ? DriverRequestsStrings.timeLeft(_c.countdownText(o))
                : null,
            expired: o.state == OfferState.ringing && _c.remaining(o) == Duration.zero,
            enabled: _enabled(o),
            onOpen: widget.onOpenOffer == null ? null : () => widget.onOpenOffer!(o.offerId),
            onAccept: () => _act(() => _c.accept(o.offerId)),
            onDecline: () => _act(() => _c.decline(o.offerId)),
          ),
        ),
    ];
  }

  Widget _banner(String text, String key) => Padding(
        padding: EdgeInsets.only(bottom: DS.gv(12)),
        child: Container(
          key: ValueKey(key),
          padding: DS.sym(h: 14, v: 10),
          decoration: BoxDecoration(color: DesignColors.surfaceTint, borderRadius: DS.circular(12)),
          child: Text(text, style: Ink3D.text(13, FontWeight.w600, DesignColors.primary)),
        ),
      );

  Widget _loadingView() => Padding(
        key: const ValueKey('requests_loading'),
        padding: DS.sym(v: 48),
        child: Column(
          children: [
            const CircularProgressIndicator(color: DesignColors.primary),
            Gap.v(14),
            Text(DriverRequestsStrings.loading, style: Ink3D.text(14, FontWeight.w400, Ink3D.copy)),
          ],
        ),
      );

  Widget _stateView(String art, String title, String line, String key, {bool retry = false}) => Padding(
        key: ValueKey(key),
        padding: DS.sym(v: 32),
        child: Column(
          children: [
            Art3D(asset: art, size: 84, shadowBlur: 6, shadowOffset: const Offset(3, 5)),
            Gap.v(12),
            Text(title, textAlign: TextAlign.center, style: Ink3D.text(20, FontWeight.w700, Ink3D.title)),
            Gap.v(6),
            Text(line, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, Ink3D.copy)),
            if (retry) ...[
              Gap.v(16),
              WhitePillButton(
                key: const ValueKey('requests_retry'),
                tone: ListingTone.indigo,
                label: DriverRequestsStrings.tryAgain,
                onTap: () => unawaited(_c.reloadList()),
                height: _buttonHeight,
                fontSize: _buttonFont,
              ),
            ],
          ],
        ),
      );
}
