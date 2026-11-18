import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_colors.dart';
import '../../../services/system_settings_channel.dart';
import '../../../services/taxi_ring_service.dart';
import '../../trip/utils/taxi_result.dart';
import 'controllers/driver_ready_controller.dart';
import 'models/driver_request_models.dart';
import 'strings/driver_ready_strings.dart';

class DriverReadyScreen extends StatefulWidget {
  const DriverReadyScreen({super.key, this.controller, this.settings});

  final DriverReadyController? controller;
  final SystemSettingsChannel? settings;

  @override
  State<DriverReadyScreen> createState() => _DriverReadyScreenState();
}

class _DriverReadyScreenState extends State<DriverReadyScreen> {
  late final DriverReadyController _ctrl = widget.controller ?? DriverReadyController.to;
  late final SystemSettingsChannel _settings = widget.settings ?? SystemSettingsChannel.instance;
  static final ListingTone _tone = ListingTone.coral;

  String? _testNote;
  bool _testOk = false;
  String _fallbackMaker = '';
  bool _askedMaker = false;
  late final Worker _makerWorker;

  @override
  void initState() {
    super.initState();
    _makerWorker = ever<DriverDeviceState?>(_ctrl.device, _askMaker);
    _askMaker(_ctrl.device.value);
  }

  @override
  void dispose() {
    _makerWorker.dispose();
    super.dispose();
  }

  void _askMaker(DriverDeviceState? d) {
    if (_askedMaker || d == null || d.manufacturer.trim().isNotEmpty) return;
    _askedMaker = true;
    _settings.deviceInfo().then((m) {
      if (mounted && m != null) setState(() => _fallbackMaker = m.manufacturer);
    });
  }

  Future<void> _runTest() async {
    setState(() => _testNote = null);
    final before = _ctrl.device.value;
    final r = await _ctrl.testRing();
    if (!mounted) return;
    final after = _ctrl.device.value;
    final shownNotSaved = r is! TaxiOk && !identical(before, after) && (after?.ringTested ?? false);
    setState(() {
      switch (r) {
        case TaxiOk(:final value):
          _testOk = value == DriverTestRing.shown;
          _testNote = _testOk ? DriverReadyStrings.testShown : DriverReadyStrings.testNotShown;
        default:
          _testOk = false;
          _testNote = shownNotSaved ? DriverReadyStrings.testNotSaved : DriverReadyStrings.testFailed;
      }
    });
  }

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
              title: DriverReadyStrings.title,
              subtitle: DriverReadyStrings.subtitle,
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
    final missed = _ctrl.missedRings;
    final loaded = _ctrl.device.value != null;
    final probeFailed = !loaded && _ctrl.hasFailed(DriverReadyAction.report) && !_ctrl.isBusy(DriverReadyAction.report);
    final ownMaker = _ctrl.device.value?.manufacturer.trim() ?? '';
    final maker = ownMaker.isNotEmpty ? ownMaker : _fallbackMaker;
    final testDone = _ctrl.isDone(DriverReadyItem.testRing);
    final testing = _ctrl.isBusy(DriverReadyAction.testRing);
    final primary = missed || !testDone;
    return ListView(
      padding: EdgeInsets.fromLTRB(DS.s(16), DS.gv(8), DS.s(16), DS.gv(28)),
      children: [
        if (missed) ...[_MissedLine(tone: _tone), Gap.v(12)],
        if (probeFailed) _ProbeFailed(tone: _tone, onRetry: () => _ctrl.report()),
        if (!loaded && !probeFailed)
          Padding(padding: EdgeInsets.symmetric(vertical: DS.gv(24)), child: const Center(child: CircularProgressIndicator())),
        if (loaded) ...[
          _Row(
            key: const ValueKey('ready_row_notifications'),
            tone: _tone,
            title: DriverReadyStrings.notificationsTitle,
            text: _ctrl.isDone(DriverReadyItem.notifications) ? DriverReadyStrings.notificationsDone : DriverReadyStrings.notificationsFix,
            done: _ctrl.isDone(DriverReadyItem.notifications),
            actionKey: const ValueKey('ready_fix_notifications'),
            onFix: _settings.openNotificationSettings,
          ),
          Gap.v(12),
          _Row(
            key: const ValueKey('ready_row_ring'),
            tone: _tone,
            title: DriverReadyStrings.ringTitle,
            text: _ctrl.isDone(DriverReadyItem.ringSound) ? DriverReadyStrings.ringDone : DriverReadyStrings.ringFix,
            done: _ctrl.isDone(DriverReadyItem.ringSound),
            actionKey: const ValueKey('ready_fix_ring'),
            onFix: () => _settings.openRingChannelSettings(TaxiRingNotification.ringChannelId),
          ),
          Gap.v(12),
          _Row(
            key: const ValueKey('ready_row_battery'),
            tone: _tone,
            title: DriverReadyStrings.batteryTitle,
            text: _ctrl.isDone(DriverReadyItem.battery) ? DriverReadyStrings.batteryDone : DriverReadyStrings.batteryFix,
            extra: _ctrl.isDone(DriverReadyItem.battery) ? null : DriverReadyStrings.batteryMakerLine(maker),
            done: _ctrl.isDone(DriverReadyItem.battery),
            actionKey: const ValueKey('ready_fix_battery'),
            onFix: _settings.openBatterySettings,
          ),
          Gap.v(12),
          _Row(
            key: const ValueKey('ready_row_test'),
            tone: _tone,
            title: DriverReadyStrings.testTitle,
            text: testDone ? DriverReadyStrings.testDone : DriverReadyStrings.testFix,
            done: testDone,
          ),
          Gap.v(16),
          if (testing)
            Padding(padding: EdgeInsets.only(bottom: DS.gv(8)), child: Center(child: Text(DriverReadyStrings.running, style: Ink3D.text(14, FontWeight.w500, Ink3D.sub)))),
          if (_testNote != null)
            Padding(
              padding: EdgeInsets.only(bottom: DS.gv(12)),
              child: Text(_testNote!, key: const ValueKey('ready_test_note'), textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w600, _testOk ? Ink3D.title : Ink3D.sub)),
            ),
          if (primary)
            GradientPillButton(
              key: const ValueKey('ready_test_ring_primary'),
              tone: _tone,
              label: DriverReadyStrings.runTest,
              loading: testing,
              onTap: _runTest,
            )
          else
            WhitePillButton(
              key: const ValueKey('ready_test_ring'),
              tone: _tone,
              label: DriverReadyStrings.runTestAgain,
              enabled: !testing,
              onTap: _runTest,
            ),
        ],
      ],
    );
  }
}

