import 'stay_page_header.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import 'stay_rules_form.dart';
import 'stay_setup_controller.dart';

class StayRulesScreen extends StatefulWidget {
  const StayRulesScreen({super.key});
  @override
  State<StayRulesScreen> createState() => _StayRulesScreenState();
}

class _StayRulesScreenState extends State<StayRulesScreen> {
  final _ctrl = StaySetupController.ensure();
  final _form = StayRulesFormController();

  @override
  void initState() {
    super.initState();
    _form.seed(_ctrl.stay.value);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = _form.validate();
    if (err != null) {
      AppToast.error(err);
      return;
    }
    final ok = await _ctrl.saveRules(_form.payload());
    if (!ok || !mounted) return;
    Get.back();
    AppToast.success('Rules saved');
  }

  void _onBack() {
    if (_ctrl.isSaving.value) return;
    if (!_form.dirty) {
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
        art: ListingArt.clipboard,
        onCancel: () => Navigator.pop(context),
        onConfirm: () {
          Navigator.pop(context);
          Get.back();
        },
      ),
    );
  }

  static final _tone = ListingTone.forest;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Stack(children: [
        Scaffold(
          backgroundColor: ListingPalette.forest.page,
          body: Column(children: [
            StayPageHeader(title: 'Rules', onBack: _onBack, asset: SetupAssets.clipboard),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: DS.s(24)),
                children: [StayRulesForm(controller: _form, tone: _tone)],
              ),
            ),
          ]),
          bottomNavigationBar: Obx(() => FormFooter(
                tone: _tone,
                primaryLabel: 'Save',
                onPrimary: _ctrl.isSaving.value ? null : _save,
                primaryLoading: _ctrl.isSaving.value,
              )),
        ),
        Obx(() => _ctrl.isSaving.value ? const StayBusy(message: 'Saving rules...', art: SetupAssets.clipboard) : const SizedBox.shrink()),
      ]),
    );
  }
}
