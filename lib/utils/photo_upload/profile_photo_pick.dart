import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../design/design.dart';
import '../../design/extra/ext_taxi_owner.dart';
import '../app_toast.dart';
import 'app_photo_pick.dart';
import 'photo_pick_strings.dart';
import 'profile_photo_crop.dart';

abstract final class ProfilePhotoPick {
  // Null = cancelled or rejected (the toast is already shown).
  static Future<File?> pick(BuildContext context) async {
    final tone = ListingTone.indigo;
    final source = await Sheet3D.show<ImageSource>(
      context,
      builder: (sheetCtx) => Sheet3D(
        tone: tone,
        art: ListingArt.camera,
        title: PhotoPickStrings.sheetTitle,
        subtitle: PhotoPickStrings.sheetSubtitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetOptionCard(tone: tone, art: ListingArt.camera, title: PhotoPickStrings.cameraTitle, subtitle: PhotoPickStrings.cameraSubtitle, onTap: () => Navigator.pop(sheetCtx, ImageSource.camera)),
            SheetOptionCard(tone: tone, art: ListingArt.sunrise, title: PhotoPickStrings.galleryTitle, subtitle: PhotoPickStrings.gallerySubtitle, onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery)),
            Gap.v(8),
          ],
        ),
      ),
    );
    if (source == null) return null;
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (status.isPermanentlyDenied && context.mounted) await _showPermissionDeniedDialog(context, PhotoPickStrings.camera);
        return null;
      }
    }
    final picked = await AppPhotoPick.pickOne(source, onFailed: () => AppToast.error(PhotoPickStrings.pickFailed));
    if (picked == null) return null;
    File? cropped;
    try {
      cropped = await ProfilePhotoCrop.crop(picked.path);
    } finally {
      if (cropped?.path != picked.path) await _drop(File(picked.path));
    }
    if (cropped == null) return null;
    final reject = await AppPhotoPick.accept(cropped);
    if (reject != null) {
      await _drop(cropped);
      AppToast.error(reject == PhotoReject.tooLarge ? PhotoPickStrings.tooLarge : PhotoPickStrings.wrongType);
      return null;
    }
    return cropped;
  }

  static Future<void> _drop(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  static Future<void> _showPermissionDeniedDialog(BuildContext context, String type) async {
    final ok = await showTaxiOwnerDialog(
      context,
      art: ListingArt.camera,
      title: PhotoPickStrings.permissionTitle(type),
      body: PhotoPickStrings.permissionBody(type),
      cancelLabel: PhotoPickStrings.permissionCancel,
      confirmLabel: PhotoPickStrings.permissionOpenSettings,
    );
    if (ok == true) openAppSettings();
  }
}
