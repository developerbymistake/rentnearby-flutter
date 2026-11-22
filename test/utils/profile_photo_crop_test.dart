import 'package:bakhli/design/design.dart';
import 'package:bakhli/utils/photo_upload/profile_photo_crop.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_cropper_platform_interface/image_cropper_platform_interface.dart';

class _Cropper extends ImageCropperPlatform {
  _Cropper(this.result, {this.fail = false});
  final String? result;
  final bool fail;
  final calls = <Map<String, Object?>>[];

  @override
  Future<CroppedFile?> cropImage({
    required String sourcePath,
    int? maxWidth,
    int? maxHeight,
    CropAspectRatio? aspectRatio,
    ImageCompressFormat compressFormat = ImageCompressFormat.jpg,
    int compressQuality = 90,
    List<PlatformUiSettings>? uiSettings,
  }) async {
    if (fail) throw Exception('activity gone');
    calls.add({
      'source': sourcePath,
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
      'ratio': aspectRatio,
      'format': compressFormat,
      'quality': compressQuality,
      'ui': uiSettings,
    });
    return result == null ? null : CroppedFile(result!);
  }
}

void main() {
  late ImageCropperPlatform before;
  setUp(() => before = ImageCropperPlatform.instance);
  tearDown(() => ImageCropperPlatform.instance = before);

  test('crop passes 1280 / 1280 / jpg / 85 / square / circle and returns the cropped file', () async {
    final c = _Cropper('/tmp/cropped.jpg');
    ImageCropperPlatform.instance = c;
    final out = await ProfilePhotoCrop.crop('/tmp/picked.jpg');
    expect(out?.path, '/tmp/cropped.jpg');
    final call = c.calls.single;
    expect(call['source'], '/tmp/picked.jpg');
    expect(call['maxWidth'], 1280);
    expect(call['maxHeight'], 1280);
    expect(call['ratio'], const CropAspectRatio(ratioX: 1, ratioY: 1));
    expect(call['format'], ImageCompressFormat.jpg);
    expect(call['quality'], 85);
    final android = (call['ui'] as List<PlatformUiSettings>).whereType<AndroidUiSettings>().single;
    expect(android.cropStyle, CropStyle.circle);
    expect(android.lockAspectRatio, isTrue);
    expect(android.initAspectRatio, CropAspectRatioPreset.square);
    expect(android.aspectRatioPresets, [CropAspectRatioPreset.square]);
    expect(android.showCropGrid, isTrue);
    expect(android.toolbarTitle, 'Crop photo');
    expect(android.toolbarColor, ListingTone.indigo.g2);
    expect(android.activeControlsWidgetColor, ListingTone.indigo.g2);
    expect(android.toolbarWidgetColor, DesignColors.onPrimary);
  });

  test('cancel and a failing crop screen return null', () async {
    ImageCropperPlatform.instance = _Cropper(null);
    expect(await ProfilePhotoCrop.crop('/tmp/a.jpg'), isNull);
    ImageCropperPlatform.instance = _Cropper('/x', fail: true);
    expect(await ProfilePhotoCrop.crop('/tmp/a.jpg'), isNull);
  });
}
