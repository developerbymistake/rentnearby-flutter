import 'dart:io';

import 'package:bakhli/utils/photo_upload/app_photo_pick.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

class _Picker extends ImagePickerPlatform {
  _Picker({this.fail = false});
  final bool fail;
  final singles = <ImagePickerOptions>[];
  final sources = <ImageSource>[];
  final multis = <MultiImagePickerOptions>[];

  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async {
    if (fail) throw Exception('no photos');
    sources.add(source);
    singles.add(options);
    return XFile('a.jpg');
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({MultiImagePickerOptions options = const MultiImagePickerOptions()}) async {
    if (fail) throw Exception('no photos');
    multis.add(options);
    return [for (var i = 0; i < (options.limit ?? 2); i++) XFile('m$i.jpg')];
  }
}

const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46, 0, 1];
const _png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D];
const _webp = [0x52, 0x49, 0x46, 0x46, 0x24, 0, 0, 0, 0x57, 0x45, 0x42, 0x50];
const _heic = [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63];

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('pick_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, List<int> bytes) => File('${dir.path}/$name')..writeAsBytesSync(bytes);

  group('accept', () {
    test('JPEG, PNG and WebP bytes pass under any name', () async {
      for (final name in ['a.jpg', 'b.heic', 'noext', 'c.PNG']) {
        expect(await AppPhotoPick.accept(write(name, _jpeg)), isNull, reason: name);
      }
      expect(await AppPhotoPick.accept(write('p.png', _png)), isNull);
      expect(await AppPhotoPick.accept(write('w.webp', _webp)), isNull);
    });

    test('HEIC, text, short and empty files are the wrong type', () async {
      expect(await AppPhotoPick.accept(write('h.heic', _heic)), PhotoReject.wrongType);
      expect(await AppPhotoPick.accept(write('t.jpg', 'hello there friend'.codeUnits)), PhotoReject.wrongType);
      expect(await AppPhotoPick.accept(write('s.jpg', [0xFF, 0xD8])), PhotoReject.wrongType);
      expect(await AppPhotoPick.accept(write('e.jpg', [])), PhotoReject.wrongType);
      expect(await AppPhotoPick.accept(File('${dir.path}/missing.jpg')), PhotoReject.wrongType);
    });

    test('over 10 MB is too large, exactly 10 MB passes', () async {
      final big = List<int>.filled(PhotoPickSpec.maxBytes + 1, 0)..setRange(0, _jpeg.length, _jpeg);
      expect(await AppPhotoPick.accept(write('big.jpg', big)), PhotoReject.tooLarge);
      expect(await AppPhotoPick.accept(write('ok.jpg', big.sublist(0, PhotoPickSpec.maxBytes))), isNull);
    });
  });

  group('pick', () {
    late ImagePickerPlatform before;
    setUp(() => before = ImagePickerPlatform.instance);
    tearDown(() => ImagePickerPlatform.instance = before);

    test('pickOne passes quality 85 and width 1280 for camera and gallery', () async {
      final p = _Picker();
      ImagePickerPlatform.instance = p;
      expect((await AppPhotoPick.pickOne(ImageSource.camera))?.path, 'a.jpg');
      expect(await AppPhotoPick.pickOne(ImageSource.gallery), isNotNull);
      expect(p.sources, [ImageSource.camera, ImageSource.gallery]);
      for (final o in p.singles) {
        expect(o.imageQuality, 85);
        expect(o.maxWidth, 1280);
        expect(o.maxHeight, isNull);
      }
    });

    test('pickGallery: 0 none, 1 single pick, 3 multi pick with limit 3', () async {
      final p = _Picker();
      ImagePickerPlatform.instance = p;
      expect(await AppPhotoPick.pickGallery(0), isEmpty);
      expect(p.singles, isEmpty);
      expect(await AppPhotoPick.pickGallery(1), hasLength(1));
      expect(p.singles, hasLength(1));
      expect(p.multis, isEmpty);
      expect(await AppPhotoPick.pickGallery(3), hasLength(3));
      expect(p.multis.single.limit, 3);
      expect(p.multis.single.imageOptions.imageQuality, 85);
      expect(p.multis.single.imageOptions.maxWidth, 1280);
    });

    test('a throwing picker calls onFailed once and returns nothing', () async {
      ImagePickerPlatform.instance = _Picker(fail: true);
      var failed = 0;
      expect(await AppPhotoPick.pickOne(ImageSource.gallery, onFailed: () => failed++), isNull);
      expect(failed, 1);
      expect(await AppPhotoPick.pickGallery(1, onFailed: () => failed++), isEmpty);
      expect(await AppPhotoPick.pickGallery(4, onFailed: () => failed++), isEmpty);
      expect(failed, 3);
      expect(await AppPhotoPick.pickOne(ImageSource.camera), isNull);
    });
  });

  test('multipart uses the last path segment as the file name', () async {
    final f = write('photo_1.jpg', _jpeg);
    expect((await AppPhotoPick.multipart(f.path)).filename, 'photo_1.jpg');
    expect((await AppPhotoPick.multipart(f.path.replaceAll('/', r'\'))).filename, 'photo_1.jpg');
  });
}
