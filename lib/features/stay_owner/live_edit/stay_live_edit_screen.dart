import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/onboarding_closed_dialog.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/sheets/owner_sheet.dart';
import '../../stay/models/stay_owner_model.dart';
import '../../stay/models/stay_registration_type_model.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../../stay/setup/stay_page_header.dart';
import '../../stay/setup/stay_registration_validators.dart';
import '../../stay/setup/stay_setup_controller.dart';
import '../../stay/stay_registration_types_controller.dart';
import '../../stay/stay_types_controller.dart';
import '../hub/stay_hub_controller.dart';
import '../stay_owner_deps.dart';
import '../strings/stay_live_edit_strings.dart';
import '../strings/stay_setup_strings.dart';
import '../widgets/stay_widgets.dart';
import '../../owner_core/sheets/sheet_disposables.dart';

class StayLiveEditScreen extends StatefulWidget {
  const StayLiveEditScreen({super.key, this.setup});

  final StaySetupController? setup;

  @override
  State<StayLiveEditScreen> createState() => _StayLiveEditScreenState();
}

class _StayLiveEditScreenState extends State<StayLiveEditScreen> {
  late final StaySetupController _ctrl = widget.setup ?? StaySetupController.ensure();
  final _types = StayTypesController.ensure();
  final _regTypes = StayRegistrationTypesController.ensure();
  static final _tone = ListingTone.forest;

