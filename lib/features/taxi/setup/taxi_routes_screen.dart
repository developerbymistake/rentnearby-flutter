import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/search_fold.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../taxi_driver/strings/taxi_gate_strings.dart';
import '../../taxi_driver/strings/taxi_setup_strings.dart';
import '../../trip/data/trip_city_catalog.dart';
import '../../trip/models/trip_city_model.dart';
import '../../trip/trip_strings_a3.dart';
import '../guest/v2/taxi_rate_strings.dart';
import '../taxi_option_sets.dart';
import 'taxi_rate_rules.dart';
import 'taxi_route_city_sheet.dart';
import 'taxi_route_strings.dart';
import 'taxi_setup_controller.dart';

class _Place {
  final String name;
  final String? label;
  final double lat;
  final double lng;
  final int? cityKey;
  final bool otherPlace;
  const _Place({required this.name, this.label, required this.lat, required this.lng, this.cityKey, this.otherPlace = false});

  bool get named => cityKey != null || otherPlace;

  factory _Place.fromPicked(PickedPlace p) => _Place(
        name: _cut(p.name.trim(), 80),
        label: p.districtName.trim().isNotEmpty ? _cut(p.districtName.trim(), 160) : null,
        lat: p.latitude,
        lng: p.longitude,
        otherPlace: true,
      );

  factory _Place.fromCity(TripCityModel c) => _Place(
        name: _cut(c.name.trim(), 80),
        label: c.placeLine.isNotEmpty ? _cut(c.placeLine, 160) : null,
        lat: c.latitude,
        lng: c.longitude,
        cityKey: c.cityKey,
      );

  static String _cut(String s, int max) => s.length > max ? s.substring(0, max) : s;
}

class _RouteDraft {
  final String? id;
  final _Place from;
  final _Place to;
  final int fare;
  final String tripType;
  const _RouteDraft({this.id, required this.from, required this.to, required this.fare, required this.tripType});

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

class TaxiRoutesScreen extends StatefulWidget {
  const TaxiRoutesScreen({super.key});
  @override
  State<TaxiRoutesScreen> createState() => _TaxiRoutesScreenState();
}

enum _Ring { rate, km, from, to, fare, trip }

class _TaxiRoutesScreenState extends State<TaxiRoutesScreen> with TickerProviderStateMixin {
  static final ListingTone _tone = ListingTone.coral;
  final _rateKey = GlobalKey();
  final _formKey = GlobalKey();
  _Ring? _ring;
  late final AnimationController _anim = SetupKit.controller(this);
  final _ctrl = TaxiSetupController.ensure();
  final _fareCtrl = TextEditingController();
  final _fareFocusNode = FocusNode();
  final _rateCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  bool _savingRate = false;
  final List<_RouteDraft> _routes = [];
  bool _formOpen = false;
  int? _editingIndex;
  String? _editingId;
  _Place? _from;
  _Place? _to;
  String? _tripType;
  bool _dirty = false;
  bool _picking = false;

  static const _max = TaxiOptionSets.maxRoutes;

  int get _planMax {
    final l = PlanGate.limit(PlanKey.routes);
    return l <= 0 ? 1 : (l > _max ? _max : l);
  }

  bool get _planFull => _routes.length >= _planMax;

