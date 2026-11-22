import 'package:image_picker/image_picker.dart';

abstract final class StayPhotoPick {
  // image_picker refuses a multi pick with a limit below 2, so the last free slot uses a single pick.
  static Future<List<XFile>> gallery(ImagePicker picker, int remaining) async {
    if (remaining <= 0) return const [];
    if (remaining == 1) {
      final one = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1280);
      return one == null ? const [] : [one];
    }
    return picker.pickMultiImage(imageQuality: 85, maxWidth: 1280, limit: remaining);
  }
}
