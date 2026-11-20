import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../scan_rules.dart';

enum ScanState { checking, scanning, notBakhli, ownQr, cameraOff }

enum CameraAccess { granted, denied, permanentlyDenied }

abstract class ScanPermissionGate {
  Future<CameraAccess> status();
  Future<CameraAccess> request();
  Future<void> openSettings();
}

class DeviceScanPermission implements ScanPermissionGate {
  const DeviceScanPermission();

  static CameraAccess _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return CameraAccess.granted;
    if (s.isPermanentlyDenied || s.isRestricted) return CameraAccess.permanentlyDenied;
    return CameraAccess.denied;
  }

  @override
  Future<CameraAccess> status() async => _map(await Permission.camera.status);

  @override
  Future<CameraAccess> request() async => _map(await Permission.camera.request());

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

class ScanController extends GetxController {
  ScanController({
    required this.ownUsername,
    required this.onFound,
    ScanPermissionGate? permission,
    DateTime Function()? clock,
    Future<void> Function()? haptic,
  })  : _permission = permission ?? const DeviceScanPermission(),
        _debounce = ScanDebounce(clock: clock),
        _haptic = haptic ?? HapticFeedback.lightImpact;

  final String? Function() ownUsername;
  final void Function(String username) onFound;
  final ScanPermissionGate _permission;
  final ScanDebounce _debounce;
  final Future<void> Function() _haptic;

  final state = ScanState.checking.obs;
  final settingsNeeded = false.obs;
  bool _busy = false;

  Future<void> start() async {
    if (_busy) return;
    _busy = true;
    try {
      var access = await _permission.status();
      if (access != CameraAccess.granted) access = await _permission.request();
      _apply(access);
    } catch (_) {
      state.value = ScanState.cameraOff;
    } finally {
      _busy = false;
    }
  }

  Future<void> recheck() async {
    if (state.value != ScanState.cameraOff || _busy) return;
    try {
      final access = await _permission.status();
      if (access == CameraAccess.granted) _apply(access);
    } catch (_) {}
  }

  Future<void> allow() async {
    if (_busy) return;
    _busy = true;
    try {
      if (settingsNeeded.value) {
        await _permission.openSettings();
        return;
      }
      _apply(await _permission.request());
    } catch (_) {
      state.value = ScanState.cameraOff;
    } finally {
      _busy = false;
    }
  }

  void _apply(CameraAccess access) {
    settingsNeeded.value = access == CameraAccess.permanentlyDenied;
    state.value = access == CameraAccess.granted ? ScanState.scanning : ScanState.cameraOff;
  }

  void onRead(String? raw) {
    if (state.value != ScanState.scanning || !_debounce.open) return;
    _debounce.mark();
    switch (ScanRules.classify(raw, ownUsername())) {
      case ScanVerdict.notBakhli:
        state.value = ScanState.notBakhli;
      case ScanVerdict.own:
        state.value = ScanState.ownQr;
      case ScanVerdict.other:
        final username = raw!;
        _haptic();
        onFound(username);
    }
  }

  void cameraFailed() {
    if (state.value == ScanState.scanning) state.value = ScanState.cameraOff;
  }

  void scanAgain() {
    if (state.value == ScanState.notBakhli || state.value == ScanState.ownQr) state.value = ScanState.scanning;
  }
}