  String? _name;
  String? _typeId;
  Set<String>? _facilities;
  String? _regTypeId;
  String? _regOther;
  String? _regNumber;
  String? _gstin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _types.ensureLoaded();
    _regTypes.ensureLoaded();
    final s = _ctrl.stay.value;
    if (s == null || !s.isApproved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Get.back();
      });
    }
  }

  bool get _dirty => _name != null || _typeId != null || _facilities != null || _regTypeId != null || _regOther != null || _regNumber != null || _gstin != null;

  Future<void> _back() async {
    if (_saving) return;
    if (!_dirty || await OwnerConfirm.discard(context)) Get.back();
  }

  String _typeName(StayOwnerModel s) {
    final id = _typeId ?? s.stayTypeId;
    for (final t in _types.types) {
      if (t.id == id) return t.name;
    }
    return s.stayTypeName ?? '';
  }

  String _facilityText(StayOwnerModel s) {
    final set = _facilities ?? s.facilities.toSet();
    return [for (final o in StayOptionSets.facilities) if (set.contains(o.value)) o.label].join(', ');
  }

  Future<void> _editName(StayOwnerModel s) async {
    final v = await _textSheet(StayLiveEditStrings.stayName, _name ?? s.name ?? '', (t) => t.trim().length < 2 || t.trim().length > 80 ? StayLiveEditStrings.nameRule : null);
    if (v != null && mounted) setState(() => _name = v == s.name ? null : v);
  }

  Future<String?> _textSheet(String title, String initial, String? Function(String) check) {
    final ctrl = TextEditingController(text: initial);
    final err = ValueNotifier<String?>(null);
    return OwnerSheet.show<String>(
      context,
      look: OwnerLook.stay,
      title: title,
      child: (c) => SheetDisposables(notifiers: [ctrl, err], child: ValueListenableBuilder<String?>(
        valueListenable: err,
        builder: (_, e, _) => Padding(
          padding: EdgeInsets.only(top: DS.gv(6)),
          child: PillField(tone: _tone, controller: ctrl, autofocus: true, inputFormatters: noEmojiInputFormatters, errorText: e),
        ),
      )),
      footer: (c) => GradientPillButton(
        tone: _tone,
        label: StayLiveEditStrings.done,
        onTap: () {
          final e = check(ctrl.text);
          if (e != null) {
            err.value = e;
            return;
          }
          Navigator.of(c).pop(ctrl.text.trim());
        },
      ),
    );
  }

  Future<void> _editType(StayOwnerModel s) async {
    final picked = await Sheet3D.show<String>(
      context,
      builder: (sc) => Sheet3D(
        tone: _tone,
        art: ListingArt.stay,
        title: StayLiveEditStrings.stayType,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _types.types.length; i++)
              SheetListRow(tone: _tone, compact: true, title: _types.types[i].name, selected: _types.types[i].id == (_typeId ?? s.stayTypeId), divider: i > 0, onTap: () => Navigator.pop(sc, _types.types[i].id)),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _typeId = picked == s.stayTypeId ? null : picked);
  }

  Future<void> _editFacilities(StayOwnerModel s) async {
    final set = {...(_facilities ?? s.facilities.toSet())};
    final ok = await Sheet3D.show<bool>(
      context,
      builder: (sc) => StatefulBuilder(
        builder: (c, set2) => Sheet3D(
          tone: _tone,
          art: ListingArt.stay,
          title: StayLiveEditStrings.facilities,
          padding: EdgeInsets.zero,
          footer: GradientPillButton(tone: _tone, label: StayLiveEditStrings.done, onTap: () => Navigator.pop(sc, true)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < StayOptionSets.facilities.length; i++)
                SheetListRow(
                  tone: _tone,
                  compact: true,
                  title: StayOptionSets.facilities[i].label,
                  selected: set.contains(StayOptionSets.facilities[i].value),
                  divider: i > 0,
                  onTap: () => set2(() {
                    final v = StayOptionSets.facilities[i].value;
                    set.contains(v) ? set.remove(v) : set.add(v);
                  }),
                ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) setState(() => _facilities = setEquals(set, s.facilities.toSet()) ? null : set);
  }

  bool setEquals(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  Future<void> _editRegistration(StayOwnerModel s) async {
    final types = _regTypes.types;
    String? typeId = _regTypeId ?? s.registrationTypeId;
    final other = TextEditingController(text: _regOther ?? s.registrationOtherName ?? '');
    final number = TextEditingController(text: _regNumber ?? '');
    final gstin = TextEditingController(text: _gstin ?? '');
    StayRegistrationTypeModel? typeOf(String? id) {
      for (final t in types) {
        if (t.id == id) return t;
      }
      return null;
    }

    final ok = await OwnerSheet.show<bool>(
      context,
      look: OwnerLook.stay,
      title: StayLiveEditStrings.registrationNumber,
      child: (c) => SheetDisposables(notifiers: [other, number, gstin], child: StatefulBuilder(
        builder: (c, set) {
          final t = typeOf(typeId);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap.v(6),
              PillPickerField(
                tone: _tone,
                label: StayLiveEditStrings.registrationType,
                value: t?.name ?? s.registrationTypeName,
                hint: StayLiveEditStrings.select,
                onTap: () async {
                  final id = await Sheet3D.show<String>(
                    c,
                    builder: (sc) => Sheet3D(
                      tone: _tone,
                      title: StayLiveEditStrings.registrationType,
                      padding: EdgeInsets.zero,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (var i = 0; i < types.length; i++) SheetListRow(tone: _tone, compact: true, title: types[i].name, selected: types[i].id == typeId, divider: i > 0, onTap: () => Navigator.pop(sc, types[i].id)),
                      ]),
                    ),
                  );
                  if (id != null) set(() => typeId = id);
                },
              ),
              if (t?.requiresOtherName ?? false) PillField(tone: _tone, label: StayLiveEditStrings.documentName, controller: other, inputFormatters: noEmojiInputFormatters),
              PillField(tone: _tone, label: StayLiveEditStrings.registrationNumber, controller: number, hint: StayLiveEditStrings.keepNumberHint, inputFormatters: noEmojiInputFormatters),
              PillField(tone: _tone, label: StayLiveEditStrings.gstin, controller: gstin, inputFormatters: noEmojiInputFormatters),
            ],
          );
        },
      )),
      footer: (c) => GradientPillButton(
        tone: _tone,
        label: StayLiveEditStrings.done,
        onTap: () {
          final t = typeOf(typeId);
          final n = number.text.trim();
          if (n.isNotEmpty && t != null) {
            final norm = StayRegistrationValidators.normalizeForType(t.code, n);
            if (!StayRegistrationValidators.isValidForType(t.code, norm)) {
              AppToast.error(StayRegistrationValidators.messageForType(t.code));
              return;
            }
          }
          final g = gstin.text.trim();
          if (g.isNotEmpty && !StayRegistrationValidators.isValidGstin(StayRegistrationValidators.normalizeGstin(g))) {
            AppToast.error(StayRegistrationValidators.gstinInvalidMessage);
            return;
          }
          Navigator.of(c).pop(true);
        },
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        _regTypeId = typeId == s.registrationTypeId ? null : typeId;
        _regOther = other.text.trim().isEmpty ? null : other.text.trim();
        _regNumber = number.text.trim().isEmpty ? null : number.text.trim();
        _gstin = gstin.text.trim().isEmpty ? null : gstin.text.trim();
      });
    }
  }

  Future<void> _editLocation() async {
    await Get.toNamed(AppRoutes.stayBasicDetails, arguments: const {'section': 'location'});
    if (mounted) _ctrl.load();
  }

  Future<void> _save(StayOwnerModel s) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final t = [for (final x in _regTypes.types) if (x.id == (_regTypeId ?? s.registrationTypeId)) x];
      final type = t.isEmpty ? null : t.first;
      final ok = await _ctrl.saveBasic({
        'name': _name ?? s.name,
        'stayTypeId': _typeId ?? s.stayTypeId,
        'registrationTypeId': _regTypeId ?? s.registrationTypeId,
        'registrationOtherName': type != null && type.requiresOtherName ? StayRegistrationValidators.normalizeOtherName(_regOther ?? s.registrationOtherName) : null,
        'registrationNumber': _regNumber == null || type == null ? null : StayRegistrationValidators.normalizeForType(type.code, _regNumber),
        'gstin': _gstin == null ? null : StayRegistrationValidators.normalizeGstin(_gstin),
        'vehicleAccess': s.vehicleAccess,
        'hostLivesHere': s.hostLivesHere,
        'facilities': (_facilities ?? s.facilities.toSet()).toList(),
        'description': s.description,
        'latitude': s.latitude,
        'longitude': s.longitude,
        'address': s.address,
        'districtId': s.districtId,
        'cityId': s.cityId,
      });
      if (!mounted) return;
      if (!ok) {
        if (_ctrl.lastErrorType == 'OnboardingClosed' || _ctrl.lastErrorType == 'StayOutsideDistrict') {
          OnboardingClosedDialog.show(context, body: StaySetupStrings.notOpenBodyFor(_ctrl.lastErrorType, _ctrl.lastErrorMessage));
        }
        return;
      }
      StayHubController.maybe?.reload();
      StayOwnerDeps.refreshHome();
      AppToast.success(StayLiveEditStrings.saved);
      Get.back();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: ListingPalette.forest.page,
        body: Column(
          children: [
            StayPageHeader(title: StayLiveEditStrings.title, subtitle: StayLiveEditStrings.subtitle, onBack: _back, asset: SetupAssets.hotel),
            Expanded(
              child: Obx(() {
                final s = _ctrl.stay.value;
                if (s == null) return const SizedBox.shrink();
                return SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: DS.s(24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const StayStrip(art: ListingArt.shield, text: StayLiveEditStrings.strip, fill: StayLook.amberSoft, ink: StayLook.amberText),
                      _field(StayLiveEditStrings.stayName, true, _name ?? s.name ?? '', () => _editName(s)),
                      _field(StayLiveEditStrings.stayType, false, _typeName(s), () => _editType(s)),
                      _field(StayLiveEditStrings.facilities, false, _facilityText(s), () => _editFacilities(s)),
                      _field(StayLiveEditStrings.registrationNumber, true, _regNumber ?? s.registrationNumber ?? StaySetupStrings.saved, () => _editRegistration(s)),
                      _field(StayLiveEditStrings.location, true, s.address ?? s.locality, _editLocation),
                      Padding(
                        padding: DS.insets(l: 18, t: 14, r: 18),
                        child: Text(StayLiveEditStrings.footer, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
        bottomNavigationBar: Obx(() {
          final s = _ctrl.stay.value;
          return StayFooter(
            child: GradientPillButton(tone: _tone, label: StayLiveEditStrings.saveChanges, loading: _saving, enabled: s != null && !_saving, onTap: s == null ? null : () => _save(s)),
          );
        }),
      ),
    );
  }

  Widget _field(String label, bool review, String value, VoidCallback onTap) => Padding(
        padding: DS.insets(l: 18, t: 16, r: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, Ink3D.body, letterSpacing: 0))),
                if (review) ...[
                  Gap.h(8),
                  DecoratedBox(
                    decoration: BoxDecoration(color: StayLook.amberSoft, borderRadius: DS.circular(8)),
                    child: Padding(padding: DS.sym(h: 7, v: 1), child: Text(StayLiveEditStrings.goesForReview, maxLines: 1, style: Ink3D.text(10, FontWeight.w700, StayLook.amberText, letterSpacing: 0))),
                  ),
                ],
              ],
            ),
            Gap.v(8),
            Semantics(
              button: true,
              label: '$label, $value',
              excludeSemantics: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: DS.circular(14),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(14), boxShadow: DS.shadows(Ink3D.softShadow)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: DS.s(48)),
                    child: Padding(
                      padding: DS.sym(h: 16, v: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                          Text(StayLiveEditStrings.chevron, style: Ink3D.text(20, FontWeight.w700, StayLook.indigoText, letterSpacing: 0)),
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
}
