import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/gradient_button.dart';
import 'stay_option_grid.dart';
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
    final picked = await showTimePicker(
      context: context,
      initialTime: checkIn ? _checkIn : _checkOut,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: StayColors.accentDark)),
        child: child!,
      ),
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
                style: TextStyle(fontFamily: 'Poppins', color: StayColors.accentDark, fontWeight: FontWeight.w600)),
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
            Container(
              decoration: const BoxDecoration(gradient: StayColors.gradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
                  child: Row(children: [
                    IconButton(onPressed: _onBack, icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white)),
                    const Text('Rules',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionCard(
                    title: 'Check-in and Check-out',
                    child: Row(children: [
                      Expanded(child: _timeField('Check-in', _checkIn, Iconsax.clock, () => _pickTime(true))),
                      const SizedBox(width: 10),
                      Expanded(child: _timeField('Check-out', _checkOut, Iconsax.clock, () => _pickTime(false))),
                    ]),
                  ),
                  _sectionCard(
                    title: 'House Rules',
                    child: Column(children: [
                      _switchRow('Pets allowed', _pets, (v) => _pets = v),
                      _switchRow('Smoking allowed', _smoking, (v) => _smoking = v),
                      _switchRow('Alcohol allowed', _alcohol, (v) => _alcohol = v),
                      _switchRow('Unmarried couples allowed', _couples, (v) => _couples = v),
                      _switchRow('ID proof required', _idProof, (v) => _idProof = v, last: true),
                    ]),
                  ),
                  _sectionCard(
                    title: 'Cancellation *',
                    child: StayOptionGrid(
                      crossAxisCount: 3,
                      childAspectRatio: 2.6,
                      labels: StayOptionSets.cancellation.map((o) => o.label).toList(),
                      accent: StayColors.accent,
                      isActive: (i) => _cancellation == StayOptionSets.cancellation[i].value,
                      onTap: (i) => setState(() {
                        _cancellation = StayOptionSets.cancellation[i].value;
                        _dirty = true;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(20, 12, 20, AppInsets.bottomViewPadding(context) + 12),
              child: Obx(() => GradientButton(
                    onPressed: _ctrl.isSaving.value ? null : _save,
                    isLoading: _ctrl.isSaving.value,
                    label: 'Save',
                    gradient: StayColors.gradient,
                    shadowColor: StayColors.accent,
                  )),
            ),
          ]),
        ),
        Obx(() => _ctrl.isSaving.value
            ? AppLoadingOverlay.stackChild(message: 'Saving rules...', indicatorColor: StayColors.accent)
            : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 10),
          child,
        ]),
      );

  Widget _timeField(String label, TimeOfDay value, IconData icon, VoidCallback onTap) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              decoration: BoxDecoration(
                color: StayColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(children: [
                Icon(icon, size: 16, color: StayColors.accentDark),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(StayOptionSets.time12(_hhmm(value)),
                        maxLines: 1,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark)),
                  ),
                ),
              ]),
            ),
          ),
        ],
      );

  Widget _switchRow(String label, bool value, void Function(bool) apply, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textDark)),
          ),
          Switch(
            value: value,
            onChanged: (v) => setState(() {
              apply(v);
              _dirty = true;
            }),
            activeThumbColor: StayColors.accentDark,
            activeTrackColor: StayColors.accent.withValues(alpha: 0.45),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
      );
}
