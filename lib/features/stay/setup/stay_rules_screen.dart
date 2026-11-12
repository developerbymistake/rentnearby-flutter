import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import 'stay_option_grid.dart';
import 'stay_option_sets.dart';
import 'stay_setup_controller.dart';

class StayRulesScreen extends StatefulWidget {
  const StayRulesScreen({super.key});
  @override
  State<StayRulesScreen> createState() => _StayRulesScreenState();
}

class _StayRulesScreenState extends State<StayRulesScreen> with TickerProviderStateMixin {
  final _ctrl = StaySetupController.ensure();
  late final AnimationController _anim = SetupKit.controller(this);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SetupKit.play(_anim, context);
    });
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

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
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
        onCancel: () => Navigator.pop(context),
        onConfirm: () {
          Navigator.pop(context);
          Get.back();
        },
      ),
    );
  }

  Widget _in(int i, Widget child) => SetupEntrance(controller: _anim, index: i, count: 4, child: child);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Stack(children: [
        Scaffold(
          backgroundColor: DesignColors.scaffold,
          body: Column(children: [
            StayPageHeader(
              title: 'Rules',
              onBack: _onBack,
              asset: SetupAssets.clipboard,
              animation: templateInterval(_anim, 0, 2),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _in(
                    0,
                    SectionTile(
 tone: KitTone.stay,
 margin: const EdgeInsets.only(bottom: 16),
                      title: 'Check-in and Check-out',
                      child: Row(children: [
                        Expanded(child: _timeField('Check-in', _checkIn, () => _pickTime(true))),
                        const SizedBox(width: 10),
                        Expanded(child: _timeField('Check-out', _checkOut, () => _pickTime(false))),
                      ]),
                    ),
                  ),
                  _in(
                    1,
                    SectionTile(
 tone: KitTone.stay,
 margin: const EdgeInsets.only(bottom: 16),
                      title: 'House Rules',
                      child: Column(children: [
                        _switchRow('Pets allowed', _pets, (v) => _pets = v),
                        _switchRow('Smoking allowed', _smoking, (v) => _smoking = v),
                        _switchRow('Alcohol allowed', _alcohol, (v) => _alcohol = v),
                        _switchRow('Unmarried couples allowed', _couples, (v) => _couples = v),
                        _switchRow('ID proof required', _idProof, (v) => _idProof = v, last: true),
                      ]),
                    ),
                  ),
                  _in(
                    2,
                    SectionTile(
 tone: KitTone.stay,
 margin: const EdgeInsets.only(bottom: 16),
                      title: 'Cancellation *',
                      child: StayOptionGrid(
                        crossAxisCount: 3,
                        childAspectRatio: 2.6,
                        labels: StayOptionSets.cancellation.map((o) => o.label).toList(),
                        accent: PickKit.stay,
                        isActive: (i) => _cancellation == StayOptionSets.cancellation[i].value,
                        onTap: (i) => setState(() {
                          _cancellation = StayOptionSets.cancellation[i].value;
                          _dirty = true;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _in(
              3,
              StayFooter(
                child: Obx(() => PrimaryButton(
 tone: KitTone.stay,
                      onPressed: _ctrl.isSaving.value ? null : _save,
                      loading: _ctrl.isSaving.value,
                      label: 'Save',
                    )),
              ),
            ),
          ]),
        ),
        Obx(() => _ctrl.isSaving.value ? const StayBusy(message: 'Saving rules...') : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _timeField(String label, TimeOfDay value, VoidCallback onTap) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: SetupKit.label()),
          const SizedBox(height: 6),
          Material(
            color: DesignColors.scaffold,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Row(children: [
                  Image.asset(SetupAssets.key, width: 20, height: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(StayOptionSets.time12(_hhmm(value)), maxLines: 1, style: SetupKit.fieldText()),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      );

  Widget _switchRow(String label, bool value, void Function(bool) apply, {bool last = false}) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Text(label, style: TripKit.text(14))),
              SetupSwitch(
                value: value,
                onChanged: (v) => setState(() {
                  apply(v);
                  _dirty = true;
                }),
              ),
            ]),
          ),
          if (!last) const Divider(height: 1, color: DesignColors.dividerSoft),
        ],
      );
}
