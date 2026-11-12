import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../design/extra/taxi_setup_kit.dart';
import '../../../design/extra/trip_plan_look.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/location_switch_sheet.dart';
import '../../trip/trip_strings_a3.dart';
import '../guest/v2/taxi_rate_strings.dart';
import '../taxi_option_sets.dart';
import 'taxi_rate_rules.dart';
import 'taxi_setup_controller.dart';

class _Place {
  final String name;
  final String? label;
  final double lat;
  final double lng;
  const _Place({required this.name, this.label, required this.lat, required this.lng});

  factory _Place.fromPicked(PickedPlace p) => _Place(
        name: _cut(p.name.trim(), 80),
        label: p.districtName.trim().isNotEmpty ? _cut(p.districtName.trim(), 160) : null,
        lat: p.latitude,
        lng: p.longitude,
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

  String get key => '${from.lat.toStringAsFixed(3)}|${from.lng.toStringAsFixed(3)}|'
      '${to.lat.toStringAsFixed(3)}|${to.lng.toStringAsFixed(3)}|$tripType';
}

class TaxiRoutesScreen extends StatefulWidget {
  const TaxiRoutesScreen({super.key});
  @override
  State<TaxiRoutesScreen> createState() => _TaxiRoutesScreenState();
}

class _TaxiRoutesScreenState extends State<TaxiRoutesScreen> with TickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    for (final r in _ctrl.taxi.value?.routes ?? const []) {
      _routes.add(_RouteDraft(
        id: r.id,
        from: _Place(name: r.fromName, label: r.fromLabel, lat: r.fromLatitude, lng: r.fromLongitude),
        to: _Place(name: r.toName, label: r.toLabel, lat: r.toLatitude, lng: r.toLongitude),
        fare: r.fare,
        tripType: r.tripType,
      ));
    }
    _formOpen = _routes.length < _max;
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
    final t = _ctrl.taxi.value;
    final lat = t?.latitude, lng = t?.longitude;
    final name = t?.locality ?? '';
    if (t == null || lat == null || lng == null || name.isEmpty) return null;
    final label = t.baseLabel;
    return _Place(name: name, label: label.isNotEmpty && label != name ? label : null, lat: lat, lng: lng);
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
      final picked = await LocationSwitchSheet.pick(context,
          palette: templateModulePalette, title: isFrom ? 'From city' : 'To city');
      if (picked == null || !mounted) return;
      setState(() {
        if (isFrom) {
          _from = _Place.fromPicked(picked);
        } else {
          _to = _Place.fromPicked(picked);
        }
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
      return false;
    }
    if (to == null) {
      AppToast.error('Pick a To place');
      return false;
    }
    if (TaxiOptionSets.distanceMeters(from.lat, from.lng, to.lat, to.lng) < TaxiOptionSets.minEndpointDistanceMeters) {
      AppToast.error('From and To must be different places');
      return false;
    }
    final fareText = _fareCtrl.text.trim();
    if (fareText.isEmpty) {
      AppToast.error('Enter the fare');
      _fareFocusNode.requestFocus();
      return false;
    }
    final fare = int.tryParse(fareText) ?? 0;
    if (fare < TaxiOptionSets.minFare || fare > TaxiOptionSets.maxFare) {
      AppToast.error('Fare must be between ₹100 and ₹99,00,000');
      _fareFocusNode.requestFocus();
      return false;
    }
    if (_tripType == null) {
      AppToast.error('Pick One way or Round trip');
      return false;
    }
    final draft = _RouteDraft(id: _editingId, from: from, to: to, fare: fare, tripType: _tripType!);
    if (_routes.any((r) => r.key == draft.key)) {
      AppToast.error('This route is already added');
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
    });
    return true;
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
      return;
    }
    final rateError = _rateEditable ? TaxiRateRules.validate(_rateCtrl.text, _kmCtrl.text) : null;
    if (rateError != null) {
      AppToast.error(rateError);
      return;
    }
    if (rateDirty && !await _persistRate(quiet: _routes.isNotEmpty)) return;
    if (!mounted) return;
    if (_routes.isEmpty) {
      Get.back();
      return;
    }
    final ok = await _ctrl.saveRoutes([
      for (final r in _routes)
        {
          'id': r.id,
          'fromName': r.from.name,
          'fromLabel': r.from.label,
          'fromLatitude': r.from.lat,
          'fromLongitude': r.from.lng,
          'toName': r.to.name,
          'toLabel': r.to.label,
          'toLatitude': r.to.lat,
          'toLongitude': r.to.lng,
          'fare': r.fare,
          'tripType': r.tripType,
        },
    ]);
    if (!ok || !mounted) return;
    Get.back();
    AppToast.success('Routes saved');
  }

  Future<void> _confirmDiscard() async {
    final ok = await showTaxiDialog(
      context,
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
          backgroundColor: FitnessAppTheme.background,
          body: Column(children: [
            ModuleHeader(
              title: 'Routes and fares',
              tone: KitTone.taxi,
              onBack: _onBack,
              leadingAsset: TravelIcon.route,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(KitMetrics.gutter),
                children: [
                  SetupEntrance(controller: _anim, index: 0, count: 4, child: _localRateCard()),
                  SetupEntrance(
                    controller: _anim,
                    index: 1,
                    count: 4,
                    child: Column(children: [for (var i = 0; i < _routes.length; i++) _summaryCard(i)]),
                  ),
                  SetupEntrance(
                    controller: _anim,
                    index: 2,
                    count: 4,
                    child: Column(children: [if (_formOpen) _form()]),
                  ),
                  SetupEntrance(controller: _anim, index: 3, count: 4, child: _addRow()),
                ],
              ),
            ),
            _footer(),
          ]),
        ),
        Obx(() => _ctrl.isSaving.value
            ? SetupBusy(message: _savingRate ? 'Saving rate...' : 'Saving routes...')
            : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _summaryCard(int i) {
    final r = _routes[i];
    final text = '${r.from.name} to ${r.to.name} · ${BrowseItem.inr(r.fare)} · ${TaxiOptionSets.tripLabel(r.tripType)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: TripKit.cardRadiusSmall,
        boxShadow: PickKit.greyShadow(),
      ),
      child: Row(children: [
        Expanded(
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TripKit.text(12.5)),
        ),
        const SizedBox(width: 6),
        _squareAction(Icons.edit_outlined, FitnessAppTheme.nearlyDarkBlue, PickKit.taxiTint, () => _editRoute(i)),
        _squareAction(Icons.close_rounded, TripLook.error, PickKit.badTint, () => _removeRoute(i)),
      ]),
    );
  }

  Widget _squareAction(IconData icon, Color color, Color tint, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: color),
            ),
          ),
        ),
      );

  Widget _label(String text, {bool first = false}) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 14, bottom: 8),
        child: Text(text, style: SetupKit.label()),
      );

  Widget _placeRow({required String asset, required _Place? place, required String placeholder, required VoidCallback onTap}) =>
      Material(
        color: FitnessAppTheme.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              Image.asset(asset, width: 24, height: 24),
              const SizedBox(width: 10),
              Expanded(
                child: place == null
                    ? Text(placeholder, style: TripKit.text(14, color: FitnessAppTheme.deactivatedText))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TripKit.text(14)),
                        if (place.label != null && place.label!.isNotEmpty)
                          Text(place.label!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TripKit.text(11, color: FitnessAppTheme.lightText)),
                      ]),
              ),
              const SizedBox(width: 8),
              Image.asset(TravelIcon.pin, width: 20, height: 20),
            ]),
          ),
        ),
      );

  Widget _form() {
    final number = (_editingIndex ?? _routes.length) + 1;
    return SetupCard(
      title: 'Route $number',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('From *', first: true),
        _placeRow(asset: TravelIcon.place, place: _from, placeholder: 'Search a place', onTap: () => _pickPlace(true)),
        _label('To *'),
        _placeRow(asset: TravelIcon.map, place: _to, placeholder: 'Search a place', onTap: () => _pickPlace(false)),
        _label('Fare (₹) *'),
        TextFormField(
          controller: _fareCtrl,
          focusNode: _fareFocusNode,
          cursorColor: FitnessAppTheme.nearlyDarkBlue,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          onChanged: (_) => _dirty = true,
          style: SetupKit.fieldText(),
          decoration: SetupKit.input(hint: 'e.g. 4500', prefix: '₹ '),
        ),
        _label('Trip *'),
        Row(children: [
          for (var i = 0; i < TaxiOptionSets.tripTypes.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: PickChip(
                label: TaxiOptionSets.tripTypes[i].label,
                selected: _tripType == TaxiOptionSets.tripTypes[i].value,
                activeColor: PickKit.taxi,
                onTap: () => setState(() {
                  _tripType = TaxiOptionSets.tripTypes[i].value;
                  _dirty = true;
                }),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _localRateCard() {
    final editable = _rateEditable;
    return SetupCard(
      title: 'Local sightseeing',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(TaxiRateStrings.neededToList, style: TripKit.text(12, color: FitnessAppTheme.lightText)),
        _label(TripStringsA3.driverRateLabel),
        TextFormField(
          controller: _rateCtrl,
          readOnly: !editable,
          cursorColor: FitnessAppTheme.nearlyDarkBlue,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          onChanged: (_) => setState(() {}),
          style: SetupKit.fieldText(),
          decoration: SetupKit.input(hint: 'e.g. 2500', prefix: '₹ '),
        ),
        _label(TaxiRateStrings.kmLabel),
        TextFormField(
          controller: _kmCtrl,
          readOnly: !editable,
          cursorColor: FitnessAppTheme.nearlyDarkBlue,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          onChanged: (_) => setState(() {}),
          style: SetupKit.fieldText(),
          decoration: SetupKit.input(
              hint: 'e.g. 120',
              suffix: Text('km', style: TripKit.text(13, color: FitnessAppTheme.lightText))),
        ),
        const SizedBox(height: 12),
        Text('Travellers see this rate. You can quote a different fare for a trip after you read the itinerary.',
            style: TripKit.text(12, color: FitnessAppTheme.grey).copyWith(height: 1.4)),
      ]),
    );
  }

  Widget _addRow() {
    final n = _count;
    final enabled = n < _max;
    return PressScale(
      child: Container(
        decoration: BoxDecoration(
            color: FitnessAppTheme.white, borderRadius: TripKit.cardRadiusSmall, boxShadow: PickKit.greyShadow()),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _addAnother,
            borderRadius: TripKit.cardRadiusSmall,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: enabled ? PickKit.taxiGradient : null,
                      color: enabled ? null : FitnessAppTheme.deactivatedText,
                      boxShadow: enabled ? PickKit.shadow(PickKit.taxiDark) : const [],
                    ),
                    child: const Icon(Icons.add_rounded, size: 20, color: FitnessAppTheme.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Add another route',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TripKit.text(14, color: enabled ? FitnessAppTheme.nearlyDarkBlue : DesignColors.textDisabled).copyWith(letterSpacing: 0.2)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(enabled ? '$n of $_max' : 'Limit reached',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TripKit.text(11, color: FitnessAppTheme.lightText)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() => SetupFooter(
        child: Obx(() => PickButton(
              onPressed: _ctrl.isSaving.value ? null : _save,
              isLoading: _ctrl.isSaving.value,
              label: 'Save',
              gradient: PickKit.taxiGradient,
              shadowColor: PickKit.taxiDark,
            )),
      );
}
