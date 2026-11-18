import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/contact_launcher.dart';
import '../../trip/trip_strings_taxi_driver.dart';
import '../../trip/utils/taxi_result.dart';
import '../../trip/widgets/taxi_status/taxi_driver_card.dart';
import '../../trip/widgets/taxi_status/taxi_status_states.dart';
import 'controllers/driver_requests_controller.dart';
import 'data/driver_request_repository.dart';
import 'driver_bookings_screen.dart';
import 'models/driver_request_models.dart';
import 'strings/driver_request_detail_strings.dart';
import 'widgets/driver_request_body.dart';

typedef _S = DriverRequestDetailStrings;

class DriverRequestDetailScreen extends StatefulWidget {
  const DriverRequestDetailScreen({
    super.key,
    required this.offerId,
    this.controller,
    this.onBack,
    this.onCall,
    this.onOpenBookings,
  });

  final String offerId;
  final DriverRequestsController? controller;
  final VoidCallback? onBack;
  final Future<void> Function(String phone)? onCall;
  final VoidCallback? onOpenBookings;

  @override
  State<DriverRequestDetailScreen> createState() => _DriverRequestDetailScreenState();
}

class _DriverRequestDetailScreenState extends State<DriverRequestDetailScreen> {
  static const double _maxWidth = 640;

  late final DriverRequestsController _c = widget.controller ?? DriverRequestsController.to;
  Timer? _ticker;
  String? _error;
  bool _reloadedAtZero = false;

