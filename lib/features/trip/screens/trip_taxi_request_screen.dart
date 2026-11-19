import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/trip_taxi_request_controller.dart';
import '../models/taxi_request_models.dart';
import '../trip_strings_taxi_request.dart';
import '../utils/taxi_request_form.dart';
import '../utils/taxi_result.dart';
import '../utils/taxi_request_errors.dart';
import '../widgets/taxi_request/taxi_day_rows.dart';
import '../widgets/taxi_request/taxi_place_dropdown.dart';
import '../widgets/taxi_request/taxi_seat_chips.dart';
import '../widgets/taxi_request/taxi_section_card.dart';

class TripTaxiRequestScreen extends StatefulWidget {
  const TripTaxiRequestScreen({
    super.key,
    required this.controller,
    required this.tripId,
    required this.rows,
    required this.onSent,
    this.dayStats = const [],
    this.onTryAnotherCity,
    this.onBack,
  });

  final TripTaxiRequestController controller;
  final String tripId;
  final List<TaxiRequestDayRow> rows;
  final List<TaxiDayStat> dayStats;
  final void Function(TaxiRequest request) onSent;
  final VoidCallback? onTryAnotherCity;
  final VoidCallback? onBack;

  static const double _maxWidth = 640;
  static const double _buttonFont = 14;

  @override
  State<TripTaxiRequestScreen> createState() => _TripTaxiRequestScreenState();
}

class _TripTaxiRequestScreenState extends State<TripTaxiRequestScreen> {
  bool _dropPicking = false;

