import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_stay_owner.dart';
import '../../../design/extra/tone_segment_control.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../models/stay_owner_model.dart';
import 'stay_option_sets.dart';
import 'stay_setup_controller.dart';

class StayRoomDraft {
  final String? id;
  final String name;
  final int price;
  final int guests;
  final String meals;
  const StayRoomDraft({this.id, required this.name, required this.price, required this.guests, required this.meals});
}

enum StayRoomsAction { add, save, next }

class StayRoomsFormController extends ChangeNotifier {
  StayRoomsFormController({required this.onboarding, StaySetupController? ctrl}) : _ctrl = ctrl ?? StaySetupController.ensure();

  final bool onboarding;
  final StaySetupController _ctrl;
  final priceCtrl = TextEditingController();
  final priceFocusNode = FocusNode();
  final List<StayRoomDraft> rooms = [];
  int formSeq = 0;
  bool formOpen = false;
  int? editingIndex;
  String? editingId;
  String? roomName;
  int? guests;
  String? meals;
  bool dirty = false;

  static const onboardingHint = 'Add 2 room types.';
  static const onboardingLimit = 'You can add up to 2 room types.';
  static const addLabel = 'Add room';
  static const saveLabel = 'Save';

  int get max {
    if (onboarding) return PlanKeys.freeSeed[PlanKey.roomTypes]!;
    final m = _ctrl.stay.value?.meter('RoomTypes')?.limit;
    if (m != null && m > 0) return m;
    if (!PlanGate.loaded) return PlanKeys.plusSeed[PlanKey.roomTypes] ?? PlanGate.limit(PlanKey.roomTypes);
    return PlanGate.limit(PlanKey.roomTypes);
  }

  int get count => rooms.length + (formOpen ? 1 : 0);

  bool get formBlank => roomName == null && priceCtrl.text.trim().isEmpty && guests == null && meals == null;

  StayRoomsAction get action {
    if (formOpen) return StayRoomsAction.save;
    return rooms.length >= max ? StayRoomsAction.next : StayRoomsAction.add;
  }

  void seed(StayOwnerModel? s) {
    rooms
      ..clear()
      ..addAll([
        for (final r in s?.rooms ?? const <StayRoomModel>[])
          StayRoomDraft(id: r.id, name: r.roomName, price: r.pricePerNight, guests: r.maxGuests, meals: r.meals),
      ]);
    _clearForm();
    formOpen = !onboarding && rooms.length < max;
    formSeq++;
    notifyListeners();
  }

  void touch() {
    dirty = true;
    notifyListeners();
  }

  void setRoomName(String v) {
    roomName = v;
    touch();
  }

  void setGuests(int v) {
    guests = v;
    touch();
  }

  void setMeals(String v) {
    meals = v;
    touch();
  }

  void _clearForm() {
    roomName = null;
    priceCtrl.clear();
    guests = null;
    meals = null;
    editingIndex = null;
    editingId = null;
  }

  void _openBlank() {
    formOpen = true;
    formSeq++;
  }

  static StayRoomDraft? _check(String? id, String? name, TextEditingController priceCtrl, FocusNode focus, int? guests, String? meals) {
    if (name == null) {
      AppToast.error('Please select a room type');
      return null;
    }
    final priceText = priceCtrl.text.trim();
    if (priceText.isEmpty) {
      AppToast.error('Please enter the price per night');
      focus.requestFocus();
      return null;
    }
    final price = int.tryParse(priceText) ?? 0;
    if (price < StayOptionSets.minPrice || price > StayOptionSets.maxPrice) {
      AppToast.error('Price per night must be between ₹100 and ₹99,00,000');
      focus.requestFocus();
      return null;
    }
    if (guests == null) {
      AppToast.error('Please select max guests');
      return null;
    }
    if (meals == null) {
      AppToast.error('Please select meals');
      return null;
    }
    return StayRoomDraft(id: id, name: name, price: price, guests: guests, meals: meals);
  }

  bool commitForm() {
    if (!formOpen) return true;
    if (!onboarding && formBlank && editingIndex == null) {
      formOpen = false;
      _clearForm();
      notifyListeners();
      return true;
    }
    final draft = _check(editingId, roomName, priceCtrl, priceFocusNode, guests, meals);
    if (draft == null) return false;
    final at = editingIndex;
    if (at != null && at <= rooms.length) {
      rooms.insert(at, draft);
    } else {
      rooms.add(draft);
    }
    formOpen = false;
    _clearForm();
    notifyListeners();
    return true;
  }

  bool validate() {
    if (!commitForm()) return false;
    if (rooms.isEmpty) {
      AppToast.error('Add at least one room');
      _openBlank();
      notifyListeners();
      return false;
    }
    if (onboarding && rooms.length < max) {
      AppToast.error(onboardingHint);
      notifyListeners();
      return false;
    }
    return true;
  }

  void openForm() {
    if (formOpen || rooms.length >= max) return;
    _openBlank();
    notifyListeners();
  }

  void addAnother() {
    if (count >= max) return;
    if (formOpen) {
      if (formBlank) {
        AppToast.info('Fill this room first');
        return;
      }
      if (!commitForm()) return;
    }
    _openBlank();
    notifyListeners();
  }

  void editRoom(int i) {
    final r = rooms[i];
    if (formOpen && onboarding && formBlank && editingIndex == null) {
      formOpen = false;
      _clearForm();
    } else if (formOpen && !commitForm()) {
      return;
    }
    final at = rooms.indexOf(r);
    if (at < 0) return;
    rooms.removeAt(at);
    editingIndex = at;
    editingId = r.id;
    roomName = r.name.isEmpty ? null : r.name;
    priceCtrl.text = '${r.price}';
    guests = r.guests;
    meals = r.meals;
    formOpen = true;
    formSeq++;
    dirty = true;
    notifyListeners();
  }

