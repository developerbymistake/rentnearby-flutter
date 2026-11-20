import 'dart:async';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
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
import '../widgets/taxi_request/taxi_request_look.dart';
import '../widgets/taxi_request/taxi_seat_chips.dart';
import '../widgets/taxi_request/taxi_section_card.dart';
import '../widgets/trip_plan_header.dart';

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
      case TaxiNoReadyDriver<TaxiRequest>():
        AppToast.error(TripStringsTaxiRequest.noReadyDriver);
      case TaxiAllDriversBusy<TaxiRequest>():
        AppToast.error(TripStringsTaxiRequest.allDriversBusy);
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
      backgroundColor: DesignColors.scaffold,
      body: Column(
        children: [
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: TripFlowHeader(
              title: TripStringsTaxiRequest.title,
              subtitle: TripStringsTaxiRequest.subtitle,
              onBack: widget.onBack ?? () => Get.back(),
              trailing: [_menu()],
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

  Widget _menu() => PopupMenuButton<int>(
        key: const ValueKey('taxi_request_menu'),
        tooltip: TripStringsTaxiRequest.moreOptions,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: DS.circular(12)),
        color: DesignColors.surface,
        onSelected: (_) => (widget.onTryAnotherCity ?? () => Get.back())(),
        itemBuilder: (_) => [
          PopupMenuItem<int>(
            value: 0,
            child: Text(TripStringsTaxiRequest.tryAnotherCity, style: Ink3D.text(13, FontWeight.w600, Ink3D.title)),
          ),
        ],
        child: TripMenuDots.box(),
      );

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
          padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(14), DS.s(18), DS.gv(20)),
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
              Padding(
                padding: DS.sym(h: 4),
                child: Text(TripStringsTaxiRequest.intro, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub, height: 1.5, letterSpacing: 0)),
              ),
              Gap.v(24),
              _pickupCard(form, places),
              Gap.v(24),
              _sightseeingCard(form),
              Gap.v(24),
              _dropCard(form, places),
              Gap.v(24),
              TaxiSectionCard(
                art: JourneyArt.automobile,
                tone: TaxiSectionTones.car,
      title: TripStringsTaxiRequest.carTitle,
                sub: TripStringsTaxiRequest.setFromTravellers(places.travellers),
                child: TaxiSeatChips(seats: form.seats, enabledFor: form.seatEnabled, onChanged: (s) => _edit((f) => f.setSeats(s))),
              ),
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
      tone: TaxiSectionTones.pickup,
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
      tone: TaxiSectionTones.sightseeing,
      title: TripStringsTaxiRequest.sightseeingTitle,
      sub: TripStringsTaxiRequest.sightseeingSub,
      on: form.sightseeingOn,
      switchKey: const ValueKey('taxi_sightseeing_switch'),
      onChanged: (v) => _edit((f) => f.setSightseeingOn(v)),
      child: TaxiDayRows(rows: widget.rows, selected: form.days, onToggle: (d) => _edit((f) => f.toggleDay(d))),
    );
  }

  Widget _dropCard(TaxiRequestForm form, TaxiPickupPlaces places) {
    final same = form.dropIsSameAsPickup;
    final chosen = form.dropSame ? null : form.dropCityKey;
    return TaxiSectionCard(
      number: 3,
      art: TravelIcon.flag,
      tone: TaxiSectionTones.drop,
      title: TripStringsTaxiRequest.dropTitle,
      sub: form.dropPast ? TripStringsTaxiRequest.dropPassed : TripStringsTaxiRequest.dropSub,
      on: form.dropOn,
      switchKey: const ValueKey('taxi_drop_switch'),
      switchEnabled: !form.dropPast,
      onChanged: (v) {
        if (!v) _dropPicking = false;
        _edit((f) => f.setDropOn(v));
      },
      child: TaxiPlaceDropdown(
        key: ValueKey(same ? 'taxi_drop_same_mode' : 'taxi_drop_pick_mode'),
        keyPrefix: 'taxi_drop',
        hint: TripStringsTaxiRequest.chooseDropLabel,
        places: places.drop,
        selectedKey: same ? null : chosen,
        field: same ? _SameAsPickup(onChange: () => setState(() => _dropPicking = !_dropPicking)) : null,
        open: same ? _dropPicking : null,
        sameOption: !same && form.pickupOn && chosen != null,
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
        color: DesignColors.surface,
        borderRadius: DS.br(TripCustomizeLook.barRadius),
        boxShadow: DS.shadows(Ink3D.topEdge),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(12), DS.s(16), DS.s(16) + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: DS.sym(h: 4),
              child: Text(
                form.summary,
                key: const ValueKey('taxi_request_summary'),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Ink3D.text(12.5, FontWeight.w600, Ink3D.sub, height: 1.4, letterSpacing: 0),
              ),
            ),
            SizedBox(height: DS.s(10)),
            GradientPillButton(
              key: const ValueKey('taxi_request_send'),
              tone: tone,
              label: TripStringsTaxiRequest.send,
              shadows: TripLook.pillShadow,
              offColor: TripLook.disabledFill,
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
      constraints: TaxiPlaceDropdown.fieldConstraints(),
      alignment: Alignment.centerLeft,
      padding: DS.sym(h: 18),
      decoration: TaxiPlaceDropdown.fieldDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Text(TripStringsTaxiRequest.sameAsPickup, maxLines: 2, overflow: TextOverflow.ellipsis, style: TaxiPlaceDropdown.valueStyle()),
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
                style: Ink3D.text(13, FontWeight.w700, tone.g2, letterSpacing: 0).copyWith(decoration: TextDecoration.underline, decorationColor: tone.g2),
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
    return Column(
      key: const ValueKey('taxi_pickup_empty'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(TravelIcon.warning, width: DS.s(56), height: DS.s(56), fit: BoxFit.contain),
        Gap.v(8),
        Text(TripStringsTaxiRequest.noDriversTitle, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
        Gap.v(4),
        Text(
          TripStringsTaxiRequest.pickupNotAvailableFor(city),
          textAlign: TextAlign.center,
          style: Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0),
        ),
        Gap.v(14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: DS.gh(12),
          runSpacing: DS.gv(12),
          children: [
            _pill(const ValueKey('taxi_pickup_skip'), TripStringsTaxiRequest.skipTaxi, onSkip),
            _pill(const ValueKey('taxi_pickup_try_another'), TripStringsTaxiRequest.tryAnotherCity, onTryAnother),
          ],
        ),
      ],
    );
  }

  Widget _pill(Key key, String label, VoidCallback onTap) {
    return Tap3D(
      key: key,
      onTap: onTap,
      label: label,
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(40)),
        padding: DS.sym(h: 18),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(20), boxShadow: DS.shadows(TaxiRequestLook.whitePill)),
        child: Center(widthFactor: 1, child: Text(label, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, ListingTone.indigo.text, letterSpacing: 0))),
      ),
    );
  }
}
