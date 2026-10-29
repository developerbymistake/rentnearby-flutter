import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../controllers/location_controller.dart';
import '../../../models/browse_item.dart';
import '../../../models/place_result_model.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/location_search_sheet.dart';
import '../../stay/setup/dashed_add_row.dart';
import '../../stay/setup/stay_option_grid.dart';
import '../taxi_option_sets.dart';
import 'taxi_setup_controller.dart';

class _Place {
  final String name;
  final String? label;
  final double lat;
  final double lng;
  const _Place({required this.name, this.label, required this.lat, required this.lng});

  factory _Place.fromResult(PlaceResult p) => _Place(
        name: _cut(p.name.trim().isNotEmpty ? p.name.trim() : p.subtitle.trim(), 80),
        label: p.subtitle.trim().isNotEmpty ? _cut(p.subtitle.trim(), 160) : null,
        lat: p.latLng.latitude,
        lng: p.latLng.longitude,
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

class _TaxiRoutesScreenState extends State<TaxiRoutesScreen> {
  final _ctrl = TaxiSetupController.ensure();
  final _fareCtrl = TextEditingController();
  final _fareFocusNode = FocusNode();
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
  }

  @override
  void dispose() {
    _fareCtrl.dispose();
    _fareFocusNode.dispose();
    super.dispose();
  }

  int get _count => _routes.length + (_formOpen ? 1 : 0);

  bool get _fromIsDefault {
    final from = _from;
    if (from == null) return true;
    final d = _defaultFrom;
    return d != null && d.name == from.name && d.lat == from.lat && d.lng == from.lng;
  }

  bool get _formBlank => _fromIsDefault && _to == null && _fareCtrl.text.trim().isEmpty && _tripType == null;

  LatLng get _bias {
    final t = _ctrl.taxi.value;
    if (t?.latitude != null && t?.longitude != null) return LatLng(t!.latitude!, t.longitude!);
    return Get.find<LocationController>().effectiveSearchCenter;
  }

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
      final picked = await LocationSearchSheet.show(context, bias: _bias, palette: TaxiColors.palette);
      if (picked == null || !mounted) return;
      setState(() {
        if (isFrom) {
          _from = _Place.fromResult(picked);
        } else {
          _to = _Place.fromResult(picked);
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
    if (_ctrl.isSaving.value) return;
    FocusScope.of(context).unfocus();
    if (!_commitForm()) return;
    if (_routes.isEmpty) {
      AppToast.error('Add at least one route');
      setState(() => _formOpen = true);
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

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard changes?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark)),
        content: const Text('Unsaved changes will be lost.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Editing',
                style: TextStyle(fontFamily: 'Poppins', color: TaxiColors.accentDark, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Get.back();
            },
            child: const Text('Discard', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _onBack() {
    if (_ctrl.isSaving.value) return;
    if (_dirty || !_formBlank) {
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
          backgroundColor: AppColors.scaffoldBg,
          body: Column(children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (var i = 0; i < _routes.length; i++) _summaryCard(i),
                  if (_formOpen) _form(),
                  _addRow(),
                ],
              ),
            ),
            _footer(),
          ]),
        ),
        Obx(() => _ctrl.isSaving.value
            ? AppLoadingOverlay.stackChild(message: 'Saving routes...', indicatorColor: TaxiColors.accent)
            : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _header() => Container(
        decoration: const BoxDecoration(gradient: TaxiColors.gradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
            child: Row(children: [
              IconButton(onPressed: _onBack, icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white)),
              const Text('Routes and fares',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            ]),
          ),
        ),
      );

  Widget _summaryCard(int i) {
    final r = _routes[i];
    final text = '${r.from.name} to ${r.to.name} · ${BrowseItem.inr(r.fare)} · ${TaxiOptionSets.tripLabel(r.tripType)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textDark)),
        ),
        const SizedBox(width: 6),
        _squareAction(Iconsax.edit_2, TaxiColors.accentDark, () => _editRoute(i)),
        _squareAction(Iconsax.close_circle, AppColors.error, () => _removeRoute(i)),
      ]),
    );
  }

  Widget _squareAction(IconData icon, Color color, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: color),
            ),
          ),
        ),
      );

  Widget _label(String text, {bool first = false}) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 14, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
      );

  Widget _placeRow({required IconData icon, required _Place? place, required String placeholder, required VoidCallback onTap}) =>
      Material(
        color: TaxiColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(children: [
              Icon(icon, size: 18, color: TaxiColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: place == null
                    ? Text(placeholder,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark)),
                        if (place.label != null && place.label!.isNotEmpty)
                          Text(place.label!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                      ]),
              ),
              const SizedBox(width: 8),
              const Icon(Iconsax.gps, size: 18, color: TaxiColors.accentDark),
            ]),
          ),
        ),
      );

  Widget _form() {
    final number = (_editingIndex ?? _routes.length) + 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Route $number',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 10),
        _label('From *', first: true),
        _placeRow(icon: Iconsax.location, place: _from, placeholder: 'Search a place', onTap: () => _pickPlace(true)),
        _label('To *'),
        _placeRow(icon: Iconsax.search_normal, place: _to, placeholder: 'Search a place', onTap: () => _pickPlace(false)),
        _label('Fare (₹) *'),
        TextFormField(
          controller: _fareCtrl,
          focusNode: _fareFocusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          onChanged: (_) => _dirty = true,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. 4500',
            hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
            prefixText: '₹ ',
            prefixStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500),
            filled: true,
            fillColor: TaxiColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TaxiColors.accent, width: 1.5)),
          ),
        ),
        _label('Trip *'),
        StayOptionGrid(
          crossAxisCount: 2,
          childAspectRatio: 3.9,
          labels: TaxiOptionSets.tripTypes.map((o) => o.label).toList(),
          isActive: (i) => _tripType == TaxiOptionSets.tripTypes[i].value,
          onTap: (i) => setState(() {
            _tripType = TaxiOptionSets.tripTypes[i].value;
            _dirty = true;
          }),
          accent: TaxiColors.accent,
        ),
      ]),
    );
  }

  Widget _addRow() {
    final n = _count;
    return DashedAddRow(
      label: 'Add another route',
      counter: n < _max ? '$n of $_max' : 'Limit reached',
      enabled: n < _max,
      onTap: _addAnother,
      accent: TaxiColors.accent,
    );
  }

  Widget _footer() => Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(20, 12, 20, AppInsets.bottomViewPadding(context) + 12),
        child: Obx(() => GradientButton(
              onPressed: _ctrl.isSaving.value ? null : _save,
              isLoading: _ctrl.isSaving.value,
              label: 'Save',
              gradient: TaxiColors.gradient,
              shadowColor: TaxiColors.accent,
            )),
      );
}
