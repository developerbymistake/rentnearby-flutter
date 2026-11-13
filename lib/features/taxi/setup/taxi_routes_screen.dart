import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
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
      _mark(_Ring.from);
      return false;
    }
    if (to == null) {
      AppToast.error('Pick a To place');
      _mark(_Ring.to);
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
                  title: 'Routes and fares',
                  art: ListingArt.compass,
                  inlineTitle: true,
                  onBack: _onBack,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
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
              ]),
            ),
          ),
          bottomNavigationBar: Obx(() => FormFooter(
                tone: _tone,
                top: const ToastDock(),
                primaryLabel: 'Save',
                primaryLoading: _ctrl.isSaving.value,
                onPrimary: _ctrl.isSaving.value ? null : _save,
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
      tag: '${r.from.name} to',
      title: r.to.name,
      subtitle: '${BrowseItem.inr(r.fare)} · ${TaxiOptionSets.tripLabel(r.tripType)}',
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
        hint: 'Search a place',
        leadingArt: asset,
        errorRing: ring,
        trailing: Image.asset(ListingArt.pushpin, width: 26, height: 26),
        onTap: onTap,
      ).withTopGap(first ? 0 : 14);

  Widget _form() {
    final number = (_editingIndex ?? _routes.length) + 1;
    return FormSectionCard(
      key: _formKey,
      tone: _tone,
      art: ListingArt.compass,
      artSide: FormArtSide.right,
      title: 'Route $number',
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
        Text(TaxiRateStrings.neededToList, style: FieldMessage.helperStyle.copyWith(fontSize: 12.5)),
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
          padding: const EdgeInsets.only(top: 12),
          child: Text('Travellers see this rate. You can quote a different fare for a trip after you read the itinerary.',
              style: FieldMessage.helperStyle.copyWith(fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _addRow() {
    final n = _count;
    final enabled = n < _max;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: DashedAddRow3D(
        tone: _tone,
        label: 'Add another route',
        trailing: enabled ? '$n of $_max' : 'Limit reached',
        onTap: _addAnother,
      ),
    );
  }
}

extension on Widget {
  Widget withTopGap(double gap) => gap == 0 ? this : Padding(padding: EdgeInsets.only(top: gap), child: this);
}
