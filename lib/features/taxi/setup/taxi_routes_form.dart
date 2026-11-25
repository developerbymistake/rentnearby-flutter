import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/search_fold.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../taxi_driver/strings/taxi_setup_strings.dart';
import '../../trip/data/trip_city_catalog.dart';
import '../../trip/models/trip_city_model.dart';
import '../models/taxi_owner_model.dart';
import '../taxi_option_sets.dart';
import 'taxi_route_city_sheet.dart';
import 'taxi_route_strings.dart';
import 'taxi_setup_controller.dart';

class TaxiRoutePlace {
  final String name;
  final String? label;
  final double lat;
  final double lng;
  final int? cityKey;
  final bool otherPlace;
  const TaxiRoutePlace({required this.name, this.label, required this.lat, required this.lng, this.cityKey, this.otherPlace = false});

  bool get named => cityKey != null || otherPlace;

  factory TaxiRoutePlace.fromPicked(PickedPlace p) => TaxiRoutePlace(
        name: _cut(p.name.trim(), 80),
        label: p.districtName.trim().isNotEmpty ? _cut(p.districtName.trim(), 160) : null,
        lat: p.latitude,
        lng: p.longitude,
        otherPlace: true,
      );

  factory TaxiRoutePlace.fromCity(TripCityModel c) => TaxiRoutePlace(
        name: _cut(c.name.trim(), 80),
        label: c.placeLine.isNotEmpty ? _cut(c.placeLine, 160) : null,
        lat: c.latitude,
        lng: c.longitude,
        cityKey: c.cityKey,
      );

  static String _cut(String s, int max) => s.length > max ? s.substring(0, max) : s;
}

class TaxiRouteDraft {
  final String? id;
  final TaxiRoutePlace from;
  final TaxiRoutePlace to;
  final int fare;
  final String tripType;
  const TaxiRouteDraft({this.id, required this.from, required this.to, required this.fare, required this.tripType});

  bool get active => from.cityKey != null && to.cityKey != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromName': from.name,
        'fromLabel': from.label,
        'fromLatitude': from.lat,
        'fromLongitude': from.lng,
        'toName': to.name,
        'toLabel': to.label,
        'toLatitude': to.lat,
        'toLongitude': to.lng,
        'fare': fare,
        'tripType': tripType,
        if (from.named && to.named) ...{
          'fromCityKey': from.cityKey,
          'toCityKey': to.cityKey,
          'fromOtherPlace': from.cityKey == null,
          'toOtherPlace': to.cityKey == null,
        },
      };

  String get key => '${from.lat.toStringAsFixed(3)}|${from.lng.toStringAsFixed(3)}|'
      '${to.lat.toStringAsFixed(3)}|${to.lng.toStringAsFixed(3)}|$tripType';
}

enum TaxiRouteRing { from, to, fare, trip }

class TaxiRoutesFormController extends ChangeNotifier {
  TaxiRoutesFormController({required this.onboarding});

  final bool onboarding;
  final _ctrl = TaxiSetupController.ensure();
  final formKey = GlobalKey();
  final fareCtrl = TextEditingController();
  final fareFocusNode = FocusNode();
  final List<TaxiRouteDraft> routes = [];
  bool formOpen = false;
  int? editingIndex;
  String? _editingId;
  TaxiRoutePlace? from;
  TaxiRoutePlace? to;
  String? tripType;
  bool dirty = false;
  TaxiRouteRing? ring;
  bool _picking = false;
  bool _disposed = false;

  int get max => onboarding ? PlanKeys.freeSeed[PlanKey.routes]! : TaxiOptionSets.maxRoutes;

  int get count => routes.length + (formOpen ? 1 : 0);

  void seed(TaxiOwnerModel? t) {
    routes.clear();
    for (final r in t?.routes ?? const []) {
      routes.add(TaxiRouteDraft(
        id: r.id,
        from: TaxiRoutePlace(
            name: r.fromName, label: r.fromLabel, lat: r.fromLatitude, lng: r.fromLongitude, cityKey: r.fromCityKey, otherPlace: r.fromOtherPlace),
        to: TaxiRoutePlace(name: r.toName, label: r.toLabel, lat: r.toLatitude, lng: r.toLongitude, cityKey: r.toCityKey, otherPlace: r.toOtherPlace),
        fare: r.fare,
        tripType: r.tripType,
      ));
    }
    formOpen = routes.length < max;
    clearForm();
    dirty = false;
    ring = null;
    _notify();
  }

  void refreshDefaultFrom() {
    if (editingIndex != null || to != null || fareCtrl.text.trim().isNotEmpty || tripType != null) return;
    from = defaultFrom;
    _notify();
  }

  bool get _fromIsDefault {
    final f = from;
    if (f == null) return true;
    final d = defaultFrom;
    return d != null && d.name == f.name && d.lat == f.lat && d.lng == f.lng;
  }

