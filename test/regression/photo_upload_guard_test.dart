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

  test('no other picker or multipart builder exists', () {
    const banned = ['MultipartFile(', 'MultipartRequest(', '.pickMedia(', '.pickMultipleMedia(', '.pickVideo(', 'FilePicker'];
    final bad = [
      for (final (path, src) in files)
        if (!path.startsWith(_helperDir))
          for (final b in banned)
            if (src.contains(b)) '$path uses $b',
    ];
    expect(bad, isEmpty);
  });

  test('FormData is built only in the listed upload files', () {
    const uploaders = {
      'lib/controllers/profile_photo_controller.dart',
      'lib/features/stay/setup/stay_repository.dart',
      'lib/features/taxi/setup/taxi_repository.dart',
    };
    final real = {for (final (path, src) in files) if (src.contains('FormData.fromMap(') || src.contains('FormData()')) path};
    expect(real, uploaders);
  });

  test('the crop keeps the stay numbers', () {
    final src = File('lib/utils/photo_upload/profile_photo_crop.dart').readAsStringSync();
    expect(src, contains('maxWidth: PhotoPickSpec.maxWidth.toInt()'));
    expect(src, contains('maxHeight: PhotoPickSpec.maxWidth.toInt()'));
    expect(src, contains('compressQuality: PhotoPickSpec.quality'));
    expect(src, contains('compressFormat: ImageCompressFormat.jpg'));
  });

  test('every pick is followed by the accept check before the file is used', () {
    const sites = {
      'lib/features/stay/setup/stay_basic_details_screen.dart': ('AppPhotoPick.pick', '_acceptPhoto('),
      'lib/features/taxi/setup/taxi_vehicle_screen.dart': ('TaxiPhotoPick.pick(', 'TaxiPhotoPick.reject('),
      'lib/features/taxi_driver/hub/taxi_display_photo_action.dart': ('TaxiPhotoPick.pick(', 'TaxiPhotoPick.reject('),
      'lib/utils/photo_upload/profile_photo_pick.dart': ('AppPhotoPick.pickOne(', 'AppPhotoPick.accept('),
    };
    sites.forEach((path, rule) {
      final src = File(path).readAsStringSync();
      final picks = rule.$1.allMatches(src).toList();
      expect(picks, isNotEmpty, reason: path);
      for (final m in picks) {
        final next = src.indexOf(rule.$2, m.end);
        expect(next >= 0 && next - m.end < 700, isTrue, reason: '$path: ${rule.$1} at ${m.start} has no ${rule.$2} after it');
      }
    });
  });

  test('profile pick deletes the picked original and a refused crop', () {
    final src = File('lib/utils/photo_upload/profile_photo_pick.dart').readAsStringSync();
    expect(src, contains('_drop(File(picked.path))'));
    expect(src, contains('await _drop(cropped);'));
  });

  test('no client file checks photo extensions or a 1600 width any more', () {
    final bad = [
      for (final (path, src) in files)
        if (src.contains('maxWidth: 1600') || src.contains("'jpg', 'jpeg', 'png', 'webp'")) path,
    ];
    expect(bad, isEmpty);
  });
}