  TripTaxiRequestController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    await _c.loadPlaces(
      widget.tripId,
      planDays: [for (final r in widget.rows) r.day],
      dayStats: widget.dayStats,
      pastDays: TaxiDayRows.pastOf(widget.rows),
    );
  }

  void _edit(TaxiRequestForm Function(TaxiRequestForm f) change) => _c.editForm(change);

  Future<void> _send() => _handle(_c.send());

  Future<void> _handle(Future<TaxiResult<TaxiRequest>> pending) async {
    final r = await pending;
    if (!mounted) return;
    switch (r) {
      case TaxiOk<TaxiRequest>(:final value):
        widget.onSent(value);
      case TaxiAlreadyActive<TaxiRequest>():
        final existing = _c.request.value;
        if (existing != null) {
          widget.onSent(existing);
        } else {
          AppToast.error(r.message ?? TripStringsTaxiRequest.sendFailed);
        }
      case TaxiLegacyActive<TaxiRequest>():
        await _askCancelLegacy();
      case TaxiRefused<TaxiRequest>(:final type) when type == 'PickupNotAvailable' || type == 'DropNotAvailable':
        AppToast.error(r.message ?? (type == 'PickupNotAvailable' ? TripStringsTaxiRequest.pickupGone : TripStringsTaxiRequest.dropGone));
        _dropPicking = false;
        await _load();
      case TaxiPaused<TaxiRequest>():
        break;
      case TaxiOffline<TaxiRequest>():
        AppToast.error(TripStringsTaxiRequest.offline);
      case TaxiPlanLocked<TaxiRequest>(:final message):
        AppToast.error(message ?? TripStringsTaxiRequest.sendFailed);
      case TaxiOverlap<TaxiRequest>(:final tripName):
        AppToast.error(TaxiRequestErrors.overlapMessage(tripName));
      case TaxiRefused<TaxiRequest>(:final type) when TaxiRequestErrors.isSeatsError(type):
        AppToast.error(TaxiRequestErrors.seatsMessage(type));
        await _load();
      case TaxiRefused<TaxiRequest>(:final type) when TaxiRequestErrors.isDayInPast(type):
        AppToast.error(TaxiRequestErrors.dayInPastMessage(type));
        await _load();
      case TaxiRefused<TaxiRequest>(:final message):
        AppToast.error(message ?? TripStringsTaxiRequest.sendFailed);
      case TaxiFailed<TaxiRequest>(:final message):
        AppToast.error(message.isEmpty ? TripStringsTaxiRequest.sendFailed : message);
      default:
        AppToast.error(TripStringsTaxiRequest.sendFailed);
    }
  }

  Future<void> _askCancelLegacy() async {
    final cancelOld = await Dialog3D.show<bool>(
      context,
      builder: (ctx) => Dialog3D(
        tone: ListingTone.indigo,
        art: TravelIcon.taxi,
        title: TripStringsTaxiRequest.legacyTitle,
        body: TripStringsTaxiRequest.legacyBody,
        tight: true,
        secondaryKey: const ValueKey('taxi_legacy_keep'),
        secondaryLabel: TripStringsTaxiRequest.legacyKeep,
        secondaryNeutral: true,
        onSecondary: () => Navigator.pop(ctx, false),
        primaryKey: const ValueKey('taxi_legacy_cancel'),
        primaryLabel: TripStringsTaxiRequest.legacyCancel,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    if (cancelOld != true || !mounted) return;
    await _handle(_c.cancelLegacyTaxi());
  }

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    return Scaffold(
      backgroundColor: DesignColors.surface,
      body: Column(
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: ModuleHeader(
              title: TripStringsTaxiRequest.title,
              subtitle: TripStringsTaxiRequest.subtitle,
              autoHeight: true,
              tone: KitTone.brand,
              gradient: tone.gradient,
              onBack: widget.onBack ?? () => Get.back(),
            ),
          ),
          Expanded(
            child: Obx(() {
              final form = _c.form.value;
              final places = _c.places.value;
              if (form == null || places == null) return _loading(tone);
              return Column(
                children: [
                  Expanded(child: _body(form, places)),
                  _bottom(form, tone),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _loading(ListingTone tone) {
    if (_c.isBusy(TaxiAction.places)) {
      return Center(child: CircularProgressIndicator(color: tone.g2));
    }
    return Center(
      child: Padding(
        padding: DS.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(TripStringsTaxiRequest.loadFailed, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w600, Ink3D.sub)),
            Gap.v(14),
            WhitePillButton(
              key: const ValueKey('taxi_request_retry'),
              tone: tone,
              label: TripStringsTaxiRequest.retry,
              onTap: () => unawaited(_load()),
              expand: false,
              height: 44,
              fontSize: TripTaxiRequestScreen._buttonFont,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(TaxiRequestForm form, TaxiPickupPlaces places) {
    final tone = ListingTone.indigo;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TripTaxiRequestScreen._maxWidth),
        child: SingleChildScrollView(
          padding: DS.sym(h: 16, v: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_c.paused.value) ...[
                Container(
                  key: const ValueKey('taxi_request_paused'),
                  padding: DS.sym(h: 14, v: 10),
                  decoration: BoxDecoration(color: tone.tint, borderRadius: DS.circular(14)),
                  child: Text(TripStringsTaxiRequest.paused, style: Ink3D.text(13, FontWeight.w700, tone.text)),
                ),
                Gap.v(10),
              ],
              Text(TripStringsTaxiRequest.intro, style: Ink3D.text(13, FontWeight.w400, Ink3D.sub)),
              Gap.v(12),
              _pickupCard(form, places),
              Gap.v(16),
              _sightseeingCard(form),
              Gap.v(16),
              _dropCard(form, places),
              Gap.v(16),
              TaxiSectionCard(
                art: TravelIcon.taxi,
                title: TripStringsTaxiRequest.carTitle,
                sub: TripStringsTaxiRequest.setFromTravellers(places.travellers),
                child: TaxiSeatChips(seats: form.seats, enabledFor: form.seatEnabled, onChanged: (s) => _edit((f) => f.setSeats(s))),
              ),
              Gap.v(8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pickupCard(TaxiRequestForm form, TaxiPickupPlaces places) {
    return TaxiSectionCard(
      number: 1,
      art: TravelIcon.place,
      title: TripStringsTaxiRequest.pickupTitle,
      sub: form.pickupPast ? TripStringsTaxiRequest.pickupPassed : TripStringsTaxiRequest.pickupSub,
      on: form.pickupOn,
      switchKey: const ValueKey('taxi_pickup_switch'),
      switchEnabled: !form.pickupPast,
      onChanged: (v) => _edit((f) => f.setPickupOn(v)),
      child: TaxiPlaceDropdown(
        keyPrefix: 'taxi_pickup',
        hint: TripStringsTaxiRequest.choosePickupLabel,
        places: places.pickup,
        selectedKey: form.pickupCityKey,
        onPick: (p) => _edit((f) => f.choosePickup(p.cityKey)),
        empty: _EmptyPickup(
          city: places.firstCity.name,
          onSkip: () => _edit((f) => f.setPickupOn(false)),
          onTryAnother: widget.onTryAnotherCity ?? () => Get.back(),
        ),
      ),
    );
  }

  Widget _sightseeingCard(TaxiRequestForm form) {
    return TaxiSectionCard(
      number: 2,
      art: TravelIcon.photo,
      title: TripStringsTaxiRequest.sightseeingTitle,
      sub: TripStringsTaxiRequest.sightseeingSub,
      on: form.sightseeingOn,
      switchKey: const ValueKey('taxi_sightseeing_switch'),
      onChanged: (v) => _edit((f) => f.setSightseeingOn(v)),
      child: TaxiDayRows(rows: widget.rows, selected: form.days, onToggle: (d) => _edit((f) => f.toggleDay(d))),
    );
  }

  Widget _dropCard(TaxiRequestForm form, TaxiPickupPlaces places) {
    final same = form.dropIsSameAsPickup && !_dropPicking;
    return TaxiSectionCard(
      number: 3,
      art: TravelIcon.flag,
      title: TripStringsTaxiRequest.dropTitle,
      sub: form.dropPast ? TripStringsTaxiRequest.dropPassed : TripStringsTaxiRequest.dropSub,
      on: form.dropOn,
      switchKey: const ValueKey('taxi_drop_switch'),
      switchEnabled: !form.dropPast,
      onChanged: (v) {
        if (!v) _dropPicking = false;
        _edit((f) => f.setDropOn(v));
      },
      child: same
          ? _SameAsPickup(onChange: () => setState(() => _dropPicking = true))
          : TaxiPlaceDropdown(
              keyPrefix: 'taxi_drop',
              hint: TripStringsTaxiRequest.chooseDropLabel,
              places: places.drop,
              selectedKey: form.dropSame ? null : form.dropCityKey,
              sameOption: form.pickupOn,
              onSame: () {
                setState(() => _dropPicking = false);
                _edit((f) => f.dropSameAsPickup());
              },
              onPick: (p) {
                setState(() => _dropPicking = false);
                _edit((f) => f.chooseDrop(p.cityKey));
              },
              empty: Text(TripStringsTaxiRequest.noDropTitle, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, Ink3D.sub)),
            ),
    );
  }

  Widget _bottom(TaxiRequestForm form, ListingTone tone) {
    final sending = _c.isBusy(TaxiAction.send) || _c.isBusy(TaxiAction.cancelLegacy);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(16))),
        boxShadow: DS.shadows(Ink3D.topEdge),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(12), DS.s(18), DS.s(16) + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              form.summary,
              key: const ValueKey('taxi_request_summary'),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Ink3D.text(13, FontWeight.w600, Ink3D.sub),
            ),
            Gap.v(10),
            GradientPillButton(
              key: const ValueKey('taxi_request_send'),
              tone: tone,
              label: TripStringsTaxiRequest.send,
              enabled: form.canSend && !_c.paused.value,
              loading: sending,
              onTap: () => unawaited(_send()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SameAsPickup extends StatelessWidget {
  const _SameAsPickup({required this.onChange});

  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    return Container(
      key: const ValueKey('taxi_drop_same'),
      padding: DS.sym(h: 18, v: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(28), boxShadow: DS.shadows(Ink3D.softShadow)),
      child: Row(
        children: [
          Expanded(
            child: Text(TripStringsTaxiRequest.sameAsPickup, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.title)),
          ),
          Gap.h(8),
          Tap3D(
            onTap: onChange,
            label: TripStringsTaxiRequest.change,
            child: Padding(
              padding: DS.sym(h: 4, v: 4),
              child: Text(
                TripStringsTaxiRequest.change,
                key: const ValueKey('taxi_drop_change'),
                style: Ink3D.text(14, FontWeight.w700, tone.text).copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPickup extends StatelessWidget {
  const _EmptyPickup({required this.city, required this.onSkip, required this.onTryAnother});

  final String city;
  final VoidCallback onSkip;
  final VoidCallback onTryAnother;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    return Column(
      key: const ValueKey('taxi_pickup_empty'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Art3D(asset: TravelIcon.warning, size: 48, shadowBlur: 4, shadowOffset: const Offset(2, 3)),
        Gap.v(10),
        Text(TripStringsTaxiRequest.noDriversTitle, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w700, Ink3D.title)),
        Gap.v(4),
        Text(TripStringsTaxiRequest.pickupNotAvailableFor(city), textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, Ink3D.sub)),
        Gap.v(14),
        PillButtonRow(
          children: [
            WhitePillButton(
              key: const ValueKey('taxi_pickup_skip'),
              tone: tone,
              label: TripStringsTaxiRequest.skipTaxi,
              onTap: onSkip,
              height: 44,
              fontSize: TripTaxiRequestScreen._buttonFont,
            ),
            WhitePillButton(
              key: const ValueKey('taxi_pickup_try_another'),
              tone: tone,
              label: TripStringsTaxiRequest.tryAnotherCity,
              onTap: onTryAnother,
              height: 44,
              fontSize: TripTaxiRequestScreen._buttonFont,
            ),
          ],
        ),
      ],
    );
  }
}
