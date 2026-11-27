import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';
import '../controllers/scan_controller.dart';
import '../scan_outcome.dart';
import '../scan_strings.dart';
import '../widgets/scan_frame.dart';
import '../widgets/scan_result_card.dart';

typedef ScanCameraBuilder = Widget Function(BuildContext context, void Function(String? raw) onRead);

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key, this.cameraBuilder, this.permission, this.ownUsername, this.clock, this.haptic, this.onPop});

  final ScanCameraBuilder? cameraBuilder;
  final ScanPermissionGate? permission;
  final String? Function()? ownUsername;
  final DateTime Function()? clock;
  final Future<void> Function()? haptic;
  final void Function(ScanOutcome? result)? onPop;

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> with WidgetsBindingObserver {
  late final ScanController _ctrl = ScanController(
    ownUsername: widget.ownUsername ?? _ownUsername,
    onFound: (username) => _pop(ScanFound(username)),
    permission: widget.permission,
    clock: widget.clock,
    haptic: widget.haptic,
  );

  static String? _ownUsername() => Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.username : null;

  void _pop(ScanOutcome? result) {
    if (widget.onPop != null) {
      widget.onPop!(result);
    } else {
      Get.back(result: result);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ctrl.recheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.dispose();
    super.dispose();
  }

  Widget _camera(BuildContext context) => widget.cameraBuilder != null ? widget.cameraBuilder!(context, _ctrl.onRead) : LiveScanCamera(onRead: _ctrl.onRead, onError: _ctrl.cameraFailed);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: BuddyLook.scanDark,
        body: Obx(() {
          final state = _ctrl.state.value;
          return LayoutBuilder(
            builder: (context, box) {
              final bottomInset = MediaQuery.paddingOf(context).bottom;
              return Stack(
                children: [
                  if (state == ScanState.scanning) Positioned.fill(child: _camera(context)),
                  ..._layers(state, box.maxHeight, bottomInset),
                  _header(context),
                ],
              );
            },
          );
        }),
      ),
    );
  }

  List<Widget> _layers(ScanState state, double height, double bottomInset) {
    switch (state) {
      case ScanState.checking:
        return const [];
      case ScanState.scanning:
        return [
          _centredAt(height, 0.48, 280, const ScanFrame(size: 280, sweep: true)),
          Positioned(
            left: 0,
            right: 0,
            bottom: DS.s(150) + bottomInset,
            child: Text(ScanStrings.hint, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, Colors.white.withValues(alpha: Alpha.v90), letterSpacing: 0)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: DS.s(70) + bottomInset,
            child: Center(child: SizedBox(width: DS.s(220), child: ScanButton(label: ScanStrings.typeUsername, onTap: () => _pop(const ScanTypeInstead()), shadow: true))),
          ),
        ];
      case ScanState.notBakhli:
        return [
          _centredAt(height, 0.34, 240, const ScanFrame(size: 240, color: BuddyLook.scanRose)),
          _card(
            bottomInset,
            ScanResultCard(
              art: BuddyArt.warning,
              title: ScanStrings.notBakhliTitle,
              body: ScanStrings.notBakhliBody,
              typeLabel: ScanStrings.typeUsername,
              actionLabel: ScanStrings.scanAgain,
              onType: () => _pop(const ScanTypeInstead()),
              onAction: _ctrl.scanAgain,
            ),
          ),
        ];
      case ScanState.ownQr:
        return [
          _centredAt(height, 0.34, 240, const ScanFrame(size: 240, color: BuddyLook.scanAmber)),
          _card(
            bottomInset,
            ScanResultCard(
              art: BuddyArt.key,
              title: ScanStrings.ownTitle,
              body: ScanStrings.ownBody,
              typeLabel: ScanStrings.typeUsername,
              actionLabel: ScanStrings.scanAgain,
              onType: () => _pop(const ScanTypeInstead()),
              onAction: _ctrl.scanAgain,
            ),
          ),
        ];
      case ScanState.cameraOff:
        return [
          _centredAt(
            height,
            0.30,
            130,
            Container(
              width: DS.s(130),
              height: DS.s(130),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: Alpha.v10), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: ExcludeSemantics(child: Opacity(opacity: Alpha.high, child: Art3D(asset: BuddyArt.camera, size: 84, shadowAlpha: Alpha.none))),
            ),
          ),
          _card(
            bottomInset,
            Obx(
              () => ScanResultCard(
                art: BuddyArt.camera,
                title: ScanStrings.cameraOffTitle,
                body: ScanStrings.cameraOffBody,
                typeLabel: ScanStrings.typeUsername,
                actionLabel: _ctrl.settingsNeeded.value ? ScanStrings.openSettings : ScanStrings.allowCamera,
                onType: () => _pop(const ScanTypeInstead()),
                onAction: _ctrl.allow,
              ),
            ),
          ),
        ];
    }
  }

  Widget _centredAt(double height, double at, double size, Widget child) =>
      Positioned(left: 0, right: 0, top: height * at - DS.s(size) / 2, child: Center(child: child));

  Widget _card(double bottomInset, Widget card) => Positioned(left: DS.s(14), right: DS.s(14), bottom: DS.s(24) + bottomInset, child: card);

  Widget _header(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(20), DS.s(22) + top, DS.s(20), 0),
        child: Row(
          children: [
            Tap3D(
              onTap: () => _pop(null),
              label: ScanStrings.back,
              exclude: true,
              child: Container(
                width: DS.s(44),
                height: DS.s(44),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: Alpha.v16), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(Icons.chevron_left_rounded, size: DS.s(30), color: Colors.white),
              ),
            ),
            Gap.h(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(ScanStrings.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(20, FontWeight.w700, Colors.white, letterSpacing: 0)),
                  ),
                  Text(
                    ScanStrings.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(12.5, FontWeight.w400, Colors.white.withValues(alpha: Alpha.v80), letterSpacing: 0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveScanCamera extends StatefulWidget {
  const LiveScanCamera({super.key, required this.onRead, this.onError});

  final void Function(String? raw) onRead;
  final VoidCallback? onError;

  @override
  State<LiveScanCamera> createState() => _LiveScanCameraState();
}

class _LiveScanCameraState extends State<LiveScanCamera> {
  late final MobileScannerController _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _detect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    widget.onRead(capture.barcodes.first.rawValue);
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
        controller: _camera,
        onDetect: _detect,
        errorBuilder: (context, error) {
          if (widget.onError != null) WidgetsBinding.instance.addPostFrameCallback((_) => widget.onError!());
          return const SizedBox.shrink();
        },
      );
}
