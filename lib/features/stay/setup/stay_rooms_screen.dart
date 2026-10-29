import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/gradient_button.dart';
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

class _StayRoomsScreenState extends State<StayRoomsScreen> {
  final _ctrl = StaySetupController.ensure();
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
      AppToast.error('Please select a room name');
      return false;
    }
    final priceText = _priceCtrl.text.trim();
    if (priceText.isEmpty) {
      AppToast.error('Please enter the price per night');
      _priceFocusNode.requestFocus();
      return false;
    }
    final price = int.tryParse(priceText) ?? 0;
    if (price <StayOptionSets.minPrice || price > StayOptionSets.maxPrice) {
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
    setState(() => _formOpen = true);
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
      _dirty = true;
    });
  }

  void _removeRoom(int i) {
    setState(() {
      _rooms.removeAt(i);
      final at = _editingIndex;
      if (at != null && at > i) _editingIndex = at - 1;
      if (!_formOpen && _rooms.isEmpty) _formOpen = true;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (!_commitForm()) return;
    if (_rooms.isEmpty) {
      AppToast.error('Add at least one room');
      setState(() => _formOpen = true);
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
            _header('Rooms', _onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (var i = 0; i < _rooms.length; i++) _summaryCard(i),
                  if (_formOpen) _form(),
                  _addRow(),
                ],
              ),
            ),
            _footer(),
          ]),
        ),
        Obx(() => _ctrl.isSaving.value
            ? AppLoadingOverlay.stackChild(message: 'Saving rooms...')
            : const SizedBox.shrink()),
      ]),
    );
  }

  Widget _header(String title, VoidCallback onBack) => Container(
        decoration: const BoxDecoration(gradient: StayColors.gradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
            child: Row(children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white)),
              Text(title,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
            ]),
          ),
        ),
      );

  Widget _summaryCard(int i) {
    final r = _rooms[i];
    final at = _editingIndex;
    final number = at != null && i >= at ? i + 2 : i + 1;
    final name = r.name.isNotEmpty ? r.name : 'Room $number';
    final text = '$name · ${BrowseItem.inr(r.price)} / night · '
        '${StayOptionSets.guestsLabel(r.guests)} guests · ${StayOptionSets.labelOf(StayOptionSets.meals, r.meals)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: StayColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StayColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(text,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textDark)),
        ),
        IconButton(
          onPressed: () => _editRoom(i),
          icon: const Icon(Iconsax.edit_2, size: 18, color: StayColors.accentDark),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: () => _removeRoom(i),
          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }

  Widget _label(String text, {bool first = false}) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : 14, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMedium)),
      );

  Widget _form() {
    final number = (_editingIndex ?? _rooms.length) + 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Room $number',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 10),
        _label('Room Name *', first: true),
        StayOptionGrid(
          crossAxisCount: 2,
          childAspectRatio: 3.9,
          labels: StayOptionSets.roomNames.map((o) => o.label).toList(),
          isActive: (i) => _roomName == StayOptionSets.roomNames[i].value,
          onTap: (i) {
            final value = StayOptionSets.roomNames[i].value;
            if (_rooms.any((r) => r.name == value)) {
              AppToast.error('Already used for another room');
              return;
            }
            setState(() {
              _roomName = value;
              _dirty = true;
            });
          },
        ),
        _label('Price per Night (₹) *'),
        TextFormField(
          controller: _priceCtrl,
          focusNode: _priceFocusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          onChanged: (_) => _dirty = true,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. 1500',
            hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textHint),
            prefixText: '₹ ',
            prefixStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StayColors.accent, width: 1.5)),
          ),
        ),
        _label('Max Guests *'),
        StayOptionGrid(
          crossAxisCount: 4,
          childAspectRatio: 1.9,
          labels: StayOptionSets.maxGuests.map(StayOptionSets.guestsLabel).toList(),
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
          isActive: (i) => _meals == StayOptionSets.meals[i].value,
          onTap: (i) => setState(() {
            _meals = StayOptionSets.meals[i].value;
            _dirty = true;
          }),
        ),
      ]),
    );
  }

  Widget _addRow() {
    final full = _count >= _max;
    return AnimatedOpacity(
      opacity: full ? 0.45 : 1,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: full ? null : _addAnother,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: StayColors.accent.withValues(alpha: 0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.add_rounded, size: 18, color: StayColors.accentDark),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Add another room',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: StayColors.accentDark)),
            ),
            Text(full ? '$_count of $_max · limit reached' : '$_count of $_max',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
          ]),
        ),
      ),
    );
  }

  Widget _footer() => Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(20, 12, 20, AppInsets.bottomViewPadding(context) + 12),
        child: Obx(() => GradientButton(
              onPressed: _ctrl.isSaving.value ? null : _save,
              isLoading: _ctrl.isSaving.value,
              label: 'Save',
              gradient: StayColors.gradient,
              shadowColor: StayColors.accent,
            )),
      );
}
