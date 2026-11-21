import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../owner_core/plan/gate_keys.dart';
import '../../../owner_core/plan/plan_gate.dart';
import '../../../owner_core/plan/plan_keys.dart';
import '../../../owner_core/plan/soft_lock.dart';
import '../../../taxi_driver/strings/taxi_gate_strings_work.dart';
import '../../../taxi_driver/strings/taxi_work_strings.dart';
import '../../../trip/utils/taxi_result.dart';
import '../controllers/driver_ready_controller.dart';
import '../controllers/driver_requests_controller.dart';
import '../data/driver_request_repository.dart';
import '../models/driver_request_models.dart';
import 'driver_offer_card.dart';
import 'driver_ready_strip.dart';

const double _pillFont = 14;

/// Groups of the requests list, prepared outside build.
class DriverOfferGroups {
  const DriverOfferGroups(this.fresh, this.booked, this.earlier);

  final List<DriverOffer> fresh;
  final List<DriverOffer> booked;
  final List<DriverOffer> earlier;

  static DriverOfferGroups of(List<DriverOffer> items) {
    final fresh = <DriverOffer>[];
    final booked = <DriverOffer>[];
    final earlier = <DriverOffer>[];
    for (final o in items) {
      switch (o.bucket) {
        case OfferBucket.newOffers:
          fresh.add(o);
        case OfferBucket.booked:
          booked.add(o);
        default:
          earlier.add(o);
      }
    }
    return DriverOfferGroups(fresh, booked, earlier);
  }
}

/// G3: Free with payment ON, only after a non-empty Earlier group.
abstract final class DriverTurnBanner {
  static bool shows({required int earlierCount}) =>
      earlierCount > 0 && PlanGate.canUpgrade && PlanGate.limit(PlanKey.ringWeight) < 2;
}

sealed class _Row {
  const _Row();
}

class _Header extends _Row {
  const _Header(this.title, this.count, this.key);
  final String title;
  final int? count;
  final String key;
}

class _Card extends _Row {
  const _Card(this.offer);
  final DriverOffer offer;
}

class _Note extends _Row {
  const _Note(this.text, this.key);
  final String text;
  final String key;
}

class _Turn extends _Row {
  const _Turn();
}

class _More extends _Row {
  const _More();
}

class DriverRequestsBody extends StatefulWidget {
  const DriverRequestsBody({
    super.key,
    this.controller,
    this.ready,
    this.onOpenReady,
    this.onOpenOffer,
    this.onBadge,
    this.bottomPadding = 28,
    this.tick = const Duration(seconds: 1),
  });

  final DriverRequestsController? controller;
  final DriverReadyController? ready;
  final VoidCallback? onOpenReady;
  final void Function(String offerId)? onOpenOffer;
  final void Function(int newCount)? onBadge;
  final double bottomPadding;
  final Duration tick;

  @override
  State<DriverRequestsBody> createState() => _DriverRequestsBodyState();
}

class _DriverRequestsBodyState extends State<DriverRequestsBody> with AutomaticKeepAliveClientMixin {
  static const double _maxWidth = 640;

