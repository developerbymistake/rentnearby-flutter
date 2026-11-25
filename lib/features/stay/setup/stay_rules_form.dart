import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../models/stay_owner_model.dart';
import 'stay_option_sets.dart';
import 'stay_option_tiles.dart';

class StayRulesFormController extends ChangeNotifier {
  TimeOfDay checkIn = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay checkOut = const TimeOfDay(hour: 11, minute: 0);
  bool pets = false;
  bool smoking = false;
  bool alcohol = false;
  bool couples = false;
  bool idProof = false;
  String? cancellation;
  bool dirty = false;

  void seed(StayOwnerModel? s) {
    final r = s?.rules;
    if (r != null) {
      checkIn = _parse(r.checkInTime, checkIn);
      checkOut = _parse(r.checkOutTime, checkOut);
      pets = r.petsAllowed;
      smoking = r.smokingAllowed;
      alcohol = r.alcoholAllowed;
      couples = r.unmarriedCouplesAllowed;
      idProof = r.idProofRequired;
      cancellation = r.cancellationPolicy;
    }
    notifyListeners();
  }

  static TimeOfDay _parse(String hhmm, TimeOfDay fallback) {
    final p = hhmm.split(':');
    final h = int.tryParse(p.first);
    final m = p.length > 1 ? int.tryParse(p[1]) : null;
    return h == null || m == null ? fallback : TimeOfDay(hour: h, minute: m);
  }

  static String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void update(VoidCallback apply) {
    apply();
    dirty = true;
    notifyListeners();
  }

  String? validate() => cancellation == null ? 'Please select a cancellation policy' : null;

  Map<String, dynamic> payload() => {
        'checkInTime': hhmm(checkIn),
        'checkOutTime': hhmm(checkOut),
        'petsAllowed': pets,
        'smokingAllowed': smoking,
        'alcoholAllowed': alcohol,
        'unmarriedCouplesAllowed': couples,
        'idProofRequired': idProof,
        'cancellationPolicy': cancellation,
      };

  String get key => payload().toString();

  bool changedSince(String? savedKey) => dirty && key != savedKey;
}

class StayRulesForm extends StatelessWidget {
  const StayRulesForm({super.key, required this.controller, required this.tone});

  final StayRulesFormController controller;
  final ListingTone tone;

  Future<void> _pickTime(BuildContext context, bool checkIn) async {
    final c = controller;
    final picked = await TemplateTimePopup.pick(
      context,
      initial: checkIn ? c.checkIn : c.checkOut,
      label: checkIn ? 'Check-in time' : 'Check-out time',
      tone: KitTone.stay,
      art: ListingArt.key,
    );
    if (picked == null || !context.mounted) return;
    c.update(() {
      if (checkIn) {
        c.checkIn = picked;
      } else {
        c.checkOut = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormSectionCard(
              tone: tone,
              art: ListingArt.key,
              title: 'Check-in and Check-out',
              tag: 'Required',
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _timeField('Check-in', c.checkIn, () => _pickTime(context, true))),
                Gap.h(12),
                Expanded(child: _timeField('Check-out', c.checkOut, () => _pickTime(context, false))),
              ]),
            ),
            FormSectionCard(
              tone: tone,
              art: ListingArt.clipboard,
              title: 'House Rules',
              tag: 'Required',
              child: Column(children: [
                _switchRow('Pets allowed', 'pets', c.pets, (v) => c.pets = v),
                _switchRow('Smoking allowed', 'smoking', c.smoking, (v) => c.smoking = v),
                _switchRow('Alcohol allowed', 'alcohol', c.alcohol, (v) => c.alcohol = v),
                _switchRow('Unmarried couples allowed', 'couples', c.couples, (v) => c.couples = v),
                _switchRow('ID proof required', 'idProof', c.idProof, (v) => c.idProof = v),
              ]),
            ),
            FormSectionCard(
              tone: tone,
              art: ListingArt.calendar,
              title: 'Cancellation',
              tag: 'Required',
              child: OptionTileGrid(
                tone: tone,
                items: StayOptionTiles.cancellation,
                isSelected: (i) => c.cancellation == StayOptionSets.cancellation[i].value,
                onTap: (i) => c.update(() => c.cancellation = StayOptionSets.cancellation[i].value),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _timeField(String label, TimeOfDay value, VoidCallback onTap) => PillPickerField(
        tone: tone,
        label: label,
        value: StayOptionSets.time12(StayRulesFormController.hhmm(value)),
        leadingArt: ListingArt.key,
        trailing: const SizedBox.shrink(),
        onTap: onTap,
      );

  Widget _switchRow(String label, String rule, bool value, void Function(bool) apply) => ToggleRow(
        tone: tone,
        label: label,
        art: StayOptionTiles.houseRuleArt(rule),
        value: value,
        divider: true,
        onChanged: (v) => controller.update(() => apply(v)),
      );
}
