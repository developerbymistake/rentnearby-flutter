import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../strings/stay_ring_strings.dart';
import 'stay_ring_settings_controller.dart';

/// "Ring me for new enquiries": the switch row shared by Settings and the ring checklist.
class StayRingSwitchRow extends StatefulWidget {
  const StayRingSwitchRow({super.key, this.controller, this.divider = false, this.tone});

  static const Key switchKey = ValueKey('stay_ring_switch');

  final StayRingSettingsController? controller;
  final bool divider;
  final ListingTone? tone;

  @override
  State<StayRingSwitchRow> createState() => _StayRingSwitchRowState();
}

class _StayRingSwitchRowState extends State<StayRingSwitchRow> {
  late final StayRingSettingsController _c = widget.controller ?? StayRingSettingsController.to;

  @override
  void initState() {
    super.initState();
    if (!_c.loaded.value) unawaited(_c.load());
  }

  Future<void> _set(bool on) async {
    final ok = await _c.setEnabled(on);
    if (!ok && mounted) AppToast.error(StayRingReadyStrings.saveFailed);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final on = _c.enabled.value;
      return IconRow3D(
        art: ListingArt.bell,
        title: StayRingReadyStrings.switchTitle,
        subtitle: _c.loadFailed.value && !_c.loaded.value ? StayRingReadyStrings.loadFailed : (on ? StayRingReadyStrings.switchOn : StayRingReadyStrings.switchOff),
        divider: widget.divider,
        trailing: Switch3D(
          key: StayRingSwitchRow.switchKey,
          tone: widget.tone ?? ListingTone.indigo,
          value: on,
          semanticsLabel: StayRingReadyStrings.switchTitle,
          onChanged: _c.saving.value ? null : _set,
        ),
      );
    });
  }
}
