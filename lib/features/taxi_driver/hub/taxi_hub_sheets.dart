import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/money_format.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_sheet.dart';
import '../../taxi/models/taxi_owner_model.dart';
import '../../taxi/setup/taxi_route_city_sheet.dart';
import '../../trip/models/trip_city_model.dart';
import '../strings/taxi_hub_strings.dart';
import '../widgets/taxi_widgets.dart';
import 'taxi_hub_controller.dart';

abstract final class TaxiRules {
  static const int minFare = 100;
  static const int maxFare = 9900000;
  static const int minKm = 1;
  static const int maxKm = 1000;

  static int? parse(String text) => int.tryParse(text.replaceAll(',', '').trim());

  static bool fareOk(int? v) => v != null && v >= minFare && v <= maxFare;

  static bool kmOk(int? v) => v != null && v >= minKm && v <= maxKm;

  static String? fareError(String text) {
    if (text.trim().isEmpty) return TaxiHubStrings.fareEmpty;
    return fareOk(parse(text)) ? null : TaxiHubStrings.fareRange;
  }
}

class _GroupFormatter extends TextInputFormatter {
  const _GroupFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final n = int.tryParse(newValue.text);
    if (n == null) return newValue;
    final g = Money.group(n);
    return TextEditingValue(text: g, selection: TextSelection.collapsed(offset: g.length));
  }
}

List<TextInputFormatter> _digits(int maxLen, {bool group = false}) =>
    [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(maxLen), if (group) const _GroupFormatter()];

abstract final class TaxiEditFareSheet {
  static Future<void> show(BuildContext context, TaxiHubController ctrl, TaxiRouteModel route) {
    final taxi = ctrl.taxi;
    if (taxi == null) return Future.value();
    if (taxi.isPendingReview) {
      AppToast.info(TaxiHubStrings.underReview);
      return Future.value();
    }
    final text = TextEditingController(text: Money.group(route.fare));
    final value = ValueNotifier<String>(text.text);
    text.addListener(() => value.value = text.text);
    return OwnerSheet.show<void>(
      context,
      look: OwnerLook.taxi,
      title: TaxiHubStrings.editFareTitle,
      subtitle: TaxiHubStrings.editFareSub(TaxiHubStrings.routeTitleOf(route.fromName, route.toName), route.roundTrip),
      art: ListingArt.moneyBag,
      size: SheetSize.hug,
      dirty: () => TaxiRules.parse(text.text) != route.fare,
      child: (c) => ValueListenableBuilder<String>(
        valueListenable: value,
        builder: (_, t, _) {
          final err = t.trim().isEmpty ? null : TaxiRules.fareError(t);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap.v(6),
              PillField(
                tone: ListingTone.coral,
                controller: text,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: _digits(8, group: true),
                prefixText: TaxiHubStrings.rupee,
                errorRing: err != null,
              ),
              Gap.v(8),
              Semantics(
                liveRegion: true,
                child: Text(
                  err ?? TaxiHubStrings.fareHint,
                  style: Ink3D.text(11.5, FontWeight.w400, err != null ? TaxiLook.redText : Ink3D.grey, height: 1.4, letterSpacing: 0),
                ),
              ),
              Gap.v(8),
            ],
          );
        },
      ),
      footer: (c) => ValueListenableBuilder<String>(
        valueListenable: value,
        builder: (_, t, _) => Obx(
          () => GradientPillButton(
            tone: ListingTone.coral,
            label: TaxiHubStrings.save,
            loading: ctrl.busy.value,
            enabled: TaxiRules.fareOk(TaxiRules.parse(t)) && !ctrl.busy.value,
            onTap: () async {
              final v = TaxiRules.parse(t);
              if (!TaxiRules.fareOk(v)) return;
              if (v == route.fare) {
                Navigator.of(c).pop();
                return;
              }
              final ok = await ctrl.updateFare(route.id, v ?? 0);
              if (ok && c.mounted) Navigator.of(c).pop();
            },
          ),
        ),
      ),
    ).whenComplete(() {
      text.dispose();
      value.dispose();
    });
  }
}

