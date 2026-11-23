import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

abstract final class PhotoPickSpec {
  static const int quality = 85;
  static const double maxWidth = 1280;
  static const int maxBytes = 10 * 1024 * 1024;
}

enum PhotoReject { wrongType, tooLarge }

// The one place that opens the picker and builds an upload part (stay photo standard: 85 / 1280, JPEG PNG WebP bytes, 10 MB).
abstract final class AppPhotoPick {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickOne(ImageSource source, {void Function()? onFailed}) async {
    try {
      return await _picker.pickImage(source: source, imageQuality: PhotoPickSpec.quality, maxWidth: PhotoPickSpec.maxWidth);
    } catch (_) {
      onFailed?.call();
      return null;
    }
  }

  // image_picker refuses a multi pick with a limit below 2, so the last free slot uses a single pick.
  static Future<List<XFile>> pickGallery(int remaining, {void Function()? onFailed}) async {
    if (remaining <= 0) return const [];
    try {
      if (remaining == 1) {
        final one = await _picker.pickImage(source: ImageSource.gallery, imageQuality: PhotoPickSpec.quality, maxWidth: PhotoPickSpec.maxWidth);
        return one == null ? const [] : [one];
      }
      return await _picker.pickMultiImage(imageQuality: PhotoPickSpec.quality, maxWidth: PhotoPickSpec.maxWidth, limit: remaining);
    } catch (_) {
      onFailed?.call();
      return const [];
    }
  }

  static Future<PhotoReject?> accept(File f) async {
    try {
      final length = await f.length();
      if (length == 0) return PhotoReject.wrongType;
      if (length > PhotoPickSpec.maxBytes) return PhotoReject.tooLarge;
      final raf = await f.open();
      try {
        final head = await raf.read(12);
        return isImage(head) ? null : PhotoReject.wrongType;
      } finally {
        await raf.close();
      }
    } catch (_) {
      return PhotoReject.wrongType;
    }
  }

  static bool isImage(List<int> h) {
    if (h.length >= 3 && h[0] == 0xFF && h[1] == 0xD8 && h[2] == 0xFF) return true;
    if (h.length >= 8 && h[0] == 0x89 && h[1] == 0x50 && h[2] == 0x4E && h[3] == 0x47 && h[4] == 0x0D && h[5] == 0x0A && h[6] == 0x1A && h[7] == 0x0A) return true;
    return h.length >= 12 &&
        h[0] == 0x52 && h[1] == 0x49 && h[2] == 0x46 && h[3] == 0x46 &&
        h[8] == 0x57 && h[9] == 0x45 && h[10] == 0x42 && h[11] == 0x50;
  }

  static Future<MultipartFile> multipart(String path) =>
      MultipartFile.fromFile(path, filename: path.split(RegExp(r'[/\\]')).last);
}
