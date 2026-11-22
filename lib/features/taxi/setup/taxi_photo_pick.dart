import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../design/design.dart';
import '../../taxi_driver/strings/taxi_photo_strings.dart';

abstract final class TaxiPhotoPick {
  static const maxBytes = 10 * 1024 * 1024;
  static const okExt = {'jpg', 'jpeg', 'png', 'webp'};

  static Future<File?> pick(BuildContext context, {required ImagePicker picker, required Future<void> Function(String type) onDenied}) async {
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
    final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    if (picked == null) return null;
    return File(picked.path);
  }

  static Future<String?> reject(File f) async {
    final name = f.path.toLowerCase();
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1);
    if (!okExt.contains(ext)) return TaxiPhotoStrings.photoWrongType;
    try {
      if (await f.length() > maxBytes) return TaxiPhotoStrings.photoTooLarge;
    } catch (_) {
      return TaxiPhotoStrings.photoWrongType;
    }
    return null;
  }
}
