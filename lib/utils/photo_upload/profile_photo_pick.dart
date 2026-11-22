import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../design/design.dart';
import '../../design/extra/ext_taxi_owner.dart';
import '../../features/stay_owner/strings/stay_setup_strings.dart';
import '../app_toast.dart';
import 'app_photo_pick.dart';
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
        title: 'Add Photo',
        subtitle: 'Camera or Gallery',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetOptionCard(tone: tone, art: ListingArt.camera, title: 'Take Photo', subtitle: 'Use camera to capture now', onTap: () => Navigator.pop(sheetCtx, ImageSource.camera)),
            SheetOptionCard(tone: tone, art: ListingArt.sunrise, title: 'Choose from Gallery', subtitle: 'Pick existing photos', onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery)),
            Gap.v(8),
          ],
        ),
      ),
    );
    if (source == null) return null;
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (status.isPermanentlyDenied && context.mounted) await _showPermissionDeniedDialog(context, 'Camera');
        return null;
      }
    }
    final picked = await AppPhotoPick.pickOne(source, onFailed: () => AppToast.error(StaySetupStrings.photoPickFailed));
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
      AppToast.error(reject == PhotoReject.tooLarge ? StaySetupStrings.photoTooLarge : StaySetupStrings.photoWrongType);
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
      title: '$type Permission Required',
      body: 'Please enable $type access in your device Settings to add photos.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Open Settings',
    );
    if (ok == true) openAppSettings();
  }
}
