import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/plan_controller.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_stay_owner.dart';
import '../../owner_core/data/owner_args.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/owner_inactive.dart';
import '../../owner_core/plan/owner_manage_card.dart';
import '../../owner_core/plan/plan_bindings.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../stay_owner/hub/stay_edit_price_sheet.dart';
import '../../stay_owner/hub/stay_hub_controller.dart';
import '../../stay_owner/plan/stay_plan_strings.dart';
import '../../stay_owner/strings/stay_gate_strings.dart';
import '../../stay_owner/strings/stay_setup_strings.dart';
import '../models/stay_owner_model.dart';
import 'stay_option_sets.dart';
import 'stay_repository.dart';
import 'stay_setup_controller.dart';

class _RoomDraft {
  final String? id;
  final String name;
  final int price;
  final int guests;
  final String meals;
  const _RoomDraft({this.id, required this.name, required this.price, required this.guests, required this.meals});
}

class StayRoomsScreen extends StatefulWidget {
  const StayRoomsScreen({super.key, this.manage});

  final bool? manage;
  @override
  State<StayRoomsScreen> createState() => _StayRoomsScreenState();
}

class _StayRoomsScreenState extends State<StayRoomsScreen> {
  final _ctrl = StaySetupController.ensure();
  static final _tone = ListingTone.forest;
  int _formSeq = 0;
  final _priceCtrl = TextEditingController();
  final _priceFocusNode = FocusNode();
  final List<_RoomDraft> _rooms = [];
  bool _formOpen = false;
  int? _editingIndex;
  String? _editingId;
  String? _roomName;
  int? _guests;
  String? _meals;
  bool _dirty = false;
  String? _deletingId;

  bool get _manage => widget.manage ?? OwnerArgs.isManage(Get.arguments);

  int get _max {
    final m = _ctrl.stay.value?.meter('RoomTypes')?.limit;
    if (m != null && m > 0) return m;
    if (!PlanGate.loaded) return PlanKeys.plusSeed[PlanKey.roomTypes] ?? PlanGate.limit(PlanKey.roomTypes);
    return PlanGate.limit(PlanKey.roomTypes);
  }

  @override
  void initState() {
    super.initState();
    // Reached from /stay-setup before MainScreen: the plan must exist before its limits are read.
    PlanBindings.ensure();
    _fillRooms();
    _formOpen = _manage ? _rooms.isEmpty : _rooms.length < _max;
    if (_manage) _stayWorker = ever<StayOwnerModel?>(_ctrl.stay, (_) => _syncRooms());
    if (_manage && _ctrl.stay.value == null) {
      _ctrl.load().then((_) {
        if (mounted && _ctrl.stay.value != null) setState(_mergeLoaded);
      });
    }
    if (!PlanGate.loaded && Get.isRegistered<PlanController>()) {
      _planWorker = once<bool>(Get.find<PlanController>().loaded, (_) => _afterPlan());
    }
  }

  Worker? _planWorker;
  Worker? _stayWorker;

  void _fillRooms() {
    _rooms.clear();
    for (final r in _ctrl.stay.value?.rooms ?? const []) {
      _rooms.add(_RoomDraft(id: r.id, name: r.roomName, price: r.pricePerNight, guests: r.maxGuests, meals: r.meals));
    }
  }

  // Cold start: saved rooms first, new unsaved drafts after them.
  void _mergeLoaded() {
    final drafts = _rooms.where((r) => r.id == null).toList();
    _fillRooms();
    _rooms.addAll(drafts);
    if (_editingIndex != null) _editingIndex = _rooms.length;
    if (_editingIndex == null && _formBlank) _formOpen = _rooms.isEmpty;
  }

  void _syncRooms() {
    if (!mounted || _dirty || _formOpen) return;
    setState(_fillRooms);
  }

  // The blank extra form was opened on the pre-plan limit; close it once the real limit says full.
  void _afterPlan() {
    if (!mounted || !_formOpen || _editingIndex != null || !_formBlank || _rooms.length < _max) return;
    setState(() => _formOpen = false);
  }

