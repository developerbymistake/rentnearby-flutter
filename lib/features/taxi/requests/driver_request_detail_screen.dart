import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/taxi_status_look.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../taxi_driver/strings/taxi_work_strings.dart';
import '../../taxi_driver/taxi_driver_deps.dart';
import '../../trip/trip_strings_taxi_driver.dart';
import '../../trip/utils/taxi_result.dart';
import 'widgets/driver_state_chip.dart';
import '../../trip/widgets/taxi_status/taxi_status_states.dart';
import 'controllers/driver_requests_controller.dart';
import 'data/driver_request_repository.dart';
import 'driver_bookings_screen.dart';
import 'models/driver_request_models.dart';
import 'strings/driver_request_detail_strings.dart';
import 'utils/indian_phone.dart';
import 'widgets/driver_request_body.dart';
import 'widgets/driver_withdraw_sheet.dart';

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
    switch (r) {
      case TaxiConfirmWindowPassed<DriverOffer>():
        return TaxiWorkStrings.timeToConfirmOver;
      case TaxiOfferMissed<DriverOffer>():
        return TaxiWorkStrings.wentToNext;
      case TaxiPaused<DriverOffer>():
        return TaxiWorkStrings.pausedNow;
      case TaxiOffline<DriverOffer>():
        return TaxiWorkStrings.noConnection;
      case TaxiRefused<DriverOffer>(:final statusCode) when statusCode == 429:
        return TaxiWorkStrings.tooManyTries;
      default:
    }
    final server = switch (r) {
      TaxiStateInvalid(:final message) || TaxiNotFound(:final message) || TaxiRefused(:final message) => message,
      _ => null,
    };
    if (server != null && server.trim().isNotEmpty) return server.trim();
    return TaxiWorkStrings.didNotWork;
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

  Future<void> _withdraw(DriverOffer o) async {
    if (_c.isBusy(DriverRequestAction.withdraw, _id)) return;
    final booked = o.state == OfferState.confirmed;
    final name = (o.traveller?.name ?? '').trim().split(' ').first;
    final chip = await DriverWithdrawSheet.show(
      context,
      kind: booked ? DriverWithdrawKind.booking : DriverWithdrawKind.request,
      travellerName: name,
      range: TaxiWorkStrings.shortRange(o.fromDay, o.toDay),
    );
    if (chip == null || !mounted) return;
    final r = await _act(() => _c.withdraw(_id, chip));
    if (booked && r is TaxiOk<DriverOffer> && mounted) AppToast.success(TaxiWorkStrings.withdrewBooking);
  }

  void _openBookings() => (widget.onOpenBookings ?? () => Get.to(() => const DriverBookingsScreen()))();

  void _call(String phone) => (widget.onCall ?? ContactLauncher.call)(phone);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
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
                titleStyle: TripCustomizeLook.headerTitle,
                subtitleWidget: o != null && o.pickupName.isNotEmpty
                    ? Text(TripStringsTaxiDriver.pickupCity(o.pickupName), maxLines: 1, overflow: TextOverflow.ellipsis, style: TripCustomizeLook.headerSubtitle)
                    : null,
                autoHeight: true,
                compact: true,
                tone: KitTone.taxiDriver,
                gradient: ListingTone.coral.gradient,
                onBack: _back,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
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
        OfferState.ringing => TaxiWorkStrings.titleRinging,
        OfferState.accepted => TaxiWorkStrings.titleAccepted,
        OfferState.selected => TaxiWorkStrings.titleSelected,
        OfferState.confirmed => TaxiWorkStrings.titleBooked,
        _ => TaxiWorkStrings.titleEnded,
      };

  List<DateTime> _manualDays(DriverOffer o) {
    if (o.manualTripOn.isNotEmpty) return o.manualTripDays;
    final from = o.fromDay;
    final to = o.toDay;
    if (from == null || to == null) return const [];
    try {
      return TaxiDriverDeps.manualTripDays(from, to);
    } catch (_) {
      return const [];
    }
  }

  ({List<Widget> content, List<Widget> bar}) _loading() {
    final failed = _c.hasFailed(DriverRequestAction.detail, _id) && !_c.isBusy(DriverRequestAction.detail, _id);
    if (failed) {
      return (
        content: [
          const TaxiStatusHero(art: ListingArt.warning, title: TaxiWorkStrings.loadThisFailed, titleSize: 20),
          Gap.v(16),
          WhitePillButton(key: const ValueKey('request_retry'), tone: ListingTone.coral, label: TaxiWorkStrings.tryAgain, onTap: () => _c.loadOffer(_id)),
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
        _Hero(offer: o, line: showConflict ? null : _heroLine(o), chip: live ? null : _chipOf(o)),
        if (showConflict) ...[Gap.v(20), _ConflictBanner(from: conflict.from, to: conflict.to)],
        if (state == OfferState.accepted || state == OfferState.selected) ..._manualLine(o),
        if (_error != null) ...[
          Gap.v(14),
          Text(_error!, key: const ValueKey('request_error'), textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w700, Form3D.errorText)),
        ],
        Gap.v(20),
        DriverRequestBody(offer: o, compact: showConflict),
        if (o.trip == null && detailBusy) ...[
          Gap.v(16),
          const Center(child: CircularProgressIndicator(color: DesignColors.primary)),
        ],
      ],
      bar: _bar(o, hasConflict: conflict != null),
    );
  }

  List<Widget> _manualLine(DriverOffer o) {
    final days = _manualDays(o);
    if (days.isEmpty) return const [];
    return [Gap.v(16), _AmberLine(key: const ValueKey('request_manual_trip'), text: TaxiWorkStrings.manualTrips(days))];
  }

  String? _heroLine(DriverOffer o) => switch (o.state) {
        OfferState.ringing => o.trip?.name,
        OfferState.accepted => TaxiWorkStrings.waitingNote,
        OfferState.selected =>
          _c.remaining(o) == Duration.zero ? TaxiWorkStrings.timeToConfirmOver : TaxiWorkStrings.selectedCountdown(_c.countdownText(o)),
        _ => null,
      };

  ({String label, bool muted, String? note}) _chipOf(DriverOffer o) => switch (o.state) {
        OfferState.confirmed => (label: TaxiWorkStrings.bookedChip(TaxiWorkStrings.shortRange(o.fromDay, o.toDay)), muted: false, note: null),
        OfferState.missed => (label: TripStringsTaxiDriver.stateMissed, muted: true, note: TripStringsTaxiDriver.missedNote),
        OfferState.notSelected => (label: TripStringsTaxiDriver.stateNotSelected, muted: true, note: TripStringsTaxiDriver.notSelectedNote),
        OfferState.withdrawn => (label: _S.youWithdrew, muted: true, note: null),
        _ => (label: TripStringsTaxiDriver.stateClosed, muted: true, note: null),
      };

  List<Widget> _bar(DriverOffer o, {required bool hasConflict}) {
    final decline = WhitePillButton(
      key: const ValueKey('request_decline'),
      tone: ListingTone.coral,
      label: TaxiWorkStrings.decline,
      enabled: !_c.isBusy(DriverRequestAction.decline, _id),
      onTap: _decline,
    );
    final phone = o.traveller?.phone;
    final call = phone == null || phone.trim().isEmpty
        ? null
        : GradientPillButton(
            key: const ValueKey('request_call'),
            tone: ListingTone.coral,
            label: TaxiWorkStrings.callTraveller,
            shadows: TaxiStatusLook.redPill,
            onTap: () => _call(phone),
          );
    final withdraw = WhitePillButton(
      key: const ValueKey('request_withdraw'),
      tone: ListingTone.coral,
      label: TaxiWorkStrings.withdraw,
      enabled: !_c.isBusy(DriverRequestAction.withdraw, _id),
      onTap: () => _withdraw(o),
    );
    switch (o.state) {
      case OfferState.ringing:
        return [
          decline,
          GradientPillButton(
            key: const ValueKey('request_accept'),
            tone: ListingTone.coral,
            label: TaxiWorkStrings.accept,
            shadows: TaxiStatusLook.redPill,
            loading: _c.isBusy(DriverRequestAction.accept, _id),
            onTap: () => _act(() => _c.accept(_id)),
          ),
        ];
      case OfferState.accepted:
        return [?call, withdraw];
      case OfferState.selected:
        final over = _c.remaining(o) == Duration.zero;
        return [
          decline,
          GradientPillButton(
            key: const ValueKey('request_confirm'),
            tone: ListingTone.coral,
            label: TaxiWorkStrings.confirmBooking,
            shadows: TaxiStatusLook.redPill,
            offColor: TripLook.disabledFill,
            enabled: !hasConflict && !over,
            loading: _c.isBusy(DriverRequestAction.confirm, _id),
            onTap: () => _act(() => _c.confirm(_id)),
          ),
        ];
      case OfferState.confirmed:
        return [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                if (call != null) ...[Expanded(child: call), Gap.h(12)],
                Expanded(child: withdraw),
              ]),
              Gap.v(10),
              WhitePillButton(
                key: const ValueKey('request_open_bookings'),
                tone: ListingTone.coral,
                label: TaxiWorkStrings.myBookings,
                onTap: _openBookings,
              ),
            ],
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
    final ringing = offer.state == OfferState.ringing;
    final small = Ink3D.text(13, FontWeight.w400, TripLook.mutedText, height: 1.5, letterSpacing: 0);
    return Padding(
      padding: DS.insets(l: 6, t: ringing ? 0 : 10, r: 6),
      child: Column(
        children: [
          const Art3D(asset: TaxiStatusLook.person, size: 100, shadowBlur: 7, shadowOffset: Offset(6, 9)),
          Gap.v(10),
          Text(name,
              key: const ValueKey('request_traveller_name'),
              textAlign: TextAlign.center,
              style: Ink3D.text(24, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          if (phone != null && phone.isNotEmpty) ...[
            Gap.v(4),
            Text(IndianPhone.display(phone), key: const ValueKey('request_traveller_phone'), textAlign: TextAlign.center, style: small),
          ],
          if (line != null && line!.isNotEmpty)
            if (ringing) ...[
              Gap.v(4),
              Text(line!, key: const ValueKey('request_hero_line'), textAlign: TextAlign.center, style: small),
            ] else ...[
              Gap.v(10),
              DriverStateChip(key: const ValueKey('request_hero_line'), label: line!),
            ],
          if (c != null) ...[
            Gap.v(10),
            DriverStateChip(label: c.label, muted: c.muted, positive: !c.muted),
            if (c.note != null) ...[
              Gap.v(6),
              Text(c.note!, textAlign: TextAlign.center, style: small),
            ],
          ],
        ],
      ),
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
    final text = TaxiWorkStrings.datesBooked(a == null ? from : _S.shortDate(a), b == null ? to : _S.shortDate(b));
    return Stack(
      key: const ValueKey('request_conflict_banner'),
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: BoxConstraints(minHeight: DS.s(64)),
          padding: DS.insets(l: 80, t: 14, r: 16, b: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: TaxiStatusLook.warnFill, borderRadius: DS.br(TaxiStatusLook.bannerRadius)),
          child: Text(text, style: Ink3D.text(13, FontWeight.w600, TaxiStatusLook.warnText, height: 1.45, letterSpacing: 0)),
        ),
        Positioned(left: DS.s(14), top: DS.s(-8), child: const Art3D(asset: ListingArt.warning, size: 52, shadowAlpha: 0)),
      ],
    );
  }
}

class _AmberLine extends StatelessWidget {
  const _AmberLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 14, v: 10),
        decoration: BoxDecoration(color: TaxiStatusLook.warnFill, borderRadius: DS.circular(12)),
        child: Row(
          children: [
            const Art3D(asset: ListingArt.calendar, size: 26, shadowAlpha: 0),
            Gap.h(10),
            Expanded(child: Text(text, style: Ink3D.text(12.5, FontWeight.w600, TaxiStatusLook.warnText, height: 1.45, letterSpacing: 0))),
          ],
        ),
      );
}