  Future<bool> _planAllowsSave() async {
    if (_routes.length <= _planMax) return true;
    if (PlanGate.canUpgrade) {
      await PlanGate.showLimit(context, TaxiGateStrings.routeGate());
    } else {
      AppToast.warning('You can add up to $_planMax routes');
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    for (final r in _ctrl.taxi.value?.routes ?? const []) {
      _routes.add(_RouteDraft(
        id: r.id,
        from: _Place(
            name: r.fromName, label: r.fromLabel, lat: r.fromLatitude, lng: r.fromLongitude, cityKey: r.fromCityKey, otherPlace: r.fromOtherPlace),
        to: _Place(name: r.toName, label: r.toLabel, lat: r.toLatitude, lng: r.toLongitude, cityKey: r.toCityKey, otherPlace: r.toOtherPlace),
        fare: r.fare,
        tripType: r.tripType,
      ));
    }
    _formOpen = _routes.length < _max && !(PlanGate.canUpgrade && _routes.isNotEmpty && _planFull);
    _from = _defaultFrom;
    _syncRateFields();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SetupKit.play(_anim, context);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _fareCtrl.dispose();
    _fareFocusNode.dispose();
    _rateCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  String get _storedRate => '${_ctrl.taxi.value?.localDayRate ?? ''}';
  String get _storedKm => '${_ctrl.taxi.value?.localDayKm ?? ''}';
  bool get _rateEditable => _ctrl.taxi.value?.canEditSetup ?? true;
  bool get _rateDirty => _rateCtrl.text.trim() != _storedRate || _kmCtrl.text.trim() != _storedKm;

  void _syncRateFields() {
    _rateCtrl.text = _storedRate;
    _kmCtrl.text = _storedKm;
  }

  Future<bool> _persistRate({required bool quiet}) async {
    if (_savingRate || _ctrl.isSaving.value) return false;
    final rateText = _rateCtrl.text.trim();
    final kmText = _kmCtrl.text.trim();
    final error = TaxiRateRules.validate(rateText, kmText);
    if (error != null) {
      AppToast.error(error);
      _markRate();
      return false;
    }
    final rate = int.parse(rateText);
    final km = int.parse(kmText);
    setState(() => _savingRate = true);
    final ok = await _ctrl.saveLocalRate(dayRate: rate, kmPerDay: km);
    if (!mounted) return ok;
    setState(() {
      _savingRate = false;
      if (ok) _syncRateFields();
    });
    if (ok && !quiet) AppToast.success('Rate saved');
    return ok;
  }

  int get _count => _routes.length + (_formOpen ? 1 : 0);

  bool get _fromIsDefault {
    final from = _from;
    if (from == null) return true;
    final d = _defaultFrom;
    return d != null && d.name == from.name && d.lat == from.lat && d.lng == from.lng;
  }

  bool get _formBlank => _fromIsDefault && _to == null && _fareCtrl.text.trim().isEmpty && _tripType == null;

  _Place? get _defaultFrom {
    if (_routes.isNotEmpty) return _routes.last.from;
    final name = SearchFold.fold(_ctrl.taxi.value?.locality ?? '');
    if (name.isEmpty || !Get.isRegistered<TripCityCatalog>()) return null;
    for (final c in Get.find<TripCityCatalog>().search(name)) {
      if (SearchFold.fold(c.name) == name) return _Place.fromCity(c);
    }
    return null;
  }

  void _clearForm() {
    _from = _defaultFrom;
    _to = null;
    _fareCtrl.clear();
    _tripType = null;
    _editingIndex = null;
    _editingId = null;
  }

  Future<void> _pickPlace(bool isFrom) async {
    if (_picking) return;
    _picking = true;
    FocusScope.of(context).unfocus();
    try {
      final choice = await TaxiRouteCitySheet.pick(context,
          title: isFrom ? TaxiRouteStrings.fromCity : TaxiRouteStrings.toCity, selectedKey: (isFrom ? _from : _to)?.cityKey);
      if (choice == null || !mounted) return;
      final _Place place;
      switch (choice) {
        case TaxiRouteCityPicked(:final city):
          place = _Place.fromCity(city);
        case TaxiRouteOtherPlace():
          final picked = await LocationSwitchSheet.pick(context, palette: templateModulePalette, title: TaxiRouteStrings.otherPlace);
          if (picked == null || !mounted) return;
          place = _Place.fromPicked(picked);
      }
      setState(() {
        if (isFrom) {
          _from = place;
        } else {
          _to = place;
        }
        if (_ring == (isFrom ? _Ring.from : _Ring.to)) _ring = null;
        _dirty = true;
      });
    } finally {
      _picking = false;
    }
  }

  bool _commitForm() {
    if (!_formOpen) return true;
    if (_formBlank && _editingIndex == null) {
      setState(() {
        _formOpen = false;
        _clearForm();
      });
      return true;
    }
    final from = _from, to = _to;
    if (from == null) {
      AppToast.error('Pick a From place');
      _mark(_Ring.from);
      return false;
    }
    if (to == null) {
      AppToast.error('Pick a To place');
      _mark(_Ring.to);
      return false;
    }
    if (!from.named || !to.named) {
      AppToast.error(from.named ? TaxiRouteStrings.chooseToAgain : TaxiRouteStrings.chooseFromAgain);
      _mark(from.named ? _Ring.to : _Ring.from);
      return false;
    }
    if (TaxiOptionSets.distanceMeters(from.lat, from.lng, to.lat, to.lng) < TaxiOptionSets.minEndpointDistanceMeters) {
      AppToast.error('From and To must be different places');
      _mark(_Ring.to);
      return false;
    }
    final fareText = _fareCtrl.text.trim();
    if (fareText.isEmpty) {
      AppToast.error('Enter the fare');
      _mark(_Ring.fare);
      _fareFocusNode.requestFocus();
      return false;
    }
    final fare = int.tryParse(fareText) ?? 0;
    if (fare < TaxiOptionSets.minFare || fare > TaxiOptionSets.maxFare) {
      AppToast.error('Fare must be between ₹100 and ₹99,00,000');
      _mark(_Ring.fare);
      _fareFocusNode.requestFocus();
      return false;
    }
    if (_tripType == null) {
      AppToast.error('Pick One way or Round trip');
      _mark(_Ring.trip);
      return false;
    }
    final draft = _RouteDraft(id: _editingId, from: from, to: to, fare: fare, tripType: _tripType!);
    if (_routes.any((r) => r.key == draft.key)) {
      AppToast.error('This route is already added');
      _mark(_Ring.to);
      return false;
    }
    setState(() {
      final at = _editingIndex;
      if (at != null && at <= _routes.length) {
        _routes.insert(at, draft);
      } else {
        _routes.add(draft);
      }
      _formOpen = false;
      _clearForm();
      _ring = null;
    });
    return true;
  }

  void _reveal(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null && mounted) Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 250));
    });
  }

  void _mark(_Ring r) {
    setState(() => _ring = r);
    _reveal(_formKey);
  }

  void _markRate() {
    setState(() => _ring = TaxiRateRules.rateError(_rateCtrl.text) != null ? _Ring.rate : _Ring.km);
    _reveal(_rateKey);
  }

  void _addAnother() {
    if (_count >= _max) {
      AppToast.warning('You can add up to 10 routes');
      return;
    }
    if (_formOpen) {
      if (_formBlank) {
        AppToast.info('Fill this route first');
        return;
      }
      if (!_commitForm()) return;
    }
    setState(() => _formOpen = true);
  }

  void _editRoute(int i) {
    final r = _routes[i];
    if (_formOpen && !_commitForm()) return;
    final at = _routes.indexOf(r);
    if (at < 0) return;
    setState(() {
      _routes.removeAt(at);
      _editingIndex = at;
      _editingId = r.id;
      _from = r.from;
      _to = r.to;
      _fareCtrl.text = '${r.fare}';
      _tripType = r.tripType;
      _formOpen = true;
      _dirty = true;
    });
  }

  void _removeRoute(int i) {
    setState(() {
      _routes.removeAt(i);
      final at = _editingIndex;
      if (at != null && at > i) _editingIndex = at - 1;
      if (!_formOpen && _routes.isEmpty) _formOpen = true;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_ctrl.isSaving.value || _savingRate) return;
    FocusScope.of(context).unfocus();
    if (!_commitForm()) return;
    final rateDirty = _rateEditable && _rateDirty;
    if (_routes.isEmpty && !rateDirty) {
      AppToast.error('Add at least one route');
      setState(() => _formOpen = true);
      _reveal(_formKey);
      return;
    }
    final rateError = _rateEditable ? TaxiRateRules.validate(_rateCtrl.text, _kmCtrl.text) : null;
    if (rateError != null) {
      AppToast.error(rateError);
      _markRate();
      return;
    }
    if (rateDirty && !await _persistRate(quiet: _routes.isNotEmpty)) return;
    if (!mounted) return;
    if (_routes.isEmpty) {
      Get.back();
      return;
    }
    if (!await _planAllowsSave() || !mounted) return;
    final ok = await _ctrl.saveRoutes([for (final r in _routes) r.toJson()]);
    if (!mounted) return;
    if (!ok) {
      if (_ctrl.lastErrorType == 'TaxiRouteLimit' && PlanGate.canUpgrade) await PlanGate.showLimit(context, TaxiGateStrings.routeGate());
      return;
    }
    Get.back();
    AppToast.success('Routes saved');
  }

  Future<void> _confirmDiscard() async {
    final ok = await showTaxiOwnerDialog(
      context,
      art: ListingArt.clipboard,
      title: 'Discard changes?',
      body: 'Unsaved changes will be lost.',
      cancelLabel: 'Keep Editing',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (ok == true) Get.back();
  }

  void _onBack() {
    if (_ctrl.isSaving.value) return;
    if (_dirty || !_formBlank || _rateDirty) {
      _confirmDiscard();
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Stack(children: [
        Scaffold(
          backgroundColor: ListingPalette.coral.page,
          body: KitStatusBar(
            lightIcons: false,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                PageHeader3D(
                  tone: _tone,
                  title: TaxiSetupStrings.routesTitle,
                  subtitle: TaxiSetupStrings.routesStep,
                  art: ListingArt.compass,
                  inlineTitle: true,
                  onBack: _onBack,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(bottom: DS.s(24)),
                    children: [
                      SetupEntrance(controller: _anim, index: 0, count: 5, child: _meterCard()),
                      SetupEntrance(
                        controller: _anim,
                        index: 1,
                        count: 5,
                        child: Column(children: [for (var i = 0; i < _routes.length; i++) _summaryCard(i)]),
                      ),
                      SetupEntrance(
                        controller: _anim,
                        index: 2,
                        count: 5,
                        child: Column(children: [if (_formOpen) _form()]),
                      ),
                      SetupEntrance(controller: _anim, index: 3, count: 5, child: _tipRow()),
                      SetupEntrance(controller: _anim, index: 4, count: 5, child: _localRateCard()),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          bottomNavigationBar: Obx(() => FormFooter(
                tone: _tone,
                top: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const ToastDock(),
                  if (_formOpen)
                    Padding(
                      padding: EdgeInsets.only(bottom: DS.gv(8)),
                      child: Text(
                        TaxiSetupStrings.footerMeter(_routes.length, _planMax, free: PlanGate.canUpgrade),
                        key: const ValueKey('routes_footer_meter'),
                        textAlign: TextAlign.center,
                        style: Ink3D.text(12, FontWeight.w600, Form3D.muted, letterSpacing: 0),
                      ),
                    ),
                ]),
                primaryLabel: _formOpen ? TaxiSetupStrings.saveRoute : TaxiSetupStrings.save,
                primaryLoading: _ctrl.isSaving.value,
                onPrimary: _ctrl.isSaving.value ? null : _save,
                bottom: _formOpen ? null : _addRow(),
              )),
        ),
        Obx(() => _ctrl.isSaving.value
            ? SetupBusy(message: _savingRate ? 'Saving rate...' : 'Saving routes...', tone: KitTone.taxi, art: ListingArt.compass)
            : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _summaryCard(int i) {
    final r = _routes[i];
    return TaxiRouteCard3D(
      tone: _tone,
      tag: '',
      title: TaxiSetupStrings.routeTitle(r.from.name, r.to.name),
      subtitle: TaxiSetupStrings.routeLine(i + 1, TaxiOptionSets.tripLabel(r.tripType), r.fare),
      note: r.active ? TaxiRouteStrings.activeInRequests : TaxiRouteStrings.notActive,
      noteOk: r.active,
      onEdit: () => _editRoute(i),
      onRemove: () => _removeRoute(i),
    );
  }

  Widget _placeField({required String label, required bool first, required String asset, required _Place? place, required bool ring, required VoidCallback onTap}) =>
      PillPickerField(
        tone: _tone,
        label: label,
        value: place?.name,
        sublabel: place?.label,
        hint: TaxiRouteStrings.chooseCity,
        helperText: place != null && place.cityKey == null ? TaxiRouteStrings.otherPlaceNote : null,
        leadingArt: asset,
        errorRing: ring,
        trailing: Image.asset(ListingArt.pushpin, width: DS.s(26), height: DS.s(26)),
        onTap: onTap,
      ).withTopGap(first ? 0 : 14);

  Widget _form() {
    final number = (_editingIndex ?? _routes.length) + 1;
    return FormSectionCard(
      key: _formKey,
      tone: _tone,
      art: ListingArt.compass,
      artSide: FormArtSide.right,
      title: TaxiSetupStrings.routeNumber(number),
      hint: _editingIndex == null ? TaxiSetupStrings.newRoute : TaxiSetupStrings.editRoute,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _placeField(
            label: 'From *', first: true, asset: ListingArt.roundPushpin, place: _from, ring: _ring == _Ring.from, onTap: () => _pickPlace(true)),
        _placeField(
            label: 'To *', first: false, asset: ListingArt.worldMap, place: _to, ring: _ring == _Ring.to, onTap: () => _pickPlace(false)),
        PillField(
          tone: _tone,
          label: 'Fare (₹) *',
          firstLabel: false,
          controller: _fareCtrl,
          focusNode: _fareFocusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          prefixText: '₹',
          hint: 'e.g. 4500',
          errorRing: _ring == _Ring.fare,
          onChanged: (_) {
            _dirty = true;
            if (_ring == _Ring.fare) setState(() => _ring = null);
          },
        ),
        const FieldLabel('Trip *'),
        SegmentPills(
          tone: _tone,
          labels: [for (final t in TaxiOptionSets.tripTypes) t.label],
          selected: _tripType == null ? null : TaxiOptionSets.tripTypes.indexWhere((t) => t.value == _tripType),
          errorRing: _ring == _Ring.trip,
          onTap: (i) => setState(() {
            _tripType = TaxiOptionSets.tripTypes[i].value;
            _dirty = true;
            if (_ring == _Ring.trip) _ring = null;
          }),
        ),
      ]),
    );
  }

  Widget _localRateCard() {
    final editable = _rateEditable;
    return FormSectionCard(
      key: _rateKey,
      tone: _tone,
      art: ListingArt.taxi,
      artSide: FormArtSide.right,
      title: 'Local sightseeing',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(TaxiRateStrings.neededToList, style: FieldMessage.helperStyle.copyWith(fontSize: DS.f(12.5))),
        PillField(
          tone: _tone,
          label: TripStringsA3.driverRateLabel,
          firstLabel: false,
          controller: _rateCtrl,
          readOnly: !editable,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          prefixText: '₹',
          hint: 'e.g. 2500',
          errorRing: _ring == _Ring.rate,
          onChanged: (_) => setState(() {
            if (_ring == _Ring.rate) _ring = null;
          }),
        ),
        PillField(
          tone: _tone,
          label: TaxiRateStrings.kmLabel,
          firstLabel: false,
          controller: _kmCtrl,
          readOnly: !editable,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          hint: 'e.g. 120',
          suffix: Text('km', style: Ink3D.text(13, FontWeight.w500, Form3D.muted, letterSpacing: 0)),
          errorRing: _ring == _Ring.km,
          onChanged: (_) => setState(() {
            if (_ring == _Ring.km) _ring = null;
          }),
        ),
        Padding(
          padding: EdgeInsets.only(top: DS.gv(12)),
          child: Text('Travellers see this rate. You can quote a different fare for a trip after you read the itinerary.',
              style: FieldMessage.helperStyle.copyWith(fontSize: DS.f(12))),
        ),
      ]),
    );
  }

  Widget _meterCard() {
    final used = _routes.length;
    final limit = _planMax;
    final free = PlanGate.canUpgrade;
    final full = free && _planFull;
    final p = ListingPalette.coral;
    return FormSectionCard(
      tone: _tone,
      art: ListingArt.flag,
      title: TaxiSetupStrings.routes,
      trailing: Container(
        key: const ValueKey('routes_meter_chip'),
        padding: DS.sym(h: 9, v: 3),
        decoration: BoxDecoration(color: p.tint, borderRadius: DS.br(CardRadius.pill)),
        child: Text(TaxiSetupStrings.meterChip(used, limit, free: free), style: Ink3D.text(11, FontWeight.w700, p.text, letterSpacing: 0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: DS.br(CardRadius.pill),
          child: LinearProgressIndicator(
            value: limit <= 0 ? 0 : (used / limit).clamp(0.0, 1.0),
            minHeight: DS.s(6),
            backgroundColor: p.page,
            valueColor: AlwaysStoppedAnimation(p.g2),
          ),
        ),
        Gap.v(10),
        Row(children: [
          Expanded(
            child: Text(
              full && _formOpen ? TaxiGateStrings.lineFree(limit, TaxiGateStrings.plusRoutes) : TaxiSetupStrings.savedLine(used, limit, free: free),
              key: const ValueKey('routes_meter_line'),
              style: FieldMessage.helperStyle.copyWith(fontSize: DS.f(12)),
            ),
          ),
          if (full && _formOpen) ...[Gap.h(8), SeePlusButton(taxi: true, onPressed: () => PlanGate.showLimit(context, TaxiGateStrings.routeGate()))],
        ]),
      ]),
    );
  }

  Widget _tipRow() {
    if (!PlanGate.canUpgrade || !_planFull || _formOpen) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(20), DS.s(18), 0),
      child: KeyedSubtree(
        key: GateKeys.softCard,
        child: SoftLock.row(
          text: TaxiGateStrings.freePlanTip(_planMax, TaxiGateStrings.plusRoutes),
          taxi: true,
          onTap: () => PlanGate.showLimit(context, TaxiGateStrings.routeGate()),
        ),
      ),
    );
  }

  Widget _addRow() {
    final n = _count;
    final enabled = n < _max;
    final soft = PlanGate.canUpgrade && _planFull && !_formOpen;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: KeyedSubtree(
        key: soft ? const ValueKey('routes_add_locked') : null,
        child: DashedAddRow3D(
          tone: _tone,
          label: TaxiGateStrings.addAnother,
          margin: EdgeInsets.only(top: DS.gv(10)),
          trailing: !enabled ? 'Limit reached' : (soft ? TaxiSetupStrings.plus : '$n of $_planMax'),
          onTap: _addAnother,
        ),
      ),
    );
  }
}

extension on Widget {
  Widget withTopGap(double gap) => gap == 0 ? this : Padding(padding: EdgeInsets.only(top: DS.gv(gap)), child: this);
}
