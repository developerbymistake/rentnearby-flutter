import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/contact_launcher.dart';
import '../controllers/trip_taxi_request_controller.dart';
import '../models/taxi_request_models.dart';
import '../trip_strings_taxi_status.dart';
import '../utils/taxi_result.dart';
import '../widgets/taxi_status/taxi_cancel_sheet.dart';
import '../widgets/taxi_status/taxi_driver_card.dart';
import '../widgets/taxi_status/taxi_rating_card.dart';
import '../widgets/taxi_status/taxi_status_states.dart';
import '../widgets/taxi_status/taxi_status_steps.dart';

typedef TaxiOpenRequest = void Function({required bool keepChoices});

class TripTaxiRequestStatusScreen extends StatefulWidget {
  const TripTaxiRequestStatusScreen({
    super.key,
    required this.requestId,
    this.controller,
    this.onDone,
    this.onOpenRequest,
    this.onCall,
    this.onBack,
  });

  final String requestId;
  final TripTaxiRequestController? controller;
  final VoidCallback? onDone;
  final TaxiOpenRequest? onOpenRequest;
  final Future<void> Function(String phone)? onCall;
  final VoidCallback? onBack;

  @override
  State<TripTaxiRequestStatusScreen> createState() => _TripTaxiRequestStatusScreenState();
}

class _TripTaxiRequestStatusScreenState extends State<TripTaxiRequestStatusScreen> {
  static const double _maxWidth = 640;
  static const Set<TaxiAction> _actions = {
    TaxiAction.cancel,
    TaxiAction.changePickup,
    TaxiAction.askMore,
    TaxiAction.select,
    TaxiAction.notAgreed,
    TaxiAction.endTrip,
    TaxiAction.rate,
  };