  bool get formBlank => _fromIsDefault && to == null && fareCtrl.text.trim().isEmpty && tripType == null;

  TaxiRoutePlace? get defaultFrom {
    if (routes.isNotEmpty) return routes.last.from;
    final name = SearchFold.fold(_ctrl.taxi.value?.locality ?? '');
    if (name.isEmpty || !Get.isRegistered<TripCityCatalog>()) return null;
    for (final c in Get.find<TripCityCatalog>().search(name)) {
      if (SearchFold.fold(c.name) == name) return TaxiRoutePlace.fromCity(c);
    }
    return null;
  }

  void clearForm() {
    from = defaultFrom;
    to = null;
    fareCtrl.clear();
    tripType = null;
    editingIndex = null;
    _editingId = null;
  }

  void openForm() {
    formOpen = true;
    _notify();
  }

  void closeForm() {
    formOpen = false;
    _notify();
  }

  Future<void> pickPlace(BuildContext context, bool isFrom) async {
    if (_picking) return;
    _picking = true;
    FocusScope.of(context).unfocus();
    try {
      final choice = await TaxiRouteCitySheet.pick(context,
          title: isFrom ? TaxiRouteStrings.fromCity : TaxiRouteStrings.toCity, selectedKey: (isFrom ? from : to)?.cityKey);
      if (choice == null || !context.mounted || _disposed) return;
      final TaxiRoutePlace place;
      switch (choice) {
        case TaxiRouteCityPicked(:final city):
          place = TaxiRoutePlace.fromCity(city);
        case TaxiRouteOtherPlace():
          final picked = await LocationSwitchSheet.pick(context, palette: templateModulePalette, title: TaxiRouteStrings.otherPlace);
          if (picked == null || !context.mounted || _disposed) return;
          place = TaxiRoutePlace.fromPicked(picked);
      }
      if (isFrom) {
        from = place;
      } else {
        to = place;
      }
      if (ring == (isFrom ? TaxiRouteRing.from : TaxiRouteRing.to)) ring = null;
      dirty = true;
      _notify();
    } finally {
      _picking = false;
    }
  }

  bool saveForm() => commitForm(skipBlank: false);

  bool commitForm({bool skipBlank = true}) {
    if (!formOpen) return true;
    if (skipBlank && formBlank && editingIndex == null) {
      formOpen = false;
      clearForm();
      _notify();
      return true;
    }
    final f = from, t = to;
    if (f == null) {
      AppToast.error('Pick a From place');
      mark(TaxiRouteRing.from);
      return false;
    }
    if (t == null) {
      AppToast.error('Pick a To place');
      mark(TaxiRouteRing.to);
      return false;
    }
    if (!f.named || !t.named) {
      AppToast.error(f.named ? TaxiRouteStrings.chooseToAgain : TaxiRouteStrings.chooseFromAgain);
      mark(f.named ? TaxiRouteRing.to : TaxiRouteRing.from);
      return false;
    }
    if (TaxiOptionSets.distanceMeters(f.lat, f.lng, t.lat, t.lng) < TaxiOptionSets.minEndpointDistanceMeters) {
      AppToast.error('From and To must be different places');
      mark(TaxiRouteRing.to);
      return false;
    }
    final fareText = fareCtrl.text.trim();
    if (fareText.isEmpty) {
      AppToast.error('Enter the fare');
      mark(TaxiRouteRing.fare);
      fareFocusNode.requestFocus();
      return false;
    }
    final fare = int.tryParse(fareText) ?? 0;
    if (fare < TaxiOptionSets.minFare || fare > TaxiOptionSets.maxFare) {
      AppToast.error('Fare must be between ₹100 and ₹99,00,000');
      mark(TaxiRouteRing.fare);
      fareFocusNode.requestFocus();
      return false;
    }
    if (tripType == null) {
      AppToast.error('Pick One way or Round trip');
      mark(TaxiRouteRing.trip);
      return false;
    }
    final draft = TaxiRouteDraft(id: _editingId, from: f, to: t, fare: fare, tripType: tripType!);
    if (routes.any((r) => r.key == draft.key)) {
      AppToast.error('This route is already added');
      mark(TaxiRouteRing.to);
      return false;
    }
    final at = editingIndex;
    if (at != null && at <= routes.length) {
      routes.insert(at, draft);
    } else {
      routes.add(draft);
    }
    formOpen = false;
    clearForm();
    ring = null;
    _notify();
    return true;
  }

  bool validate() {
    if (!commitForm()) return false;
    if (routes.isEmpty) {
      AppToast.error('Add at least one route');
      formOpen = true;
      _notify();
      reveal(formKey);
      return false;
    }
    return true;
  }

  List<Map<String, dynamic>> payload() => [for (final r in routes) r.toJson()];

  String get key => payload().toString();

