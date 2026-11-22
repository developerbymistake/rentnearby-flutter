import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _helperDir = 'lib/utils/photo_upload/';
const _helper = 'lib/utils/photo_upload/app_photo_pick.dart';

// Every file that picks or uploads a photo through AppPhotoPick. A new caller is a conscious edit here.
const _callers = {
  'lib/controllers/profile_photo_controller.dart',
  'lib/features/stay/setup/stay_basic_details_screen.dart',
  'lib/features/stay/setup/stay_repository.dart',
  'lib/features/taxi/setup/taxi_photo_pick.dart',
  'lib/features/taxi/setup/taxi_repository.dart',
};

List<(String, String)> _lib() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .map((f) => (f.path.replaceAll(r'\', '/'), f.readAsStringSync()))
    .toList();

void main() {
  final files = _lib();

  test('no picker, cropper or multipart call outside lib/utils/photo_upload/', () {
    const banned = ['ImagePicker(', '.pickImage(', '.pickMultiImage(', 'MultipartFile.from', 'ImageCropper('];
    final bad = [
      for (final (path, src) in files)
        if (!path.startsWith(_helperDir))
          for (final b in banned)
            if (src.contains(b)) '$path uses $b',
    ];
    expect(bad, isEmpty);
  });

  test('ImageCropper is used only by the profile photo crop wrapper', () {
    final users = [for (final (path, src) in files) if (src.contains('ImageCropper(')) path];
    expect(users, everyElement(equals('lib/utils/photo_upload/profile_photo_crop.dart')));
  });

  test('the helper holds the stay standard and passes only those constants to the picker', () {
    final src = File(_helper).readAsStringSync();
    expect(src, contains('quality = 85'));
    expect(src, contains('maxWidth = 1280'));
    expect(src, contains('maxBytes = 10 * 1024 * 1024'));
    final args = RegExp(r'(imageQuality|maxWidth|maxHeight)\s*:\s*([^,)]+)').allMatches(src).toList();
    expect(args, isNotEmpty);
    for (final m in args) {
      expect(m.group(1), isNot('maxHeight'), reason: 'no maxHeight on the picker');
      expect(m.group(2)!.trim(), m.group(1) == 'imageQuality' ? 'PhotoPickSpec.quality' : 'PhotoPickSpec.maxWidth');
    }
  });

  test('the files that reference AppPhotoPick are exactly the written list', () {
    final real = {
      for (final (path, src) in files)
        if (!path.startsWith(_helperDir) && src.contains('AppPhotoPick')) path,
    };
    expect(real, _callers);
  });

  test('every form upload builds its part with AppPhotoPick.multipart', () {
    final upload = RegExp(r'ApiService\.(postFormData|putFormData)\(');
    final bad = [
      for (final (path, src) in files)
        if (upload.hasMatch(src) && !src.contains('AppPhotoPick.multipart(')) path,
    ];
    expect(bad, isEmpty);
  });

  test('no client file checks photo extensions or a 1600 width any more', () {
    final bad = [
      for (final (path, src) in files)
        if (src.contains('maxWidth: 1600') || src.contains("'jpg', 'jpeg', 'png', 'webp'")) path,
    ];
    expect(bad, isEmpty);
  });
}
