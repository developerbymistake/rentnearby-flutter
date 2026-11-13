import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_stay_owner.dart';
import '../../../utils/app_toast.dart';
import 'stay_option_sets.dart';
import 'stay_setup_controller.dart';

class StayRulesScreen extends StatefulWidget {
  const StayRulesScreen({super.key});
  @override
  State<StayRulesScreen> createState() => _StayRulesScreenState();
}

class _StayRulesScreenState extends State<StayRulesScreen> {
  final _ctrl = StaySetupController.ensure();
  TimeOfDay _checkIn = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _checkOut = const TimeOfDay(hour: 11, minute: 0);
  bool _pets = false;
  bool _smoking = false;
  bool _alcohol = false;
  bool _couples = false;
  bool _idProof = false;
  String? _cancellation;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final r = _ctrl.stay.value?.rules;
    if (r != null) {
      _checkIn = _parse(r.checkInTime, _checkIn);
      _checkOut = _parse(r.checkOutTime, _checkOut);
      _pets = r.petsAllowed;
      _smoking = r.smokingAllowed;
      _alcohol = r.alcoholAllowed;
      _couples = r.unmarriedCouplesAllowed;
      _idProof = r.idProofRequired;
      _cancellation = r.cancellationPolicy;
    }
  }

  static TimeOfDay _parse(String hhmm, TimeOfDay fallback) {
    final p = hhmm.split(':');
    final h = int.tryParse(p.first);
    final m = p.length > 1 ? int.tryParse(p[1]) : null;
    return h == null || m == null ? fallback : TimeOfDay(hour: h, minute: m);
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool checkIn) async {
    final picked = await TemplateTimePopup.pick(
      context,
      initial: checkIn ? _checkIn : _checkOut,
      label: checkIn ? 'Check-in time' : 'Check-out time',
      tone: KitTone.stay,
      art: ListingArt.key,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (checkIn) {
        _checkIn = picked;
      } else {
        _checkOut = picked;
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_cancellation == null) {
      AppToast.error('Please select a cancellation policy');
      return;
    }
    final ok = await _ctrl.saveRules({
      'checkInTime': _hhmm(_checkIn),
      'checkOutTime': _hhmm(_checkOut),
      'petsAllowed': _pets,
      'smokingAllowed': _smoking,
      'alcoholAllowed': _alcohol,
      'unmarriedCouplesAllowed': _couples,
      'idProofRequired': _idProof,
      'cancellationPolicy': _cancellation,
    });
    if (!ok || !mounted) return;
    Get.back();
    AppToast.success('Rules saved');
  }

  void _onBack() {
    if (_ctrl.isSaving.value) return;
    if (!_dirty) {
      Get.back();
      return;
    }
    showDialog(
      context: context,
      builder: (_) => StayConfirmDialog(
        title: 'Discard changes?',
        body: 'Unsaved changes will be lost.',
        cancelLabel: 'Keep Editing',
        confirmLabel: 'Discard',
        destructive: true,
        art: ListingArt.clipboard,
        onCancel: () => Navigator.pop(context),
        onConfirm: () {
          Navigator.pop(context);
          Get.back();
        },
      ),
    );
  }

  static final _tone = ListingTone.forest;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Stack(children: [
        Scaffold(
          backgroundColor: ListingPalette.forest.page,
          body: Column(children: [
            StayPageHeader(title: 'Rules', onBack: _onBack, asset: SetupAssets.clipboard),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  FormSectionCard(
                    tone: _tone,
                    art: ListingArt.key,
                    title: 'Check-in and Check-out',
                    tag: 'Required',
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _timeField('Check-in', _checkIn, () => _pickTime(true))),
                      const SizedBox(width: 12),
                      Expanded(child: _timeField('Check-out', _checkOut, () => _pickTime(false))),
                    ]),
                  ),
                  FormSectionCard(
                    tone: _tone,
                    art: ListingArt.clipboard,
                    title: 'House Rules',
                    tag: 'Required',
                    child: Column(children: [
                      _switchRow('Pets allowed', ListingArt.paw, _pets, (v) => _pets = v),
                      _switchRow('Smoking allowed', ListingArt.camping, _smoking, (v) => _smoking = v),
                      _switchRow('Alcohol allowed', ListingArt.star, _alcohol, (v) => _alcohol = v),
                      _switchRow('Unmarried couples allowed', ListingArt.key, _couples, (v) => _couples = v),
                      _switchRow('ID proof required', ListingArt.clipboard, _idProof, (v) => _idProof = v),
                    ]),
                  ),
                  FormSectionCard(
                    tone: _tone,
                    art: ListingArt.calendar,
                    title: 'Cancellation',
                    tag: 'Required',
                    child: OptionTileGrid(
                      tone: _tone,
                      items: [
                        for (final o in StayOptionSets.cancellation) OptionTileItem(label: o.label, art: StayOwnerArt.cancellation[o.value] ?? ListingArt.star),
                      ],
                      isSelected: (i) => _cancellation == StayOptionSets.cancellation[i].value,
                      onTap: (i) => setState(() {
                        _cancellation = StayOptionSets.cancellation[i].value;
                        _dirty = true;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          bottomNavigationBar: Obx(() => FormFooter(
                tone: _tone,
                primaryLabel: 'Save',
                onPrimary: _ctrl.isSaving.value ? null : _save,
                primaryLoading: _ctrl.isSaving.value,
              )),
        ),
        Obx(() => _ctrl.isSaving.value ? const StayBusy(message: 'Saving rules...', art: SetupAssets.clipboard) : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _timeField(String label, TimeOfDay value, VoidCallback onTap) => PillPickerField(
        tone: _tone,
        label: label,
        value: StayOptionSets.time12(_hhmm(value)),
        leadingArt: ListingArt.key,
        trailing: const SizedBox.shrink(),
        onTap: onTap,
      );

  Widget _switchRow(String label, String art, bool value, void Function(bool) apply) => ToggleRow(
        tone: _tone,
        label: label,
        art: art,
        value: value,
        divider: true,
        onChanged: (v) => setState(() {
          apply(v);
          _dirty = true;
        }),
      );
}