class _MissedLine extends StatelessWidget {
  const _MissedLine({required this.tone});

  final ListingTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('ready_missed_line'),
      padding: EdgeInsets.all(DS.s(14)),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.circular(18), boxShadow: DS.shadows(Form3D.glow(tone))),
      child: Text(DriverReadyStrings.missedLine, style: Ink3D.text(15, FontWeight.w600, Colors.white, height: 1.35)),
    );
  }
}

class _ProbeFailed extends StatelessWidget {
  const _ProbeFailed({required this.tone, required this.onRetry});

  final ListingTone tone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('ready_probe_failed'),
      padding: EdgeInsets.all(DS.s(14)),
      decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(18), boxShadow: DS.shadows(Ink3D.softShadow)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(DriverReadyStrings.probeFailedTitle, style: Ink3D.text(16, FontWeight.w700, Ink3D.title)),
        Gap.v(2),
        Text(DriverReadyStrings.probeFailedBody, style: Ink3D.text(13.5, FontWeight.w400, Ink3D.sub, letterSpacing: 0, height: 1.35)),
        Gap.v(12),
        WhitePillButton(key: const ValueKey('ready_probe_retry'), tone: tone, label: DriverReadyStrings.retry, onTap: onRetry),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.tone, required this.title, required this.text, required this.done, this.extra, this.actionKey, this.onFix});

  final ListingTone tone;
  final String title;
  final String text;
  final String? extra;
  final bool done;
  final Key? actionKey;
  final Future<bool> Function()? onFix;

  @override
  Widget build(BuildContext context) {
    final accent = done ? AppColors.successText : tone.text;
    return Container(
      padding: EdgeInsets.all(DS.s(14)),
      decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(18), boxShadow: DS.shadows(Ink3D.softShadow)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(done ? Icons.check_circle_rounded : Icons.error_rounded, size: DS.s(26), color: accent),
            Gap.h(12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Ink3D.text(16, FontWeight.w700, Ink3D.title)),
                Gap.v(2),
                Text(text, style: Ink3D.text(13.5, FontWeight.w400, Ink3D.sub, letterSpacing: 0, height: 1.35)),
                if (extra != null) ...[Gap.v(4), Text(extra!, style: Ink3D.text(12.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0, height: 1.35))],
              ]),
            ),
            Gap.h(8),
            Text(done ? DriverReadyStrings.done : DriverReadyStrings.fix, style: Ink3D.text(12.5, FontWeight.w700, accent)),
          ]),
          if (!done && onFix != null) ...[
            Gap.v(10),
            Align(
              alignment: Alignment.centerRight,
              child: Tap3D(
                tapKey: actionKey,
                onTap: () => onFix!(),
                label: DriverReadyStrings.openSettings,
                exclude: true,
                child: Container(
                  constraints: BoxConstraints(minHeight: DS.s(36)),
                  padding: EdgeInsets.symmetric(horizontal: DS.s(18), vertical: DS.s(6)),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.circular(18), boxShadow: DS.shadows(Form3D.glow(tone))),
                  child: Text(DriverReadyStrings.openSettings, maxLines: 1, softWrap: false, style: Ink3D.text(13.5, FontWeight.w700, Colors.white)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