  @override
  void dispose() {
    _planWorker?.dispose();
    _stayWorker?.dispose();
    _priceCtrl.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  int get _count => _rooms.length + (_formOpen ? 1 : 0);

  bool get _formBlank => _roomName == null && _priceCtrl.text.trim().isEmpty && _guests == null && _meals == null;

  void _clearForm() {
    _roomName = null;
    _priceCtrl.clear();
    _guests = null;
    _meals = null;
    _editingIndex = null;
    _editingId = null;
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
    if (_roomName == null) {
      AppToast.error('Please select a room type');
      return false;
    }
    final priceText = _priceCtrl.text.trim();
    if (priceText.isEmpty) {
      AppToast.error('Please enter the price per night');
      _priceFocusNode.requestFocus();
      return false;
    }
    final price = int.tryParse(priceText) ?? 0;
    if (price < StayOptionSets.minPrice || price > StayOptionSets.maxPrice) {
      AppToast.error('Price per night must be between ₹100 and ₹99,00,000');
      _priceFocusNode.requestFocus();
      return false;
    }
    if (_guests == null) {
      AppToast.error('Please select max guests');
      return false;
    }
    if (_meals == null) {
      AppToast.error('Please select meals');
      return false;
    }
    final draft = _RoomDraft(id: _editingId, name: _roomName!, price: price, guests: _guests!, meals: _meals!);
    setState(() {
      final at = _editingIndex;
      if (at != null && at <= _rooms.length) {
        _rooms.insert(at, draft);
      } else {
        _rooms.add(draft);
      }
      _formOpen = false;
      _clearForm();
    });
    return true;
  }

  void _addAnother() {
    if (_count >= _max) return;
    if (_formOpen) {
      if (_formBlank) {
        AppToast.info('Fill this room first');
        return;
      }
      if (!_commitForm()) return;
    }
    setState(() {
      _formOpen = true;
      _formSeq++;
    });
  }

  void _editRoom(int i) {
    final r = _rooms[i];
    if (_formOpen && !_commitForm()) return;
    final at = _rooms.indexOf(r);
    if (at < 0) return;
    setState(() {
      _rooms.removeAt(at);
      _editingIndex = at;
      _editingId = r.id;
      _roomName = r.name.isEmpty ? null : r.name;
      _priceCtrl.text = '${r.price}';
      _guests = r.guests;
      _meals = r.meals;
      _formOpen = true;
      _formSeq++;
      _dirty = true;
    });
  }

  void _removeRoom(int i) {
    setState(() {
      _rooms.removeAt(i);
      final at = _editingIndex;
      if (at != null && at > i) _editingIndex = at - 1;
      if (!_formOpen && _rooms.isEmpty) {
        _formOpen = true;
        _formSeq++;
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (!_commitForm()) return;
    if (_manage && _ctrl.stay.value == null) {
      await _ctrl.load();
      if (!mounted || _ctrl.stay.value == null) return;
      setState(_mergeLoaded);
      AppToast.info('Rooms loaded. Check and save again.');
      return;
    }
    if (_rooms.isEmpty) {
      AppToast.error('Add at least one room');
      setState(() {
        _formOpen = true;
        _formSeq++;
      });
      return;
    }
    final ok = await _ctrl.saveRooms([
      for (final r in _rooms)
        {'id': r.id, 'roomName': r.name, 'pricePerNight': r.price, 'maxGuests': r.guests, 'meals': r.meals},
    ]);
    if (!mounted) return;
    if (!ok) {
      if (_ctrl.lastErrorType == 'PlanRoomTypeLimit') await _ctrl.showLimitRefusal(context, StayGateStrings.roomGate);
      return;
    }
    if (_manage) {
      setState(() => _dirty = false);
      _syncRooms();
      StayHubController.maybe?.reload();
    } else {
      Get.back();
    }
    AppToast.success('Rooms saved');
  }

  Future<void> _deleteRoom(int i) async {
    if (_rooms.length <= 1) {
      AppToast.info('Keep at least one room');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StayConfirmDialog(
        title: 'Delete this room?',
        body: 'Guests will not see it any more.',
        cancelLabel: 'Keep',
        confirmLabel: 'Delete',
        destructive: true,
        art: ListingArt.bed,
        onCancel: () => Navigator.pop(c, false),
        onConfirm: () => Navigator.pop(c, true),
      ),
    );
    if (ok != true || !mounted) return;
    _removeRoom(i);
    await _save();
  }

  Future<void> _editPrice(int i) async {
    final id = _rooms[i].id;
    final hub = StayHubController.maybe;
    final room = id == null ? null : _ctrl.stay.value?.rooms.firstWhereOrNull((r) => r.id == id);
    if (hub == null || room == null || _dirty) {
      _editRoom(i);
      return;
    }
    await StayEditPriceSheet.show(context, hub, room);
  }

  Future<void> _deleteHidden(StayRoomModel r) async {
    if (_deletingId != null) return;
    setState(() => _deletingId = r.id);
    final res = await const StayRepository().deleteHiddenRoom(r.id);
    if (!mounted) return;
    switch (res) {
      case OwnerOk<void>():
        final hub = StayHubController.maybe;
        if (hub != null) {
          await hub.reload();
        } else {
          await _ctrl.load();
        }
      case final OwnerRefused<void> r:
        if (!PlanGate.handleInactive(r)) AppToast.warning(r.message ?? 'Could not delete the room.');
        final restored = StayHubController.maybe;
        if (restored != null) {
          await restored.reload();
        } else {
          await _ctrl.load();
        }
      default:
        AppToast.error('Could not delete the room.');
    }
    if (mounted) setState(() => _deletingId = null);
  }

  void _confirmDiscard() {
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
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: ListingPalette.forest.page,
            body: Column(
              children: [
                _manage
                    ? Obx(() {
                        _ctrl.stay.value;
                        if (Get.isRegistered<PlanController>()) Get.find<PlanController>().myPlan.value;
                        return StayPageHeader(title: StayGateStrings.roomsPage, subtitle: StayGateStrings.roomsUsed(_rooms.length, _max), onBack: _onBack, asset: SetupAssets.bed);
                      })
                    : StayPageHeader(title: 'Rooms', subtitle: StaySetupStrings.roomsSubtitle, onBack: _onBack, asset: SetupAssets.bed),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(bottom: DS.s(24)),
                    children: [
                      if (_manage) _strip(),
                      for (var i = 0; i < _rooms.length; i++) KeyedSubtree(key: ObjectKey(_rooms[i]), child: _manage ? _manageCard(i) : _summaryCard(i)),
                      if (_manage) _hiddenCards(),
                      if (_formOpen) KeyedSubtree(key: ValueKey('form-$_formSeq'), child: _form()),
                      _addRow(),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _manage && !_dirty && !_formOpen ? null : _footer(),
          ),
          Obx(() => _ctrl.isSaving.value ? const StayBusy(message: 'Saving rooms...', art: SetupAssets.bed) : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _summaryCard(int i) {
    final r = _rooms[i];
    final at = _editingIndex;
    final number = at != null && i >= at ? i + 2 : i + 1;
    final name = r.name.isNotEmpty ? r.name : 'Room $number';
    return RoomCard3D(
      tone: _tone,
      eyebrow: 'Room $number',
      title: name,
      line1: '${BrowseItem.inr(r.price)} / night',
      line2: '${StayOptionSets.guestsLabel(r.guests)} guests · ${StayOptionSets.labelOf(StayOptionSets.meals, r.meals)}',
      onEdit: () => _editRoom(i),
      onRemove: () => _removeRoom(i),
    );
  }

  Widget _strip() => Obx(() {
        if (Get.isRegistered<PlanController>()) Get.find<PlanController>().myPlan.value;
        final free = PlanGate.limit(PlanKey.roomTypes);
        final plus = PlanKeys.plusSeed[PlanKey.roomTypes] ?? free;
        if (!PlanGate.canUpgrade) return const SizedBox.shrink();
        return Padding(
          padding: DS.insets(l: 18, t: 14, r: 18),
          child: SoftLock.strip(text: StayGateStrings.roomBanner(free, plus), onTap: () => PlanGate.showLimit(context, StayGateStrings.roomGate())),
        );
      });

  Widget _manageCard(int i) {
    final r = _rooms[i];
    return OwnerManageCard(
      eyebrow: 'ROOM ${i + 1}',
      chip: '${StayOptionSets.guestsLabel(r.guests)} guests',
      title: r.name.isNotEmpty ? r.name : 'Room ${i + 1}',
      sub: '${BrowseItem.inr(r.price)} / night',
      actions: [
        GradientPillButton(tone: _tone, label: 'Edit price', height: 42, fontSize: 12.5, onTap: () => _editPrice(i)),
        WhitePillButton(tone: _tone, label: 'Edit room', height: 42, fontSize: 12.5, onTap: () => _editRoom(i)),
        WhitePillButton(tone: _tone, label: 'Delete', height: 42, fontSize: 12.5, danger: true, onTap: () => _deleteRoom(i)),
      ],
    );
  }

  Widget _hiddenCards() => Obx(() {
        final hidden = _ctrl.stay.value?.hiddenRooms ?? const <StayRoomModel>[];
        if (Get.isRegistered<PlanController>()) Get.find<PlanController>().myPlan.value;
        final free = PlanGate.limit(PlanKey.roomTypes);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var k = 0; k < hidden.length; k++)
              KeyedSubtree(
                key: ValueKey('hidden-${hidden[k].id}'),
                child: OwnerInactiveCard(
                  eyebrow: 'ROOM ${_rooms.length + k + 1}',
                  title: hidden[k].label,
                  sub: '${BrowseItem.inr(hidden[k].pricePerNight)} / night · ${StayOptionSets.guestsLabel(hidden[k].maxGuests)} guests',
                  reason: StayGateStrings.roomInactive(free),
                  editLabels: const ['Edit price', 'Edit room'],
                  busy: _deletingId == hidden[k].id,
                  onDelete: () => _deleteHidden(hidden[k]),
                ),
              ),
            if (hidden.isNotEmpty)
              Padding(
                padding: DS.insets(l: 18, t: 10, r: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextLink(label: StayPlanStrings.chooseWhatStays, tone: KitTone.stayOwner, onTap: () => Get.toNamed(AppRoutes.stayPlanVisible)),
                ),
              ),
          ],
        );
      });

  Widget _form() {
    final number = (_editingIndex ?? _rooms.length) + 1;
    final value = _roomName == null ? null : StayOptionSets.labelOf(StayOptionSets.roomNames, _roomName);
    return FormSectionCard(
      tone: _tone,
      art: ListingArt.bed,
      title: 'Room $number',
      tag: 'Required',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillPickerField(tone: _tone, label: 'Room Type', value: value, hint: 'Select', leadingArt: ListingArt.bed, onTap: _pickRoomType),
          PillField(
            tone: _tone,
            label: 'Price per Night (₹)',
            firstLabel: false,
            controller: _priceCtrl,
            focusNode: _priceFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            onChanged: (_) => _dirty = true,
            prefixText: '₹',
            hint: 'e.g. 1500',
          ),
          const FieldLabel('Max Guests'),
          OptionTileGrid(
            tone: _tone,
            columns: 4,
            items: [
              for (final g in StayOptionSets.maxGuests) OptionTileItem(label: 'guests', art: ListingArt.panda, big: StayOptionSets.guestsLabel(g)),
            ],
            isSelected: (i) => _guests == StayOptionSets.maxGuests[i],
            onTap: (i) => setState(() {
              _guests = StayOptionSets.maxGuests[i];
              _dirty = true;
            }),
          ),
          const FieldLabel('Meals'),
          OptionTileGrid(
            tone: _tone,
            items: [
              for (final o in StayOptionSets.meals) OptionTileItem(label: o.label, art: StayOwnerArt.meals[o.value] ?? ListingArt.star),
            ],
            isSelected: (i) => _meals == StayOptionSets.meals[i].value,
            onTap: (i) => setState(() {
              _meals = StayOptionSets.meals[i].value;
              _dirty = true;
            }),
          ),
        ],
      ),
    );
  }

  Widget _addRow() => Obx(() {
        _ctrl.stay.value;
        if (Get.isRegistered<PlanController>()) Get.find<PlanController>().myPlan.value;
        return _addRowNow();
      });

  Widget _addRowNow() {
    final full = _count >= _max;
    final upsell = full && PlanGate.loaded && PlanGate.canUpgrade;
    void tap() => PlanGate.addTap(context, full: full, gate: StayGateStrings.roomGate, onAdd: _addAnother);
    if (_manage) {
      final button = GradientPillButton(tone: _tone, label: StayGateStrings.addRoomType, enabled: !full || upsell, onTap: tap);
      return Padding(
        padding: DS.insets(l: 18, t: 16, r: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            upsell ? KeyedSubtree(key: GateKeys.softRow, child: button) : button,
            if (full && !upsell)
              Padding(
                padding: EdgeInsets.only(top: DS.gv(8)),
                child: Text('$_count of $_max · limit reached', textAlign: TextAlign.center, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
              ),
          ],
        ),
      );
    }
    final row = DashedAddRow3D(
      tone: _tone,
      label: 'Add another room',
      trailing: full && !upsell ? '$_count of $_max · limit reached' : '$_count of $_max',
      enabled: !full || upsell,
      onTap: tap,
    );
    return upsell ? KeyedSubtree(key: GateKeys.softRow, child: row) : row;
  }

  Future<void> _pickRoomType() async {
    FocusScope.of(context).unfocus();
    final options = [
      for (final o in StayOptionSets.roomNames)
        if (o.value == _roomName || (!_rooms.any((r) => r.name == o.value) && !(_ctrl.stay.value?.hiddenRooms.any((h) => h.roomName == o.value) ?? false))) o,
    ];
    final picked = await Sheet3D.show<String>(
      context,
      builder: (sheetCtx) => Sheet3D(
        tone: _tone,
        art: ListingArt.bed,
        title: 'Room Type',
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++)
              SheetListRow(
                tone: _tone,
                compact: true,
                title: options[i].label,
                selected: options[i].value == _roomName,
                divider: i > 0,
                onTap: () => Navigator.pop(sheetCtx, options[i].value),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted || picked == _roomName) return;
    setState(() {
      _roomName = picked;
      _dirty = true;
    });
  }

  Widget _footer() => Obx(
        () => FormFooter(
          tone: _tone,
          primaryLabel: 'Save',
          onPrimary: _ctrl.isSaving.value ? null : _save,
          primaryLoading: _ctrl.isSaving.value,
        ),
      );
}
