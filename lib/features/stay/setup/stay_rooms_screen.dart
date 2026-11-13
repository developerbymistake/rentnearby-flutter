import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_stay_owner.dart';
import 'stay_option_sets.dart';
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
  const StayRoomsScreen({super.key});
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

  static const _max = StayOptionSets.maxRooms;

  @override
  void initState() {
    super.initState();
    for (final r in _ctrl.stay.value?.rooms ?? const []) {
      _rooms.add(_RoomDraft(id: r.id, name: r.roomName, price: r.pricePerNight, guests: r.maxGuests, meals: r.meals));
    }
    _formOpen = _rooms.length < _max;
  }

  @override
  void dispose() {
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
    if (!ok || !mounted) return;
    Get.back();
    AppToast.success('Rooms saved');
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
                StayPageHeader(title: 'Rooms', subtitle: 'Add rooms, up to 2', onBack: _onBack, asset: SetupAssets.bed),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (var i = 0; i < _rooms.length; i++) KeyedSubtree(key: ObjectKey(_rooms[i]), child: _summaryCard(i)),
                      if (_formOpen) KeyedSubtree(key: ValueKey('form-$_formSeq'), child: _form()),
                      _addRow(),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _footer(),
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
              for (final g in StayOptionSets.maxGuests) OptionTileItem(label: 'guests', art: ListingArt.guests, big: StayOptionSets.guestsLabel(g)),
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

  Widget _addRow() {
    final full = _count >= _max;
    return DashedAddRow3D(
      tone: _tone,
      label: 'Add another room',
      trailing: full ? '$_count of $_max · limit reached' : '$_count of $_max',
      enabled: !full,
      onTap: _addAnother,
    );
  }

  Future<void> _pickRoomType() async {
    FocusScope.of(context).unfocus();
    final options = [
      for (final o in StayOptionSets.roomNames)
        if (o.value == _roomName || !_rooms.any((r) => r.name == o.value)) o,
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