  String get _id => widget.offerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _c.loadOffer(_id);
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    final o = _c.offer(_id);
    if (!mounted || o == null || _c.deadlineOf(o) == null) return;
    if (_c.remaining(o) == Duration.zero) {
      if (!_reloadedAtZero) {
        _reloadedAtZero = true;
        _c.loadOffer(_id);
      }
    } else {
      _reloadedAtZero = false;
    }
    setState(() {});
  }

  void _back() => (widget.onBack ?? () => Get.back())();

  static String _messageOf(TaxiResult<DriverOffer> r) {
    final server = switch (r) {
      TaxiStateInvalid(:final message) ||
      TaxiNotFound(:final message) ||
      TaxiRefused(:final message) ||
      TaxiPaused(:final message) =>
        message,
      _ => null,
    };
    if (server != null && server.trim().isNotEmpty) return server.trim();
    return r is TaxiOffline ? _S.actionOffline : _S.actionFailed;
  }

  Future<TaxiResult<DriverOffer>> _act(Future<TaxiResult<DriverOffer>> Function() action) async {
    if (_error != null) setState(() => _error = null);
    final r = await action();
    if (!mounted) return r;
    setState(() => _error = r is TaxiOk<DriverOffer> || r is TaxiDatesAlreadyBooked<DriverOffer> ? null : _messageOf(r));
    return r;
  }

  Future<void> _decline() async {
    final r = await _act(() => _c.decline(_id));
    if (r is TaxiOk<DriverOffer> && mounted) _back();
  }

  void _call(String phone) => (widget.onCall ?? ContactLauncher.call)(phone);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Obx(() {
        final o = _c.offer(_id);
        final content = o == null ? _loading() : _content(o);
        return Column(
          children: [
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: ModuleHeader(
                title: o == null ? _S.titleRinging : _titleOf(o),
                subtitle: o != null && o.pickupName.isNotEmpty ? TripStringsTaxiDriver.pickupCity(o.pickupName) : null,
                autoHeight: true,
                tone: KitTone.brand,
                gradient: ListingTone.indigo.gradient,
                onBack: _back,
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: SingleChildScrollView(
                    padding: DS.sym(h: 18, v: 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content.content),
                  ),
                ),
              ),
            ),
            if (content.bar.isNotEmpty) TaxiBottomBar(children: content.bar),
          ],
        );
      }),
    );
  }

  static String _titleOf(DriverOffer o) => switch (o.state) {
        OfferState.ringing => _S.titleRinging,
        OfferState.accepted => _S.titleAccepted,
        OfferState.selected => _S.titleSelected,
        OfferState.confirmed => _S.titleBooked,
        _ => _S.titleEnded,
      };

  ({List<Widget> content, List<Widget> bar}) _loading() {
    final failed = _c.hasFailed(DriverRequestAction.detail, _id) && !_c.isBusy(DriverRequestAction.detail, _id);
    if (failed) {
      return (
        content: [
          const TaxiStatusHero(art: ListingArt.warning, title: _S.loadFailed, titleSize: 20),
          Gap.v(16),
          WhitePillButton(key: const ValueKey('request_retry'), tone: ListingTone.indigo, label: _S.tryAgain, onTap: () => _c.loadOffer(_id)),
        ],
        bar: const [],
      );
    }
    return (
      content: [
        const TaxiStatusHero(art: ListingArt.taxi, title: _S.loading, titleSize: 20),
        Gap.v(16),
        const Center(child: CircularProgressIndicator(color: DesignColors.primary)),
      ],
      bar: const [],
    );
  }

  ({List<Widget> content, List<Widget> bar}) _content(DriverOffer o) {
    final state = o.state;
    final conflict = _c.conflictFor(_id);
    final live = state == OfferState.ringing || state == OfferState.accepted || state == OfferState.selected;
    final showConflict = conflict != null && (state == OfferState.selected || state == OfferState.accepted);
    final detailBusy = _c.isBusy(DriverRequestAction.detail, _id);
    return (
      content: [
        _Hero(offer: o, line: _heroLine(o), chip: live ? null : _chipOf(o)),
        if (state == OfferState.confirmed) ...[
          Gap.v(10),
          Center(
            child: Tap3D(
              tapKey: const ValueKey('request_open_bookings'),
              onTap: widget.onOpenBookings ?? () => Get.to(() => const DriverBookingsScreen()),
              child: Text(_S.openBookings,
                  style: Ink3D.text(14, FontWeight.w700, DesignColors.primary).copyWith(decoration: TextDecoration.underline)),
            ),
          ),
        ],
        if (showConflict) ...[Gap.v(14), _ConflictBanner(from: conflict.from, to: conflict.to)],
        if (_error != null) ...[
          Gap.v(14),
          Text(_error!, key: const ValueKey('request_error'), textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w700, Form3D.errorText)),
        ],
        Gap.v(16),
        DriverRequestBody(offer: o),
        if (o.trip == null && detailBusy) ...[
          Gap.v(16),
          const Center(child: CircularProgressIndicator(color: DesignColors.primary)),
        ],
      ],
      bar: _bar(o, hasConflict: conflict != null),
    );
  }

  String? _heroLine(DriverOffer o) => switch (o.state) {
        OfferState.ringing => o.trip?.name,
        OfferState.accepted => _S.waitingForTraveller,
        OfferState.selected => _S.selectedCountdown(_c.countdownText(o)),
        _ => null,
      };

  ({String label, bool muted, String? note}) _chipOf(DriverOffer o) => switch (o.state) {
        OfferState.confirmed => (label: TripStringsTaxiDriver.stateBooked, muted: false, note: null),
        OfferState.missed => (label: TripStringsTaxiDriver.stateMissed, muted: true, note: TripStringsTaxiDriver.missedNote),
        OfferState.notSelected => (label: TripStringsTaxiDriver.stateNotSelected, muted: true, note: TripStringsTaxiDriver.notSelectedNote),
        _ => (label: TripStringsTaxiDriver.stateClosed, muted: true, note: null),
      };

  List<Widget> _bar(DriverOffer o, {required bool hasConflict}) {
    final decline = WhitePillButton(
      key: const ValueKey('request_decline'),
      tone: ListingTone.indigo,
      label: TripStringsTaxiDriver.decline,
      enabled: !_c.isBusy(DriverRequestAction.decline, _id),
      onTap: _decline,
    );
    switch (o.state) {
      case OfferState.ringing:
        return [
          decline,
          GradientPillButton(
            key: const ValueKey('request_accept'),
            tone: ListingTone.forest,
            label: TripStringsTaxiDriver.accept,
            loading: _c.isBusy(DriverRequestAction.accept, _id),
            onTap: () => _act(() => _c.accept(_id)),
          ),
        ];
      case OfferState.accepted:
        final phone = o.traveller?.phone;
        if (phone == null) return const [];
        return [
          GradientPillButton(
            key: const ValueKey('request_call'),
            tone: ListingTone.forest,
            label: TripStringsTaxiDriver.callTraveller,
            onTap: () => _call(phone),
          ),
        ];
      case OfferState.selected:
        return [
          decline,
          GradientPillButton(
            key: const ValueKey('request_confirm'),
            tone: ListingTone.forest,
            label: TripStringsTaxiDriver.confirmBooking,
            enabled: !hasConflict,
            loading: _c.isBusy(DriverRequestAction.confirm, _id),
            onTap: () => _act(() => _c.confirm(_id)),
          ),
        ];
      default:
        return const [];
    }
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.offer, required this.line, required this.chip});

  final DriverOffer offer;
  final String? line;
  final ({String label, bool muted, String? note})? chip;

  static bool _numberVisible(OfferState s) => s == OfferState.accepted || s == OfferState.selected || s == OfferState.confirmed;

  @override
  Widget build(BuildContext context) {
    final visible = _numberVisible(offer.state);
    final t = visible ? offer.traveller : null;
    final name = t != null && t.name.isNotEmpty ? t.name : TripStringsTaxiDriver.traveller;
    final phone = t?.phone;
    final c = chip;
    return Column(
      children: [
        const Art3D(asset: ListingArt.profile, size: 84, shadowBlur: 6, shadowOffset: Offset(3, 5)),
        Gap.v(10),
        Text(name,
            key: const ValueKey('request_traveller_name'),
            textAlign: TextAlign.center,
            style: Ink3D.text(22, FontWeight.w700, Ink3D.title)),
        if (phone != null && phone.isNotEmpty) ...[
          Gap.v(4),
          Text(phone, key: const ValueKey('request_traveller_phone'), textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, Ink3D.copy)),
        ],
        if (line != null && line!.isNotEmpty) ...[
          Gap.v(6),
          Text(
            line!,
            key: const ValueKey('request_hero_line'),
            textAlign: TextAlign.center,
            style: offer.state == OfferState.ringing
                ? Ink3D.text(14, FontWeight.w400, Ink3D.copy)
                : Ink3D.text(13, FontWeight.w700, DesignColors.primary),
          ),
        ],
        if (c != null) ...[
          Gap.v(8),
          TaxiStateChip(label: c.label, muted: c.muted, positive: !c.muted),
          if (c.note != null) ...[
            Gap.v(6),
            Text(c.note!, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, Ink3D.copy)),
          ],
        ],
      ],
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final a = DateTime.tryParse(from);
    final b = DateTime.tryParse(to);
    final text = _S.datesBooked(a == null ? from : _S.shortDate(a), b == null ? to : _S.shortDate(b));
    return Container(
      key: const ValueKey('request_conflict_banner'),
      padding: DS.insets(l: 14, t: 12, r: 14, b: 12),
      decoration: BoxDecoration(
        color: DesignColors.warning.withValues(alpha: Alpha.v16),
        borderRadius: DS.br(CardRadius.tile),
      ),
      child: Row(
        children: [
          const Art3D(asset: ListingArt.warning, size: 36, shadowBlur: 3, shadowOffset: Offset(1, 2)),
          Gap.h(12),
          Expanded(child: Text(text, style: Ink3D.text(13, FontWeight.w700, DesignColors.gold))),
        ],
      ),
    );
  }
}
