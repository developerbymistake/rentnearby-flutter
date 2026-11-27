import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../utils/photo_upload/profile_photo_crop.dart';
import '../../../../utils/photo_upload/profile_photo_pick.dart';
import '../../../owner_core/data/owner_result.dart';
import '../../strings/stay_quote_setup_strings.dart';
import '../data/quote_models.dart';
import 'quote_hub_controller.dart';

typedef QuotePhotoPicker = Future<File?> Function(BuildContext context, PhotoCropShape shape);

// Logo and stamp/signature: the profile-photo pick, crop and upload path, then the server-stripped bytes come back (ARCHITECTURE 6).
class QuoteImageController extends GetxController {
  QuoteImageController({required this.hub, QuotePhotoPicker? pick, Future<bool> Function()? isOffline, void Function(String message)? tell})
      : _pick = pick ?? _defaultPick,
        _isOffline = isOffline ?? _connectivityOffline,
        _tell = tell;

  final QuoteHubController hub;
  final QuotePhotoPicker _pick;
  final Future<bool> Function() _isOffline;
  final void Function(String message)? _tell;

  final busy = Rxn<QuoteImageKind>();
  final progress = 0.0.obs;
  final paths = <QuoteImageKind, String>{}.obs;

  static Future<File?> _defaultPick(BuildContext context, PhotoCropShape shape) => ProfilePhotoPick.pick(context, shape: shape);

  static Future<bool> _connectivityOffline() async {
    try {
      final r = await Connectivity().checkConnectivity().timeout(const Duration(seconds: 2), onTimeout: () => const [ConnectivityResult.wifi]);
      return r.isNotEmpty && r.every((c) => c == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  static PhotoCropShape shapeOf(QuoteImageKind kind) => kind == QuoteImageKind.logo ? PhotoCropShape.square : PhotoCropShape.free;

  void _say(String m) => _tell?.call(m);

  // Thumbnails read only the stored server bytes; a missing file is fetched once.
  Future<void> refreshPaths() async {
    final uid = hub.userId;
    final p = hub.hub.value?.profile;
    if (uid == null || p == null) {
      paths.clear();
      return;
    }
    await hub.store.ensureImages(uid, p);
    final next = <QuoteImageKind, String>{};
    for (final kind in QuoteImageKind.values) {
      if (!p.hasImage(kind)) continue;
      final path = await hub.store.imagePath(uid, kind, p.assetsVersion);
      if (path != null) next[kind] = path;
    }
    paths.assignAll(next);
  }

  Future<void> change(BuildContext context, QuoteImageKind kind) async {
    if (busy.value != null) return;
    final file = await _pick(context, shapeOf(kind));
    if (file == null) return;
    try {
      await upload(kind, file);
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  Future<bool> upload(QuoteImageKind kind, File file) async {
    if (busy.value != null) return false;
    if (await _isOffline()) {
      _say(QuoteSetupStrings.offline);
      return false;
    }
    busy.value = kind;
    progress.value = 0;
    try {
      final r = await hub.api.putImage(kind, file.path, onProgress: (sent, total) {
        if (total > 0) progress.value = sent / total;
      });
      switch (r) {
        case OwnerOk<int>(:final value):
          hub.applyImage(kind, has: true, assetsVersion: value);
          await _afterVersion(kind, value);
          return true;
        case final OwnerRefused<int> refused:
          _say(switch (refused.type) {
            QuoteErrorTypes.photoTooLarge => QuoteSetupStrings.imageTooLarge,
            QuoteErrorTypes.photoInvalid => QuoteSetupStrings.imageInvalid,
            _ => refused.rateLimited ? QuoteSetupStrings.tooMany : QuoteSetupStrings.imageFailed,
          });
          return false;
        case OwnerOffline<int>():
          _say(QuoteSetupStrings.offline);
          return false;
        case OwnerFailed<int>():
          _say(QuoteSetupStrings.imageBusy);
          return false;
      }
    } finally {
      busy.value = null;
    }
  }

  Future<bool> remove(QuoteImageKind kind) async {
    if (busy.value != null) return false;
    busy.value = kind;
    try {
      final r = await hub.api.deleteImage(kind);
      switch (r) {
        case OwnerOk<int>(:final value):
          hub.applyImage(kind, has: false, assetsVersion: value);
          await _afterVersion(kind, value);
          _say(QuoteSetupStrings.imageRemoved);
          return true;
        case OwnerOffline<int>():
          _say(QuoteSetupStrings.offline);
          return false;
        case OwnerRefused<int>():
        case OwnerFailed<int>():
          _say(QuoteSetupStrings.couldNotSave);
          return false;
      }
    } finally {
      busy.value = null;
    }
  }

  // assetsVersion is shared by both images, so both files are re-fetched under the new version.
  Future<void> _afterVersion(QuoteImageKind kind, int version) async {
    final uid = hub.userId;
    final p = hub.hub.value?.profile;
    if (uid == null || p == null) return;
    if (p.hasImage(kind) && !await hub.store.fetchImage(uid, kind, version)) _say(QuoteSetupStrings.imageFailed);
    await refreshPaths();
  }
}