  late final TripTaxiRequestController _c = widget.controller ?? TripTaxiRequestController.to;
  final Set<String> _called = {};
  int _stars = 0;
  ({int version, String message})? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.attach(widget.requestId);
    });
  }

  @override
  void dispose() {
    _c.detach();
    super.dispose();
  }

  void _done() => (widget.onDone ?? () => Get.back())();

  void _openRequest(bool keepChoices) {
    final open = widget.onOpenRequest;
    if (open != null) {
      open(keepChoices: keepChoices);
    } else {
      Get.back();
    }
  }

  void _call(TaxiDriverCard d) {
    final phone = d.phone;
    if (phone == null) return;
    setState(() => _called.add(d.offerId));
    (widget.onCall ?? ContactLauncher.call)(phone);
  }

  static String _messageOf(TaxiResult<TaxiRequest> r) {
    final server = switch (r) {
      TaxiStateInvalid(:final message) ||
      TaxiAllDriversBusy(:final message) ||
      TaxiNotFound(:final message) ||
      TaxiRefused(:final message) ||
      TaxiPlanLocked(:final message) ||
      TaxiPaused(:final message) =>
        message,
      _ => null,
    };
    if (r is TaxiRefused<TaxiRequest> && r.rateLimited) return TripStringsTaxiStatus.tooFast;
    if (server != null && server.trim().isNotEmpty) return server.trim();
    return r is TaxiOffline ? TripStringsTaxiStatus.actionOffline : TripStringsTaxiStatus.actionFailed;
  }

  Future<TaxiResult<TaxiRequest>> _act(Future<TaxiResult<TaxiRequest>> Function() action) async {
    final version = _c.request.value?.version ?? -1;
    if (_error != null) setState(() => _error = null);
    final r = await action();
    if (!mounted) return r;
    setState(() => _error = r is TaxiOk<TaxiRequest> ? null : (version: version, message: _messageOf(r)));
    return r;
  }

  Future<void> _cancel(TaxiRequest r) async {
    final choice = await TaxiCancelSheet.show(context, withBooking: r.activeBooking != null);
    if (choice == null || !mounted) return;
    await _act(() => _c.cancel(chip: choice.chip));
  }

  Future<void> _changePickup() async {
    final r = await _act(_c.changePickup);
    if (r is TaxiOk<TaxiRequest> && mounted) _openRequest(false);
  }

  bool get _anyBusy => _actions.any(_c.isBusy);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Obx(() {
        final cur = _c.request.value;
        final r = cur != null && cur.id == widget.requestId ? cur : null;
        final body = r == null ? _loading() : _content(r);
        return Column(
          children: [
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: ModuleHeader(
                title: TripStringsTaxiStatus.title,
                subtitle: r != null && r.tripName.isNotEmpty ? r.tripName : null,
                autoHeight: true,
                tone: KitTone.brand,
                gradient: ListingTone.indigo.gradient,
                onBack: widget.onBack ?? () => Get.back(),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: SingleChildScrollView(
                    padding: DS.sym(h: 18, v: 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body.content),
                  ),
                ),
              ),
            ),
            if (body.bar.isNotEmpty) TaxiBottomBar(children: body.bar),
          ],
        );
      }),
    );
  }

  _Body _loading() {
    if (_c.hasFailed(TaxiAction.load) && !_c.isBusy(TaxiAction.load)) {
      return _Body([
        const TaxiStatusHero(art: ListingArt.warning, title: TripStringsTaxiStatus.loadFailed, titleSize: 20),
        Gap.v(16),
        WhitePillButton(
          key: const ValueKey('status_retry'),
          tone: ListingTone.indigo,
          label: TripStringsTaxiStatus.tryAgain,
          onTap: _c.refreshRequest,
        ),
      ], [_doneButton()]);
    }
    return _Body([
      const TaxiStatusHero(art: ListingArt.taxi, title: TripStringsTaxiStatus.loading, titleSize: 20),
      Gap.v(16),
      const Center(child: CircularProgressIndicator(color: DesignColors.primary)),
    ], [_doneButton()]);
  }

  Widget _doneButton() => GradientPillButton(
        key: const ValueKey('status_done'),
        tone: ListingTone.indigo,
        label: TripStringsTaxiStatus.done,
        onTap: _done,
      );

  Widget _hero(TaxiRequest r) => TaxiStatusHero(
        art: ListingArt.taxi,
        title: TripStringsTaxiStatus.taxiRequest,
        line: TripStringsTaxiStatus.requestLine(r),
      );

  Widget _failedLine(TaxiRequest r) {
    final e = _error;
    if (e == null || e.version != r.version) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(12)),
      child: Text(
        e.message,
        key: const ValueKey('status_failed_line'),
        textAlign: TextAlign.center,
        style: Ink3D.text(13, FontWeight.w600, Form3D.errorText),
      ),
    );
  }

  Widget _lapseLine(TaxiRequest r) {
    final l = _c.lapse.value;
    if (l == null || l.requestId != r.id) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(14)),
      child: Text(
        l.unavailable ? TripStringsTaxiStatus.driverUnavailable : TripStringsTaxiStatus.driverDidNotConfirm,
        key: const ValueKey('status_lapse_line'),
        textAlign: TextAlign.center,
        style: Ink3D.text(14, FontWeight.w700, Form3D.errorText),
      ),
    );
  }

  Widget _cancelLink(TaxiRequest r) {
    if (!r.canCancel || r.activeBooking != null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(8)),
      child: Tap3D(
        tapKey: const ValueKey('cancel_request'),
        onTap: _anyBusy ? null : () => _cancel(r),
        child: Padding(
          padding: DS.sym(v: 10),
          child: Center(
            child: Text(
              TripStringsTaxiStatus.cancelRequest,
              style: Ink3D.text(13, FontWeight.w700, Ink3D.grey).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ),
      ),
    );
  }

  _Body _content(TaxiRequest r) {
    switch (r.view) {
      case RequestView.finding:
        return _finding(r, TripStringsTaxiStatus.asked(r.askedCount, r.pickup?.name ?? ''));
      case RequestView.findingWaiting:
        return _finding(r, TripStringsTaxiStatus.waitingSub);
      case RequestView.noReply:
        return _finding(r, TripStringsTaxiStatus.noReplySub, noReply: true);
      case RequestView.collecting:
      case RequestView.selected:
        return _choosing(r);
      case RequestView.booked:
      case RequestView.inProgress:
        return _booked(r);
      case RequestView.rate:
        return _rate(r);
      case RequestView.done:
        return _thanks(r);
      case RequestView.busy:
        return _busy();
      case RequestView.ended:
        final b = r.booking;
        if (b != null && b.canRate) return _rate(r);
        if (b != null && b.leftDuringTrip && r.rating != null) return _thanks(r);
        return _ended();
      case RequestView.unknown:
        return _neutral();
    }
  }

  _Body _finding(TaxiRequest r, String sub, {bool noReply = false}) {
    final stalled = r.canAskMore && !r.stillAsking;
    return _Body([
        _hero(r),
        Gap.v(18),
        TaxiStatusSteps(stage: TaxiStepStage.finding, findingSub: stalled ? TripStringsTaxiStatus.noDriverAgreed : sub),
        _lapseLine(r),
        Gap.v(10),
        Text(
          TripStringsTaxiStatus.numberNote,
          key: const ValueKey('status_number_note'),
          textAlign: TextAlign.center,
          style: Ink3D.text(12, FontWeight.w400, Ink3D.copy),
        ),
        if (noReply) ...[
          Gap.v(14),
          WhitePillButton(
            key: const ValueKey('status_change_pickup'),
            tone: ListingTone.indigo,
            label: TripStringsTaxiStatus.changePickup,
            onTap: _anyBusy ? null : _changePickup,
          ),
        ],
        if (r.canAskMore) _askMoreButton(),
        _cancelLink(r),
        _failedLine(r),
      ], [_doneButton()]);
  }

  Widget _askMoreButton() => Padding(
        padding: EdgeInsets.only(top: DS.gv(12)),
        child: WhitePillButton(
          key: const ValueKey('status_ask_more'),
          tone: ListingTone.indigo,
          label: TripStringsTaxiStatus.askMore,
          onTap: _anyBusy ? null : () => _act(_c.askMore),
        ),
      );

  _Body _choosing(TaxiRequest r) {
    final chosen = r.selectedDriver;
    final shown = [
      for (final d in r.drivers)
        if (d.state == OfferState.accepted || d.state == OfferState.selected || d.state == OfferState.confirmed) d,
    ]..sort((a, b) => (b.state == OfferState.selected ? 1 : 0).compareTo(a.state == OfferState.selected ? 1 : 0));
    return _Body([
      _hero(r),
      Gap.v(18),
      TaxiStatusSteps(stage: TaxiStepStage.choosing, findingSub: TripStringsTaxiStatus.asked(r.askedCount, r.pickup?.name ?? '')),
      if (chosen == null) _lapseLine(r),
      if (chosen != null) ...[
        Gap.v(14),
        Text(
          TripStringsTaxiStatus.waitingFor(chosen.name),
          key: const ValueKey('status_waiting_for'),
          style: Ink3D.text(14, FontWeight.w700, DesignColors.primary),
        ),
      ],
      for (final d in shown) ...[
        Gap.v(14),
        TaxiDriverCardView(
          driver: d,
          mode: d.state == OfferState.selected || d.state == OfferState.confirmed
              ? TaxiDriverMode.selected
              : (chosen != null ? TaxiDriverMode.onHold : TaxiDriverMode.choose),
          showSelect: d.canSelect && chosen == null,
          calling: _called.contains(d.offerId),
          enabled: !_anyBusy,
          onCall: d.phone == null ? null : () => _call(d),
          onSelect: () => _act(() => _c.select(d.offerId)),
          onNotAgreed: () => _act(() => _c.notAgreed(d.offerId)),
        ),
      ],
      if (r.stillAsking) ...[
        Gap.v(14),
        Row(
          key: const ValueKey('status_still_asking'),
          children: [
            Container(width: DS.s(10), height: DS.s(10), decoration: const BoxDecoration(shape: BoxShape.circle, color: DesignColors.statusOffer)),
            Gap.h(12),
            Expanded(child: Text(TripStringsTaxiStatus.stillAsking, style: Ink3D.text(14, FontWeight.w400, Ink3D.copy))),
          ],
        ),
      ],
      if (r.canAskMore) _askMoreButton(),
      _cancelLink(r),
      _failedLine(r),
    ], [_doneButton()]);
  }

  _Body _booked(TaxiRequest r) {
    final d = r.selectedDriver;
    return _Body([
      _hero(r),
      Gap.v(18),
      TaxiBookedCard(
        request: r,
        driver: d,
        enabled: !_anyBusy,
        onCall: d?.phone == null ? null : () => _call(d!),
        onCancel: () => _cancel(r),
        onEnd: () => _act(_c.endTrip),
      ),
      _failedLine(r),
    ], [_doneButton()]);
  }

  _Body _rate(TaxiRequest r) => _Body([
        _hero(r),
        Gap.v(18),
        TaxiRatingCard(driver: r.selectedDriver, stars: _stars, onStar: (s) => setState(() => _stars = s)),
        _failedLine(r),
      ], [
        GradientPillButton(
          key: const ValueKey('rate_submit'),
          tone: ListingTone.indigo,
          label: TripStringsTaxiStatus.submit,
          enabled: _stars > 0 && !_anyBusy,
          onTap: () => _act(() => _c.rate(_stars)),
        ),
      ]);

  _Body _thanks(TaxiRequest r) => _Body([
        TaxiStatusHero(art: ListingArt.star, title: TripStringsTaxiStatus.thankYou, line: r.selectedDriver?.name),
        Gap.v(14),
        Center(child: TaxiStars(filled: r.rating?.stars ?? 0, size: 32)),
      ], [_doneButton()]);

  _Body _busy() => _Body([
        const TaxiStatusHero(
          art: ListingArt.warning,
          title: TripStringsTaxiStatus.busyTitle,
          line: TripStringsTaxiStatus.busySub,
          titleSize: 22,
        ),
      ], [
        WhitePillButton(
          key: const ValueKey('busy_change_pickup'),
          tone: ListingTone.indigo,
          label: TripStringsTaxiStatus.changePickup,
          onTap: () => _openRequest(false),
        ),
        GradientPillButton(
          key: const ValueKey('busy_try_again'),
          tone: ListingTone.indigo,
          label: TripStringsTaxiStatus.tryAgain,
          onTap: () => _openRequest(true),
        ),
      ]);

  _Body _ended() => _Body([
        const TaxiStatusHero(
          art: ListingArt.warning,
          title: TripStringsTaxiStatus.endedTitle,
          line: TripStringsTaxiStatus.endedSub,
          titleSize: 22,
        ),
      ], [
        WhitePillButton(key: const ValueKey('status_done'), tone: ListingTone.indigo, label: TripStringsTaxiStatus.done, onTap: _done),
        GradientPillButton(
          key: const ValueKey('ended_request_again'),
          tone: ListingTone.indigo,
          label: TripStringsTaxiStatus.requestAgain,
          onTap: () => _openRequest(false),
        ),
      ]);

  _Body _neutral() => _Body([
        const KeyedSubtree(
          key: ValueKey('status_neutral_card'),
          child: TaxiStatusHero(
            art: ListingArt.taxi,
            title: TripStringsTaxiStatus.neutralTitle,
            line: TripStringsTaxiStatus.neutralSub,
            titleSize: 20,
          ),
        ),
      ], [_doneButton()]);
}

class _Body {
  const _Body(this.content, this.bar);

  final List<Widget> content;
  final List<Widget> bar;
}
