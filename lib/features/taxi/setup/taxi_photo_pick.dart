import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/photo_upload/app_photo_pick.dart';
import '../../taxi_driver/strings/taxi_photo_strings.dart';

abstract final class TaxiPhotoPick {
  static Future<File?> pick(BuildContext context, {required Future<void> Function(String type) onDenied}) async {
    final tone = ListingTone.coral;
    final source = await Sheet3D.show<ImageSource>(
      context,
      builder: (sheetCtx) => Sheet3D(
        tone: tone,
        art: ListingArt.camera,
        title: 'Add Photo',
        centerTitle: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SheetOptionCard(
            tone: tone,
            art: ListingArt.camera,
            title: 'Take Photo',
            subtitle: 'Use camera to capture now',
            onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
          ),
          SheetOptionCard(
            tone: ListingTone.indigo,
            art: ListingArt.sunrise,
            title: 'Choose from Gallery',
            subtitle: 'Pick an existing photo',
            onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return null;
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (status.isPermanentlyDenied && context.mounted) await onDenied('Camera');
        return null;
      }
    }
    final picked = await AppPhotoPick.pickOne(source, onFailed: () => AppToast.error(TaxiPhotoStrings.photoPickFailed));
    if (picked == null) return null;
    return File(picked.path);
  }

  static Future<String?> reject(File f) async => switch (await AppPhotoPick.accept(f)) {
        PhotoReject.wrongType => TaxiPhotoStrings.photoWrongType,
        PhotoReject.tooLarge => TaxiPhotoStrings.photoTooLarge,
        null => null,
      };
}