abstract final class TaxiLocalRateSheet {
  static Future<void> show(BuildContext context, TaxiHubController ctrl) {
    final taxi = ctrl.taxi;
    if (taxi == null) return Future.value();
    if (taxi.isPendingReview) {
      AppToast.info(TaxiHubStrings.underReview);
      return Future.value();
    }
    final rate = TextEditingController(text: taxi.localDayRate == null ? '' : Money.group(taxi.localDayRate ?? 0));
    final km = TextEditingController(text: taxi.localDayKm?.toString() ?? '');
    final tick = ValueNotifier<int>(0);
    void bump() => tick.value++;
    rate.addListener(bump);
    km.addListener(bump);
    return OwnerSheet.show<void>(
      context,
      look: OwnerLook.taxi,
      title: TaxiHubStrings.localTitle,
      subtitle: TaxiHubStrings.localSub,
      art: ListingArt.mountain,
      size: SheetSize.hug,
      dirty: () => rate.text != (taxi.localDayRate == null ? '' : Money.group(taxi.localDayRate ?? 0)) || km.text != (taxi.localDayKm?.toString() ?? ''),
      child: (c) => ValueListenableBuilder<int>(
        valueListenable: tick,
        builder: (_, _, _) {
          final r = TaxiRules.parse(rate.text);
          final k = TaxiRules.parse(km.text);
          final rateBad = rate.text.trim().isNotEmpty && !TaxiRules.fareOk(r);
          final kmBad = km.text.trim().isNotEmpty && !TaxiRules.kmOk(k);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap.v(6),
              _label(TaxiHubStrings.dayRate),
              PillField(
                tone: ListingTone.coral,
                controller: rate,
                keyboardType: TextInputType.number,
                inputFormatters: _digits(8, group: true),
                prefixText: TaxiHubStrings.rupee,
                errorRing: rateBad,
              ),
              if (rateBad) _hint(TaxiHubStrings.fareRange, bad: true),
              Gap.v(10),
              _label(TaxiHubStrings.kmIncluded),
              PillField(tone: ListingTone.coral, controller: km, keyboardType: TextInputType.number, inputFormatters: _digits(4), errorRing: kmBad),
              if (kmBad) _hint(TaxiHubStrings.kmRange, bad: true),
              Gap.v(10),
              _hint(TaxiHubStrings.localNote),
              Gap.v(8),
            ],
          );
        },
      ),
      footer: (c) => ValueListenableBuilder<int>(
        valueListenable: tick,
        builder: (_, _, _) => Obx(() {
          final r = TaxiRules.parse(rate.text);
          final k = TaxiRules.parse(km.text);
          final empty = rate.text.trim().isEmpty && km.text.trim().isEmpty;
          final valid = empty || (TaxiRules.fareOk(r) && TaxiRules.kmOk(k));
          return GradientPillButton(
            tone: ListingTone.coral,
            label: TaxiHubStrings.save,
            loading: ctrl.busy.value,
            enabled: valid && !ctrl.busy.value,
            onTap: () async {
              final ok = await ctrl.saveLocalRate(empty ? null : r, empty ? null : k);
              if (ok && c.mounted) Navigator.of(c).pop();
            },
          );
        }),
      ),
    ).whenComplete(() {
      rate.dispose();
      km.dispose();
      tick.dispose();
    });
  }

  static Widget _label(String t) => Padding(
        padding: EdgeInsets.only(bottom: DS.gv(4), left: DS.gh(4)),
        child: Text(t, style: Ink3D.text(12, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
      );

  static Widget _hint(String t, {bool bad = false}) => Padding(
        padding: EdgeInsets.only(top: DS.gv(6), left: DS.gh(4)),
        child: Semantics(
          liveRegion: bad,
          child: Text(t, style: Ink3D.text(11.5, FontWeight.w400, bad ? TaxiLook.redText : Ink3D.grey, height: 1.4, letterSpacing: 0)),
        ),
      );
}

class _EditRouteDraft {
  _EditRouteDraft(TaxiRouteModel r)
      : from = TaxiRoutePlace(name: r.fromName, label: r.fromLabel, lat: r.fromLatitude, lng: r.fromLongitude, cityKey: r.fromCityKey, other: r.fromOtherPlace),
        to = TaxiRoutePlace(name: r.toName, label: r.toLabel, lat: r.toLatitude, lng: r.toLongitude, cityKey: r.toCityKey, other: r.toOtherPlace),
        roundTrip = r.roundTrip;

  TaxiRoutePlace from;
  TaxiRoutePlace to;
  bool roundTrip;
}

abstract final class TaxiEditRouteSheet {
  static TaxiRoutePlace _place(TripCityModel c) => TaxiRoutePlace(
        name: c.name.trim().length > 80 ? c.name.trim().substring(0, 80) : c.name.trim(),
        label: c.placeLine.isNotEmpty ? (c.placeLine.length > 160 ? c.placeLine.substring(0, 160) : c.placeLine) : null,
        lat: c.latitude,
        lng: c.longitude,
        cityKey: c.cityKey,
      );

  static String? sameAs(TaxiRoutePlace from, TaxiRoutePlace to, List<TaxiRouteModel> others) {
    if (from.name.trim().toLowerCase() == to.name.trim().toLowerCase()) return TaxiHubStrings.sameCity;
    for (final o in others) {
      if (o.fromName.toLowerCase() == from.name.toLowerCase() && o.toName.toLowerCase() == to.name.toLowerCase()) return TaxiHubStrings.duplicateRoute;
    }
    return null;
  }

  static Future<void> show(BuildContext context, TaxiHubController ctrl, TaxiRouteModel route) {
    final taxi = ctrl.taxi;
    if (taxi == null) return Future.value();
    if (taxi.isPendingReview) {
      AppToast.info(TaxiHubStrings.underReview);
      return Future.value();
    }
    final draft = _EditRouteDraft(route);
    final fare = TextEditingController(text: Money.group(route.fare));
    final tick = ValueNotifier<int>(0);
    void bump() => tick.value++;
    fare.addListener(bump);
    return OwnerSheet.show<void>(
      context,
      look: OwnerLook.taxi,
      title: TaxiHubStrings.editRouteTitle,
      subtitle: TaxiHubStrings.routeNumber(route.routeIndex),
      size: SheetSize.form,
      dirty: () =>
          draft.from.name != route.fromName ||
          draft.to.name != route.toName ||
          draft.roundTrip != route.roundTrip ||
          TaxiRules.parse(fare.text) != route.fare,
      child: (c) => ValueListenableBuilder<int>(
        valueListenable: tick,
        builder: (_, _, _) {
          final fareErr = fare.text.trim().isEmpty ? null : TaxiRules.fareError(fare.text);
          Widget placeRow(String label, TaxiRoutePlace p, VoidCallback onTap) => Padding(
                padding: EdgeInsets.only(bottom: DS.gv(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: DS.gh(4), bottom: DS.gv(4)),
                      child: Text(label, style: Ink3D.text(12, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                    ),
                    Semantics(
                      button: true,
                      label: '$label ${p.name}',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: DS.circular(22),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: DS.s(48)),
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(22), border: Border.all(color: ListingPalette.coral.line, width: DS.s(1.5))),
                            child: Padding(
                              padding: DS.sym(h: 16, v: 10),
                              child: Row(
                                children: [
                                  Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                                  Icon(Icons.arrow_drop_down_rounded, size: DS.s(22), color: Ink3D.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
          Future<void> pick(bool isFrom) async {
            final choice = await TaxiRouteCitySheet.pick(c, title: isFrom ? TaxiHubStrings.fromLabel : TaxiHubStrings.toLabel, selectedKey: (isFrom ? draft.from : draft.to).cityKey);
            if (choice is TaxiRouteCityPicked) {
              if (isFrom) {
                draft.from = _place(choice.city);
              } else {
                draft.to = _place(choice.city);
              }
              bump();
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap.v(6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: placeRow(TaxiHubStrings.fromLabel, draft.from, () => pick(true))),
                  Gap.h(10),
                  Expanded(child: placeRow(TaxiHubStrings.toLabel, draft.to, () => pick(false))),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(left: DS.gh(4), bottom: DS.gv(4)),
                child: Text(TaxiHubStrings.fareLabel, style: Ink3D.text(12, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
              ),
              PillField(
                tone: ListingTone.coral,
                controller: fare,
                keyboardType: TextInputType.number,
                inputFormatters: _digits(8, group: true),
                prefixText: TaxiHubStrings.rupee,
                errorRing: fareErr != null,
              ),
              if (fareErr != null)
                Padding(
                  padding: EdgeInsets.only(top: DS.gv(6), left: DS.gh(4)),
                  child: Semantics(liveRegion: true, child: Text(fareErr, style: Ink3D.text(11.5, FontWeight.w400, TaxiLook.redText, letterSpacing: 0))),
                ),
              Gap.v(12),
              Row(
                children: [
                  Expanded(child: TaxiPill(label: TaxiHubStrings.oneWay, kind: draft.roundTrip ? TaxiPillKind.outline : TaxiPillKind.coral, expand: true, onTap: () {
                    draft.roundTrip = false;
                    bump();
                  })),
                  Gap.h(10),
                  Expanded(child: TaxiPill(label: TaxiHubStrings.roundTrip, kind: draft.roundTrip ? TaxiPillKind.coral : TaxiPillKind.outline, expand: true, onTap: () {
                    draft.roundTrip = true;
                    bump();
                  })),
                ],
              ),
              Gap.v(12),
              TaxiStrip(
                art: ListingArt.warning,
                text: TaxiHubStrings.closeOldRoute,
                fill: TaxiLook.amberSoft,
                ink: TaxiLook.amberText,
                margin: EdgeInsets.zero,
              ),
              Gap.v(8),
            ],
          );
        },
      ),
      footer: (c) => ValueListenableBuilder<int>(
        valueListenable: tick,
        builder: (_, _, _) => Obx(() {
          final f = TaxiRules.parse(fare.text);
          final problem = sameAs(draft.from, draft.to, [for (final r in taxi.routes) if (r.id != route.id) r]);
          return GradientPillButton(
            tone: ListingTone.coral,
            label: TaxiHubStrings.saveRoute,
            loading: ctrl.busy.value,
            enabled: TaxiRules.fareOk(f) && !ctrl.busy.value,
            onTap: () async {
              if (problem != null) {
                AppToast.warning(problem);
                return;
              }
              final payload = [
                for (final r in taxi.routes)
                  if (r.id == route.id)
                    r.toPayload(fare: f, tripType: draft.roundTrip ? 'RoundTrip' : 'OneWay', from: draft.from, to: draft.to)
                  else
                    r.toPayload(),
              ];
              final ok = await ctrl.saveRoutes(payload, TaxiHubStrings.routeSaved);
              if (ok && c.mounted) Navigator.of(c).pop();
            },
          );
        }),
      ),
    ).whenComplete(() {
      fare.dispose();
      tick.dispose();
    });
  }
}

abstract final class TaxiReviewSheet {
  static Future<bool> ask(BuildContext context) async {
    final ok = await OwnerSheet.show<bool>(
      context,
      look: OwnerLook.taxi,
      title: TaxiHubStrings.reviewTitle,
      art: ListingArt.clipboard,
      size: SheetSize.hug,
      child: (c) => Padding(
        padding: EdgeInsets.only(top: DS.gv(6), bottom: DS.gv(8)),
        child: Text(TaxiHubStrings.reviewBody, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, height: 1.45, letterSpacing: 0)),
      ),
      footer: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GradientPillButton(tone: ListingTone.coral, label: TaxiHubStrings.reviewSend, onTap: () => Navigator.of(c).pop(true)),
          Gap.v(6),
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(TaxiHubStrings.reviewCancel, style: Ink3D.text(14, FontWeight.w600, Ink3D.grey)),
          ),
        ],
      ),
    );
    return ok == true;
  }
}
