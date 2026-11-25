import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/plan_controller.dart';
import '../../../models/browse_item.dart';
import '../../../utils/app_toast.dart';
import '../../../design/design.dart';
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
import 'stay_rooms_form.dart';
import 'stay_setup_controller.dart';

class StayRoomsScreen extends StatefulWidget {
  const StayRoomsScreen({super.key, this.manage});

  final bool? manage;
  @override
  State<StayRoomsScreen> createState() => _StayRoomsScreenState();
}

class _StayRoomsScreenState extends State<StayRoomsScreen> {
  final _ctrl = StaySetupController.ensure();
  static final _tone = ListingTone.forest;
  late final StayRoomsFormController _form;
  Worker? _planWorker;
  Worker? _stayWorker;
  String? _deletingId;

  bool get _manage => widget.manage ?? OwnerArgs.isManage(Get.arguments);

  @override
  void initState() {
    super.initState();
    // Reached from /stay-setup before MainScreen: the plan must exist before its limits are read.
    PlanBindings.ensure();
    _form = StayRoomsFormController(onboarding: false, manage: _manage, ctrl: _ctrl)..seed(_ctrl.stay.value);
    if (_manage) _stayWorker = ever<StayOwnerModel?>(_ctrl.stay, (_) => _syncRooms());
    if (_manage && _ctrl.stay.value == null) {
      _ctrl.load().then((_) {
        if (mounted && _ctrl.stay.value != null) _form.mergeLoaded(_ctrl.stay.value);
      });
    }
    if (!PlanGate.loaded && Get.isRegistered<PlanController>()) {
      _planWorker = once<bool>(Get.find<PlanController>().loaded, (_) {
        if (mounted) _form.closeBlankIfFull();
      });
    }
  }

  @override
  void dispose() {
    _planWorker?.dispose();
    _stayWorker?.dispose();
    _form.dispose();
    super.dispose();
  }

  void _syncRooms() {
    if (!mounted || _form.dirty || _form.formOpen) return;
    _form.refill(_ctrl.stay.value);
  }

  Future<void> _save() async {
    if (!_form.commitForm()) return;
    if (_manage && _ctrl.stay.value == null) {
      await _ctrl.load();
      if (!mounted || _ctrl.stay.value == null) return;
      _form.mergeLoaded(_ctrl.stay.value);
      AppToast.info('Rooms loaded. Check and save again.');
      return;
    }
    if (!_form.validate()) return;
    final ok = await _ctrl.saveRooms(_form.payload());
    if (!mounted) return;
    if (!ok) {
      if (_ctrl.lastErrorType == 'PlanRoomTypeLimit') await _ctrl.showLimitRefusal(context, StayGateStrings.roomGate);
      return;
    }
    if (_manage) {
      _form.markSaved();
      _syncRooms();
      StayHubController.maybe?.reload();
    } else {
      Get.back();
    }
    AppToast.success('Rooms saved');
  }

  Future<void> _deleteRoom(int i) async {
    if (_form.rooms.length <= 1) {
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
    _form.removeRoom(i);
    await _save();
  }

  Future<void> _editPrice(int i) async {
    final id = _form.rooms[i].id;
    final hub = StayHubController.maybe;
    final room = id == null ? null : _ctrl.stay.value?.rooms.firstWhereOrNull((r) => r.id == id);
    if (hub == null || room == null || _form.dirty) {
      _form.editRoom(i);
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
    if (_form.dirty || !_form.formBlank) {
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
          ListenableBuilder(
            listenable: _form,
            builder: (context, _) => Scaffold(
              backgroundColor: ListingPalette.forest.page,
              body: Column(
                children: [
                  _manage
                      ? Obx(() {
                          _ctrl.stay.value;
                          if (Get.isRegistered<PlanController>()) Get.find<PlanController>().myPlan.value;
                          return StayPageHeader(title: StayGateStrings.roomsPage, subtitle: StayGateStrings.roomsUsed(_form.rooms.length, _form.max), onBack: _onBack, asset: SetupAssets.bed);
                        })
                      : StayPageHeader(title: 'Rooms', subtitle: StaySetupStrings.roomsSubtitle, onBack: _onBack, asset: SetupAssets.bed),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.only(bottom: DS.s(24)),
                      children: [
                        StayRoomsForm(
                          controller: _form,
                          tone: _tone,
                          before: _manage ? _strip : null,
                          card: _manage ? _manageCard : null,
                          afterRooms: _manage ? _hiddenCards : null,
                          after: _addRow,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: _manage && !_form.dirty && !_form.formOpen ? null : _footer(),
            ),
          ),
          Obx(() => _ctrl.isSaving.value ? const StayBusy(message: 'Saving rooms...', art: SetupAssets.bed) : const SizedBox.shrink()),
        ],
      ),
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
    final r = _form.rooms[i];
    return OwnerManageCard(
      eyebrow: 'ROOM ${i + 1}',
      chip: '${StayOptionSets.guestsLabel(r.guests)} guests',
      title: r.name.isNotEmpty ? r.name : 'Room ${i + 1}',
      sub: '${BrowseItem.inr(r.price)} / night',
      actions: [
        GradientPillButton(tone: _tone, label: 'Edit price', height: 42, fontSize: 12.5, onTap: () => _editPrice(i)),
        WhitePillButton(tone: _tone, label: 'Edit room', height: 42, fontSize: 12.5, onTap: () => _form.editRoom(i)),
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
                  eyebrow: 'ROOM ${_form.rooms.length + k + 1}',
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

  Widget _addRow() => Obx(() {
        _ctrl.stay.value;
        if (Get.isRegistered<PlanController>()) Get.find<PlanController>().myPlan.value;
        return _addRowNow();
      });

  Widget _addRowNow() {
    final count = _form.count;
    final max = _form.max;
    final full = count >= max;
    final upsell = full && PlanGate.loaded && PlanGate.canUpgrade;
    void tap() => PlanGate.addTap(context, full: full, gate: StayGateStrings.roomGate, onAdd: _form.addAnother);
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
                child: Text('$count of $max · limit reached', textAlign: TextAlign.center, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
              ),
          ],
        ),
      );
    }
    final row = DashedAddRow3D(
      tone: _tone,
      label: 'Add another room',
      trailing: full && !upsell ? '$count of $max · limit reached' : '$count of $max',
      enabled: !full || upsell,
      onTap: tap,
    );
    return upsell ? KeyedSubtree(key: GateKeys.softRow, child: row) : row;
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
