import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/system_settings_channel.dart';
import '../../../services/taxi_ring_service.dart';
import '../../../widgets/ring/ready_check_row.dart';
import '../strings/stay_ring_strings.dart';
import 'stay_ring_ready_controller.dart';
import 'stay_ring_settings_controller.dart';
import 'stay_ring_switch_row.dart';

/// Stay Owner checklist so the phone rings for a new enquiry, with the ring switch on top.
class StayRingReadyScreen extends StatefulWidget {
  const StayRingReadyScreen({super.key, this.controller, this.settingsController, this.settings});

  final StayRingReadyController? controller;
  final StayRingSettingsController? settingsController;
  final SystemSettingsChannel? settings;

  @override
  State<StayRingReadyScreen> createState() => _StayRingReadyScreenState();
}

class _StayRingReadyScreenState extends State<StayRingReadyScreen> {
  late final StayRingReadyController _ctrl = widget.controller ?? StayRingReadyController.to;
  late final SystemSettingsChannel _settings = widget.settings ?? SystemSettingsChannel.instance;
  static final ListingTone _tone = ListingTone.coral;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: KitStatusBar(
        lightIcons: false,
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            PageHeader3D(
              tone: _tone,
              title: StayRingReadyStrings.title,
              subtitle: StayRingReadyStrings.subtitle,
              art: TravelIcon.bell,
              inlineTitle: true,
              onBack: () => Get.back(),
            ),
            Expanded(child: Obx(_body)),
          ]),
        ),
      ),
    );
  }

  Widget _body() {
    final loaded = _ctrl.checked.value;
    final failed = _ctrl.checkFailed.value;
    final testDone = _ctrl.isDone(StayRingReadyItem.testRing);
    final testing = _ctrl.testing.value;
    return ListView(
      padding: EdgeInsets.only(top: DS.gv(8), bottom: DS.gv(28)),
      children: [
        WhiteCard3D(child: StayRingSwitchRow(key: const ValueKey('stay_ready_switch_row'), controller: widget.settingsController, tone: _tone)),
        Gap.v(16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DS.s(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (failed)
                ReadyCheckRow(
                  key: const ValueKey('stay_ready_check_failed'),
                  tone: _tone,
                  title: RingReadyStrings.probeFailedTitle,
                  text: RingReadyStrings.probeFailedBody,
                  done: false,
                ),
              if (!loaded && !failed) Padding(padding: EdgeInsets.symmetric(vertical: DS.gv(24)), child: const Center(child: CircularProgressIndicator())),
              if (loaded) ...[
                ReadyCheckRow(
                  key: const ValueKey('stay_ready_row_notifications'),
                  tone: _tone,
                  title: RingReadyStrings.notificationsTitle,
                  text: _ctrl.isDone(StayRingReadyItem.notifications) ? RingReadyStrings.notificationsDone : StayRingReadyStrings.notificationsFix,
                  done: _ctrl.isDone(StayRingReadyItem.notifications),
                  actionKey: const ValueKey('stay_ready_fix_notifications'),
                  onFix: _settings.openNotificationSettings,
                ),
                Gap.v(12),
                ReadyCheckRow(
                  key: const ValueKey('stay_ready_row_ring'),
                  tone: _tone,
                  title: RingReadyStrings.ringTitle,
                  text: _ctrl.isDone(StayRingReadyItem.ringSound) ? RingReadyStrings.ringDone : StayRingReadyStrings.ringFix,
                  done: _ctrl.isDone(StayRingReadyItem.ringSound),
                  actionKey: const ValueKey('stay_ready_fix_ring'),
                  onFix: () => _settings.openRingChannelSettings(TaxiRingNotification.stayRingChannelId),
                ),
                Gap.v(12),
                ReadyCheckRow(
                  key: const ValueKey('stay_ready_row_battery'),
                  tone: _tone,
                  title: RingReadyStrings.batteryTitle,
                  text: _ctrl.isDone(StayRingReadyItem.battery) ? RingReadyStrings.batteryDone : RingReadyStrings.batteryFix,
                  done: _ctrl.isDone(StayRingReadyItem.battery),
                  actionKey: const ValueKey('stay_ready_fix_battery'),
                  onFix: _settings.openBatterySettings,
                ),
                Gap.v(12),
                ReadyCheckRow(
                  key: const ValueKey('stay_ready_row_test'),
                  tone: _tone,
                  title: RingReadyStrings.testTitle,
                  text: testDone ? RingReadyStrings.testDone : StayRingReadyStrings.testFix,
                  done: testDone,
                ),
                Gap.v(16),
                if (testing)
                  Padding(padding: EdgeInsets.only(bottom: DS.gv(8)), child: Center(child: Text(RingReadyStrings.running, style: Ink3D.text(14, FontWeight.w500, Ink3D.sub)))),
                if (_ctrl.testNotShown.value || _ctrl.testFailed.value)
                  Padding(
                    padding: EdgeInsets.only(bottom: DS.gv(12)),
                    child: Text(
                      _ctrl.testFailed.value ? RingReadyStrings.testFailed : StayRingReadyStrings.testNotShown,
                      key: const ValueKey('stay_ready_test_note'),
                      textAlign: TextAlign.center,
                      style: Ink3D.text(14, FontWeight.w600, Ink3D.sub),
                    ),
                  ),
                if (!testDone)
                  GradientPillButton(
                    key: const ValueKey('stay_ready_test_primary'),
                    tone: _tone,
                    label: RingReadyStrings.runTest,
                    loading: testing,
                    onTap: _ctrl.testRing,
                  )
                else
                  WhitePillButton(
                    key: const ValueKey('stay_ready_test_again'),
                    tone: _tone,
                    label: RingReadyStrings.runTestAgain,
                    enabled: !testing,
                    onTap: _ctrl.testRing,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