  void reveal(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 250));
    });
  }

  void mark(TaxiRouteRing r) {
    ring = r;
    _notify();
    reveal(formKey);
  }

  void editRoute(int i) {
    final r = routes[i];
    if (formOpen && !commitForm()) return;
    final at = routes.indexOf(r);
    if (at < 0) return;
    routes.removeAt(at);
    editingIndex = at;
    _editingId = r.id;
    from = r.from;
    to = r.to;
    fareCtrl.text = '${r.fare}';
    tripType = r.tripType;
    formOpen = true;
    dirty = true;
    _notify();
  }

  void removeRoute(int i) {
    routes.removeAt(i);
    final at = editingIndex;
    if (at != null && at > i) editingIndex = at - 1;
    if (!formOpen && routes.isEmpty) {
      if (onboarding) clearForm();
      formOpen = true;
    }
    dirty = true;
    _notify();
  }

  void pickTrip(int i) {
    tripType = TaxiOptionSets.tripTypes[i].value;
    dirty = true;
    if (ring == TaxiRouteRing.trip) ring = null;
    _notify();
  }

  void onFareChanged() {
    dirty = true;
    if (ring == TaxiRouteRing.fare) {
      ring = null;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    fareCtrl.dispose();
    fareFocusNode.dispose();
    super.dispose();
  }
}

class TaxiRouteSummaries extends StatelessWidget {
  const TaxiRouteSummaries({super.key, required this.controller, required this.tone});
  final TaxiRoutesFormController controller;
  final ListingTone tone;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final routes = controller.routes;
          return Column(children: [
            for (var i = 0; i < routes.length; i++)
              TaxiRouteCard3D(
                tone: tone,
                tag: '',
                title: TaxiSetupStrings.routeTitle(routes[i].from.name, routes[i].to.name),
                subtitle: TaxiSetupStrings.routeLine(i + 1, TaxiOptionSets.tripLabel(routes[i].tripType), routes[i].fare),
                note: routes[i].active ? TaxiRouteStrings.activeInRequests : TaxiRouteStrings.notActive,
                noteOk: routes[i].active,
                onEdit: () => controller.editRoute(i),
                onRemove: () => controller.removeRoute(i),
              ),
          ]);
        },
      );
}

class TaxiRouteFormCard extends StatelessWidget {
  const TaxiRouteFormCard({super.key, required this.controller, required this.tone});
  final TaxiRoutesFormController controller;
  final ListingTone tone;

  Widget _placeField(BuildContext context, {required String label, required bool first, required TaxiRoutePlace? place, required bool ring, required bool isFrom}) {
    final field = PillPickerField(
      tone: tone,
      label: label,
      value: place?.name,
      sublabel: place?.label,
      hint: TaxiRouteStrings.chooseCity,
      helperText: place != null && place.cityKey == null ? TaxiRouteStrings.otherPlaceNote : null,
      errorRing: ring,
      trailing: Image.asset(ListingArt.pushpin, width: DS.s(26), height: DS.s(26)),
      onTap: () => controller.pickPlace(context, isFrom),
    );
    return first ? field : Padding(padding: EdgeInsets.only(top: DS.gv(14)), child: field);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          if (!c.formOpen) return const SizedBox.shrink();
          final number = (c.editingIndex ?? c.routes.length) + 1;
          final hint = c.editingIndex != null
              ? TaxiSetupStrings.editRoute
              : c.onboarding
                  ? TaxiSetupStrings.addOneRoute
                  : TaxiSetupStrings.newRoute;
          return FormSectionCard(
            key: c.formKey,
            tone: tone,
            art: ListingArt.compass,
            artSide: FormArtSide.right,
            title: TaxiSetupStrings.routeNumber(number),
            hint: hint,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _placeField(context, label: 'From *', first: true, place: c.from, ring: c.ring == TaxiRouteRing.from, isFrom: true),
              _placeField(context, label: 'To *', first: false, place: c.to, ring: c.ring == TaxiRouteRing.to, isFrom: false),
              PillField(
                tone: tone,
                label: 'Fare (₹) *',
                firstLabel: false,
                controller: c.fareCtrl,
                focusNode: c.fareFocusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                prefixText: '₹',
                hint: 'e.g. 4500',
                errorRing: c.ring == TaxiRouteRing.fare,
                onChanged: (_) => c.onFareChanged(),
              ),
              const FieldLabel('Trip *'),
              SegmentPills(
                tone: tone,
                labels: [for (final t in TaxiOptionSets.tripTypes) t.label],
                selected: c.tripType == null ? null : TaxiOptionSets.tripTypes.indexWhere((t) => t.value == c.tripType),
                errorRing: c.ring == TaxiRouteRing.trip,
                onTap: c.pickTrip,
              ),
            ]),
          );
        },
      );
}

class TaxiRoutesForm extends StatelessWidget {
  const TaxiRoutesForm({super.key, required this.controller, required this.tone});
  final TaxiRoutesFormController controller;
  final ListingTone tone;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TaxiRouteSummaries(controller: controller, tone: tone),
        TaxiRouteFormCard(controller: controller, tone: tone),
      ]);
}