  void removeRoom(int i) {
    rooms.removeAt(i);
    final at = editingIndex;
    if (at != null && at > i) editingIndex = at - 1;
    if (!onboarding && !formOpen && rooms.isEmpty) _openBlank();
    dirty = true;
    notifyListeners();
  }

  // The blank extra form was opened on the pre-plan limit; close it once the real limit says full.
  void closeBlankIfFull() {
    if (!formOpen || editingIndex != null || !formBlank || rooms.length < max) return;
    formOpen = false;
    notifyListeners();
  }

  List<Map<String, dynamic>> payload() => [
        for (final r in rooms) {'id': r.id, 'roomName': r.name, 'pricePerNight': r.price, 'maxGuests': r.guests, 'meals': r.meals},
      ];

  String get key => payload().toString();

  bool changedSince(String? savedKey) =>
      dirty && (key != savedKey || (formOpen && !formBlank));

  @override
  void dispose() {
    priceCtrl.dispose();
    priceFocusNode.dispose();
    super.dispose();
  }
}

class StayRoomsForm extends StatelessWidget {
  const StayRoomsForm({super.key, required this.controller, required this.tone, this.after});

  final StayRoomsFormController controller;
  final ListingTone tone;
  final Widget Function()? after;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < c.rooms.length; i++) KeyedSubtree(key: ObjectKey(c.rooms[i]), child: _summaryCard(i)),
            if (c.formOpen) KeyedSubtree(key: ValueKey('form-${c.formSeq}'), child: _form(context)),
            if (after != null) after!(),
          ],
        );
      },
    );
  }

  Widget _summaryCard(int i) {
    final c = controller;
    final r = c.rooms[i];
    final at = c.editingIndex;
    final number = at != null && i >= at ? i + 2 : i + 1;
    final name = r.name.isNotEmpty ? r.name : 'Room $number';
    return RoomCard3D(
      tone: tone,
      eyebrow: 'Room $number',
      title: name,
      line1: '${BrowseItem.inr(r.price)} / night',
      line2: '${StayOptionSets.guestsLabel(r.guests)} guests · ${StayOptionSets.labelOf(StayOptionSets.meals, r.meals)}',
      onEdit: () => c.editRoom(i),
      onRemove: () => c.removeRoom(i),
    );
  }

  Widget _form(BuildContext context) {
    final c = controller;
    return _roomForm(
      context,
      number: (c.editingIndex ?? c.rooms.length) + 1,
      roomName: c.roomName,
      priceCtrl: c.priceCtrl,
      focus: c.priceFocusNode,
      guests: c.guests,
      meals: c.meals,
      onName: c.setRoomName,
      onGuests: c.setGuests,
      onMeals: c.setMeals,
    );
  }

  Widget _roomForm(
    BuildContext context, {
    required int number,
    required String? roomName,
    required TextEditingController priceCtrl,
    required FocusNode focus,
    required int? guests,
    required String? meals,
    required void Function(String) onName,
    required void Function(int) onGuests,
    required void Function(String) onMeals,
  }) {
    final value = roomName == null ? null : StayOptionSets.labelOf(StayOptionSets.roomNames, roomName);
    return FormSectionCard(
      tone: tone,
      art: ListingArt.bed,
      title: 'Room $number',
      tag: 'Required',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillPickerField(
            tone: tone,
            label: 'Room Type',
            value: value,
            hint: 'Select',
            leadingArt: ListingArt.bed,
            onTap: () => _pickRoomType(context, current: roomName, onPicked: onName),
          ),
          PillField(
            tone: tone,
            label: 'Price per Night (₹)',
            firstLabel: false,
            controller: priceCtrl,
            focusNode: focus,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            onChanged: (_) => controller.dirty = true,
            prefixText: '₹',
            hint: 'e.g. 1500',
          ),
          const FieldLabel('Max Guests'),
          ToneSegmentControl(
            key: const ValueKey('stay-room-guests'),
            tone: tone,
            labels: [for (final g in StayOptionSets.maxGuests) StayOptionSets.guestsLabel(g)],
            semanticLabels: [for (final g in StayOptionSets.maxGuests) '${StayOptionSets.guestsLabel(g)} guests'],
            selected: guests == null ? -1 : StayOptionSets.maxGuests.indexOf(guests),
            onTap: (i) => onGuests(StayOptionSets.maxGuests[i]),
          ),
          const FieldLabel('Meals'),
          ToneSegmentControl(
            key: const ValueKey('stay-room-meals'),
            tone: tone,
            labels: [for (final o in StayOptionSets.meals) o.label],
            selected: StayOptionSets.meals.indexWhere((o) => o.value == meals),
            onTap: (i) => onMeals(StayOptionSets.meals[i].value),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRoomType(BuildContext context, {String? current, required void Function(String) onPicked}) async {
    final c = controller;
    FocusScope.of(context).unfocus();
    final hidden = StaySetupController.ensure().stay.value?.hiddenRooms ?? const <StayRoomModel>[];
    final options = [
      for (final o in StayOptionSets.roomNames)
        if (o.value == current || (!c.rooms.any((r) => r.name == o.value) && !hidden.any((h) => h.roomName == o.value))) o,
    ];
    final picked = await Sheet3D.show<String>(
      context,
      builder: (sheetCtx) => Sheet3D(
        tone: tone,
        art: ListingArt.bed,
        title: 'Room Type',
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++)
              SheetListRow(
                tone: tone,
                compact: true,
                title: options[i].label,
                selected: options[i].value == current,
                divider: i > 0,
                onTap: () => Navigator.pop(sheetCtx, options[i].value),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted || picked == current) return;
    onPicked(picked);
  }
}
