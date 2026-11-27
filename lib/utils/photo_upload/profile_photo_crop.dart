import 'dart:io';

import 'package:image_cropper/image_cropper.dart';

import '../../config/profile_photo_strings.dart';
import '../../design/design.dart';
import 'app_photo_pick.dart';

// profile = round profile photo; square = business logo; free = stamp or signature, any wide box.
enum PhotoCropShape { profile, square, free }

abstract final class ProfilePhotoCrop {
  // Null = cancelled or the crop screen failed.
  static Future<File?> crop(String sourcePath, {PhotoCropShape shape = PhotoCropShape.profile}) async {
    try {
      final tone = ListingTone.indigo;
      final free = shape == PhotoCropShape.free;
      final out = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        maxWidth: PhotoPickSpec.maxWidth.toInt(),
        maxHeight: PhotoPickSpec.maxWidth.toInt(),
        aspectRatio: free ? null : const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: PhotoPickSpec.quality,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: ProfilePhotoStrings.cropTitle,
            toolbarColor: tone.g2,
            toolbarWidgetColor: DesignColors.onPrimary,
            activeControlsWidgetColor: tone.g2,
            cropStyle: shape == PhotoCropShape.profile ? CropStyle.circle : CropStyle.rectangle,
            lockAspectRatio: !free,
            initAspectRatio: free ? CropAspectRatioPreset.original : CropAspectRatioPreset.square,
            aspectRatioPresets: free
                ? const [CropAspectRatioPreset.original, CropAspectRatioPreset.ratio3x2, CropAspectRatioPreset.ratio16x9, CropAspectRatioPreset.square]
                : const [CropAspectRatioPreset.square],
            showCropGrid: true,
          ),
        ],
      );
      return out == null ? null : File(out.path);
    } catch (_) {
      return null;
    }
  }
}
