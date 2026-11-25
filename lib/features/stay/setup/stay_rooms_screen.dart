import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/plan_controller.dart';
import '../../../utils/app_toast.dart';
import '../../../design/design.dart';
import '../../owner_core/plan/plan_bindings.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../stay_owner/strings/stay_gate_strings.dart';
import '../../stay_owner/strings/stay_setup_strings.dart';
import '../../stay_owner/widgets/stay_widgets.dart';
import 'stay_rooms_form.dart';
import 'stay_setup_controller.dart';

class StayRoomsScreen extends StatefulWidget {
  const StayRoomsScreen({super.key});
  @override
  State<StayRoomsScreen> createState() => _StayRoomsScreenState();
}

class _StayRoomsScreenState extends State<StayRoomsScreen> {
  final _ctrl = StaySetupController.ensure();
  static final _tone = ListingTone.forest;
  late final StayRoomsFormController _form;
  Worker? _planWorker;

  @override
  void initState() {
    super.initState();
    // Reached from /stay-setup before MainScreen: the plan must exist before its limits are read.
    PlanBindings.ensure();
    _form = StayRoomsFormController(onboarding: false, ctrl: _ctrl)..seed(_ctrl.stay.value);
    if (!PlanGate.loaded && Get.isRegistered<PlanController>()) {
      _planWorker = once<bool>(Get.find<PlanController>().loaded, (_) {
        if (mounted) _form.closeBlankIfFull();
      });
    }
  }

  @override
  void dispose() {
    _planWorker?.dispose();
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.validate()) return;
    final ok = await _ctrl.saveRooms(_form.payload());
    if (!mounted) return;
    if (!ok) {
      if (_ctrl.lastErrorType == 'PlanRoomTypeLimit') await _ctrl.showLimitRefusal(context, StayGateStrings.roomGate);
      return;
    }
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
          Scaffold(
            backgroundColor: ListingPalette.forest.page,
            body: Column(
              children: [
                StayPageHeader(title: 'Rooms', subtitle: StaySetupStrings.roomsSubtitle, onBack: _onBack, asset: SetupAssets.bed),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(bottom: DS.s(24)),
                    children: [StayRoomsForm(controller: _form, tone: _tone, after: _addRow)],
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

  Widget _addRow() => Obx(() {
        _ctrl.stay.value;
        if (Get.isRegistered<PlanController>()) Get.find<PlanController>().myPlan.value;
        return _addRowNow();
      });

  Widget _addRowNow() {
    final count = _form.count;
    final max = _form.max;
    final full = count >= max;
    if (full && PlanGate.loaded && PlanGate.canUpgrade) {
      final plus = PlanKeys.plusSeed[PlanKey.roomTypes] ?? max;
      return Column(
        children: [
          StayLockedAddRow(label: StayGateStrings.addRoomType, onTap: () => PlanGate.showLimit(context, StayGateStrings.roomGate())),
          StayPlusBanner(text: StayGateStrings.roomBanner(max, plus), onTap: () => PlanGate.showLimit(context, StayGateStrings.roomGate())),
        ],
      );
    }
    return DashedAddRow3D(
      tone: _tone,
      label: 'Add another room',
      trailing: full ? '$count of $max · limit reached' : '$count of $max',
      enabled: !full,
      onTap: _form.addAnother,
    );
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