  late final DriverRequestsController _c = widget.controller ?? DriverRequestsController.to;
  final Set<String> _expiredSeen = {};
  Timer? _timer;
  Worker? _countWorker;
  String? _notice;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.tick, (_) => _onTick());
    final onBadge = widget.onBadge;
    if (onBadge != null) _countWorker = ever<DriverOfferCounts?>(_c.counts, (c) => onBadge(c?.newCount ?? 0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_c.reloadList());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countWorker?.dispose();
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

  bool _enabled(DriverOffer o) =>
      !_c.isBusy(DriverRequestAction.accept, o.offerId) && !_c.isBusy(DriverRequestAction.decline, o.offerId);

  static String? _messageOf(TaxiResult<DriverOffer> r) => switch (r) {
        TaxiOk<DriverOffer>() => null,
        TaxiOfferMissed<DriverOffer>() => TaxiWorkStrings.wentToNext,
        TaxiDatesAlreadyBooked<DriverOffer>() => TaxiWorkStrings.datesTaken,
        TaxiPaused<DriverOffer>() => TaxiWorkStrings.pausedNow,
        TaxiOffline<DriverOffer>() => TaxiWorkStrings.noConnection,
        TaxiRefused<DriverOffer>(:final statusCode) when statusCode == 429 => TaxiWorkStrings.tooManyTries,
        _ => TaxiWorkStrings.didNotWork,
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

  void _open(String id) {
    final cb = widget.onOpenOffer;
    if (cb != null) cb(id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
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
                color: ListingPalette.coral.g2,
                onRefresh: _refresh,
                child: Obx(_list),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _list() {
    final rows = _rows();
    return ListView.builder(
      key: const ValueKey('requests_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: DS.insets(l: 18, r: 18, b: widget.bottomPadding),
      itemCount: rows.length,
      itemBuilder: (_, i) => _build(rows[i]),
    );
  }

  List<Object> _rows() {
    final items = _c.items.toList();
    final loaded = _c.loaded.value;
    final paused = _c.paused.value;
    final listFailed = _c.hasFailed(DriverRequestAction.list);
    final loading = _c.isBusy(DriverRequestAction.list);
    if (items.isEmpty) {
      if (paused) return const [_StateKind.paused];
      if (!loaded && listFailed && !loading) return const [_StateKind.error];
      if (!loaded) return const [_StateKind.skeleton];
      return [
        if (listFailed && !loading) const _Note(TaxiWorkStrings.showingLast, 'requests_refresh_failed'),
        _StateKind.empty,
      ];
    }
    final g = DriverOfferGroups.of(items);
    final notice = _notice;
    final out = <Object>[
      if (paused) const _Note(TaxiWorkStrings.pausedNow, 'requests_paused_banner'),
      if (!paused && listFailed && !loading) const _Note(TaxiWorkStrings.showingLast, 'requests_refresh_failed'),
      if (notice != null) _Note(notice, 'requests_notice'),
    ];
    if (g.fresh.isNotEmpty) {
      out.add(_Header(TaxiWorkStrings.groupNew, g.fresh.length, 'requests_group_new'));
      out.addAll(g.fresh.map(_Card.new));
    }
    if (g.booked.isNotEmpty) {
      out.add(const _Header(TaxiWorkStrings.groupBooked, null, 'requests_group_booked'));
      out.addAll(g.booked.map(_Card.new));
    }
    if (g.earlier.isNotEmpty) {
      out.add(const _Header(TaxiWorkStrings.groupEarlier, null, 'requests_group_earlier'));
      out.addAll(g.earlier.map(_Card.new));
    }
    if (DriverTurnBanner.shows(earlierCount: g.earlier.length)) out.add(const _Turn());
    if (_c.hasMore) out.add(const _More());
    return out;
  }

  Widget _build(Object row) {
    return switch (row) {
      _StateKind.skeleton => const _Skeleton(),
      _StateKind.error => _StateView(
          key: const ValueKey('requests_error'),
          art: ListingArt.warning,
          title: TaxiWorkStrings.couldNotLoad,
          line: TaxiWorkStrings.checkConnection,
          action: TaxiWorkStrings.tryAgain,
          onAction: () => unawaited(_c.reloadList()),
        ),
      _StateKind.paused => const _StateView(
          key: ValueKey('requests_paused'),
          art: ListingArt.alarmClock,
          title: TaxiWorkStrings.pausedTitle,
          line: TaxiWorkStrings.pausedLine,
        ),
      _StateKind.empty => const _StateView(
          key: ValueKey('requests_empty'),
          art: ListingArt.taxi,
          title: TaxiWorkStrings.noRequests,
          line: TaxiWorkStrings.noRequestsLine,
        ),
      _Header(:final title, :final count, :final key) => Padding(
          padding: EdgeInsets.only(top: DS.gv(20)),
          child: Row(
            key: ValueKey(key),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(title, style: Ink3D.text(17, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
              if (count != null) ...[
                Gap.h(6),
                Text('$count', style: Ink3D.text(12, FontWeight.w500, Ink3D.hint, letterSpacing: 0)),
              ],
            ],
          ),
        ),
      _Card(:final offer) => Padding(
          padding: EdgeInsets.only(top: DS.gv(14)),
          child: DriverOfferCard(
            offer: offer,
            timeLeft: offer.state == OfferState.ringing || offer.state == OfferState.selected
                ? TaxiWorkStrings.timeLeft(_c.countdownText(offer))
                : null,
            expired: offer.state == OfferState.ringing && _c.remaining(offer) == Duration.zero,
            enabled: _enabled(offer),
            onOpen: widget.onOpenOffer == null ? null : () => _open(offer.offerId),
            onAccept: () => _act(() => _c.accept(offer.offerId)),
            onDecline: () => _act(() => _c.decline(offer.offerId)),
          ),
        ),
      _Note(:final text, :final key) => Padding(
          padding: EdgeInsets.only(top: DS.gv(14)),
          child: Container(
            key: ValueKey(key),
            padding: DS.sym(h: 14, v: 10),
            decoration: BoxDecoration(color: ListingPalette.coral.tint, borderRadius: DS.circular(12)),
            child: Text(text, style: Ink3D.text(13, FontWeight.w600, ListingPalette.coral.text)),
          ),
        ),
      _Turn() => const DriverTurnBannerCard(),
      _More() => Padding(
          padding: EdgeInsets.only(top: DS.gv(16)),
          child: WhitePillButton(
            key: const ValueKey('requests_more'),
            tone: ListingTone.coral,
            label: TaxiWorkStrings.showMore,
            onTap: _c.isBusy(DriverRequestAction.more) ? null : () => unawaited(_c.loadMore()),
            height: 44,
            fontSize: _pillFont,
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

enum _StateKind { skeleton, error, paused, empty }

class DriverTurnBannerCard extends StatelessWidget {
  const DriverTurnBannerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: GateKeys.of('G3'),
      padding: EdgeInsets.only(top: DS.gv(18)),
      child: Container(
        padding: DS.insets(l: 14, t: 10, r: 12, b: 10),
        decoration: BoxDecoration(color: ListingPalette.coral.tint, borderRadius: DS.circular(14)),
        child: Row(
          children: [
            const Art3D(asset: ListingArt.crown, size: 34, shadowAlpha: 0),
            Gap.h(12),
            Expanded(
              child: Text(TaxiGateStringsWork.turnTwice, style: Ink3D.text(12, FontWeight.w600, ListingPalette.coral.text, height: 1.4, letterSpacing: 0)),
            ),
            Gap.h(8),
            const SeePlusButton(taxi: true),
          ],
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Column(
        key: const ValueKey('requests_loading'),
        children: [
          for (var i = 0; i < 2; i++)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(18)),
              child: SkeletonBox(height: DS.s(150), radius: DS.radius(20)),
            ),
        ],
      );
}

class _StateView extends StatelessWidget {
  const _StateView({super.key, required this.art, required this.title, required this.line, this.action, this.onAction});

  final String art;
  final String title;
  final String line;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final a = action;
    return Padding(
      padding: DS.sym(v: 32),
      child: Column(
        children: [
          Art3D(asset: art, size: 84, shadowBlur: 6, shadowOffset: const Offset(3, 5)),
          Gap.v(12),
          Text(title, textAlign: TextAlign.center, style: Ink3D.text(20, FontWeight.w700, Ink3D.title)),
          Gap.v(6),
          Text(line, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, Ink3D.copy)),
          if (a != null) ...[
            Gap.v(16),
            WhitePillButton(key: const ValueKey('requests_retry'), tone: ListingTone.coral, label: a, onTap: onAction, height: 44, fontSize: _pillFont),
          ],
        ],
      ),
    );
  }
}
