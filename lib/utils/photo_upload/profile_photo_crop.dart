import 'dart:io';

import 'package:image_cropper/image_cropper.dart';

import '../../config/profile_photo_strings.dart';
import '../../design/design.dart';
import 'app_photo_pick.dart';

abstract final class ProfilePhotoCrop {
  // Null = cancelled or the crop screen failed.
  static Future<File?> crop(String sourcePath) async {
    try {
      final tone = ListingTone.indigo;
      final out = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        maxWidth: PhotoPickSpec.maxWidth.toInt(),
        maxHeight: PhotoPickSpec.maxWidth.toInt(),
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: PhotoPickSpec.quality,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: ProfilePhotoStrings.cropTitle,
            toolbarColor: tone.g2,
            toolbarWidgetColor: DesignColors.onPrimary,
            activeControlsWidgetColor: tone.g2,
            cropStyle: CropStyle.circle,
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
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
