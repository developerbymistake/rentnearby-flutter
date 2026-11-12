import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../design/design.dart';
import 'dashed_add_row.dart';
import 'stay_option_grid.dart';
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

class _StayRoomsScreenState extends State<StayRoomsScreen> with TickerProviderStateMixin {
  final _ctrl = StaySetupController.ensure();
  late final AnimationController _anim = SetupKit.controller(this);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) SetupKit.play(_anim, context);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
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
            backgroundColor: DesignColors.scaffold,
            body: Column(
              children: [
                StayPageHeader(
                  title: 'Rooms',
                  onBack: _onBack,
                  asset: SetupAssets.bed,
                  animation: templateInterval(_anim, 0, 2),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (var i = 0; i < _rooms.length; i++)
                        TemplateEntranceOnce(key: ObjectKey(_rooms[i]), child: _summaryCard(i)),
                      if (_formOpen) TemplateEntranceOnce(key: ValueKey('form-$_formSeq'), child: _form()),
                      TemplateEntranceOnce(child: _addRow()),
                    ],
                  ),
                ),
                FadeTransition(opacity: templateInterval(_anim, 1, 2), child: _footer()),
              ],
            ),
          ),
          Obx(() => _ctrl.isSaving.value ? const StayBusy(message: 'Saving rooms...') : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _summaryCard(int i) {
    final r = _rooms[i];
    final at = _editingIndex;
    final number = at != null && i >= at ? i + 2 : i + 1;
    final name = r.name.isNotEmpty ? r.name : 'Room $number';
    final text =
        '$name · ${BrowseItem.inr(r.price)} / night · '
        '${StayOptionSets.guestsLabel(r.guests)} guests · ${StayOptionSets.labelOf(StayOptionSets.meals, r.meals)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: TripKit.cardRadiusSmall,
        boxShadow: ShadowTokens.elev1,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SetupKit.sky,
              boxShadow: ShadowTokens.elev1,
            ),
            child: Image.asset(SetupAssets.bed),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TripKit.text(12.5).copyWith(letterSpacing: 0.2))),
          _circleAction(Icons.edit_outlined, PickKit.stayTint, DesignColors.primary, () => _editRoom(i)),
          _circleAction(Icons.close_rounded, PickKit.badTint, PickKit.bad, () => _removeRoom(i)),
        ],
      ),
    );
  }

  Widget _circleAction(IconData icon, Color bg, Color fg, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: fg),
      ),
    ),
  );

  Widget _label(String text, {bool first = false}) => Padding(
    padding: EdgeInsets.only(top: first ? 0 : 14, bottom: 8),
    child: Text(text, style: SetupKit.label()),
  );

  Widget _form() {
    final number = (_editingIndex ?? _rooms.length) + 1;
    return SectionTile(
 tone: KitTone.stay,
 margin: const EdgeInsets.only(bottom: 16),
      title: 'Room $number',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Room Type *', first: true),
          _roomTypeField(),
          _label('Price per Night (₹) *'),
          TextFormField(
            controller: _priceCtrl,
            focusNode: _priceFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
            onChanged: (_) => _dirty = true,
            cursorColor: DesignColors.primary,
            style: SetupKit.fieldText(),
            decoration: SetupKit.input(hint: 'e.g. 1500', prefix: '₹ '),
          ),
          _label('Max Guests *'),
          StayOptionGrid(
            crossAxisCount: 4,
            childAspectRatio: 1.9,
            labels: StayOptionSets.maxGuests.map(StayOptionSets.guestsLabel).toList(),
            accent: PickKit.stay,
            isActive: (i) => _guests == StayOptionSets.maxGuests[i],
            onTap: (i) => setState(() {
              _guests = StayOptionSets.maxGuests[i];
              _dirty = true;
            }),
          ),
          _label('Meals *'),
          StayOptionGrid(
            crossAxisCount: 3,
            childAspectRatio: 2.6,
            labels: StayOptionSets.meals.map((o) => o.label).toList(),
            accent: PickKit.stay,
            isActive: (i) => _meals == StayOptionSets.meals[i].value,
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
    return DashedAddRow(
      label: 'Add another room',
      counter: full ? '$_count of $_max · limit reached' : '$_count of $_max',
      enabled: !full,
      onTap: _addAnother,
      accent: PickKit.stay,
    );
  }

  Widget _roomTypeField() {
    final value = _roomName == null ? null : StayOptionSets.labelOf(StayOptionSets.roomNames, _roomName);
    const radius = BorderRadius.all(Radius.circular(12));
    return Material(
      color: DesignColors.scaffold,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: _pickRoomType,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Image.asset(SetupAssets.bed, width: 22, height: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value ?? 'Select',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: value == null
                      ? TripKit.text(14, weight: FontWeight.w400, color: DesignColors.textMuted)
                      : SetupKit.fieldText(),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: DesignColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickRoomType() async {
    FocusScope.of(context).unfocus();
    final options = [
      for (final o in StayOptionSets.roomNames)
        if (o.value == _roomName || !_rooms.any((r) => r.name == o.value)) o,
    ];
    final picked = await SetupKit.sheet<String>(
      context,
      builder: (sheetCtx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SetupKit.grabber(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Room Type', style: TripKit.text(18)),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(sheetCtx).bottom + 12),
                child: TemplateStagger(
                  children: [
                    for (var i = 0; i < options.length; i++)
                      SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () => Navigator.pop(sheetCtx, options[i].value),
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        options[i].label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TripKit.text(
                                          14,
                                          weight: options[i].value == _roomName ? FontWeight.w700 : FontWeight.w400,
                                          color: options[i].value == _roomName
                                              ? DesignColors.primary
                                              : DesignColors.textStrong,
                                        ),
                                      ),
                                    ),
                                    if (options[i].value == _roomName)
                                      const Icon(Icons.check_rounded, size: 20, color: DesignColors.primary),
                                  ],
                                ),
                              ),
                            ),
                            if (i < options.length - 1)
                              const Divider(height: 1, indent: 20, endIndent: 20, color: DesignColors.dividerSoft),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
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

  Widget _footer() => StayFooter(
    child: Obx(
      () => PrimaryButton(
 tone: KitTone.stay,
        onPressed: _ctrl.isSaving.value ? null : _save,
        loading: _ctrl.isSaving.value,
        label: 'Save',
      ),
    ),
  );
}
