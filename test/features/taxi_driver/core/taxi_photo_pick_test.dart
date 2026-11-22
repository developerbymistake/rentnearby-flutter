import 'dart:io';

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi/models/taxi_vehicle_type_model.dart';
import 'package:bakhli/features/taxi/setup/taxi_vehicle_screen.dart';
import 'package:bakhli/features/taxi/taxi_vehicle_types_controller.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_photo_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import 'taxi_setup_fixtures.dart';

class _Types extends TaxiVehicleTypesController {
  @override
  // ignore: must_call_super
  void onInit() {
    types.value = const [TaxiVehicleTypeModel(id: 'v3', name: 'Maruti Ertiga', category: 'MUV', defaultSeats: 7, sortOrder: 1)];
  }

  @override
  Future<void> load() async {}
}

class _Picker extends ImagePickerPlatform {
  _Picker(this.path, {this.fail = false});
  final String path;
  final bool fail;
  final options = <ImagePickerOptions>[];

  @override
  Future<XFile?> getImageFromSource({required ImageSource source, ImagePickerOptions options = const ImagePickerOptions()}) async {
    if (fail) throw Exception('no photos');
    this.options.add(options);
    return XFile(path);
  }
}

const _plate = 'https://res.cloudinary.com/x/plate.jpg';
const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46, 0, 1];

final _mark = RegExp(r'\s*\*\s*$');
Finder _text(String s) => find.byWidgetPredicate((w) {
      if (w is! Text) return false;
      final plain = w.data ?? w.textSpan?.toPlainText(includePlaceholders: false) ?? '';
      return plain.replaceAll(_mark, '').trim() == s;
    });
Finder _section(String title) => find.ancestor(of: _text(title), matching: find.byType(FormSectionCard)).first;
Finder _inSection(String title, String text) => find.descendant(of: _section(title), matching: _text(text));
Finder _localImages(String title) =>
    find.descendant(of: _section(title), matching: find.byWidgetPredicate((w) => w is Image && w.image is ResizeImage && (w.image as ResizeImage).imageProvider is FileImage || w is Image && w.image is FileImage));

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  late Directory dir;
  late ImagePickerPlatform before;
  setUpAll(() => initTestStorage('taxi_photo_pick'));
  setUp(() {
    dir = Directory.systemTemp.createTempSync('taxi_pick');
    before = ImagePickerPlatform.instance;
  });
  tearDown(() {
    ImagePickerPlatform.instance = before;
    tearDownTaxiSetup();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows keeps the decoded preview file open until the image cache lets go.
    }
  });

  String write(String name, List<int> bytes) => (File('${dir.path}/$name')..writeAsBytesSync(bytes)).path;

  Future<void> pickPlate(WidgetTester t) async {
    setUpTaxiSetup(setupTaxi(percent: 40, step1: true, identity: true, plateUrl: _plate));
    Get.put<TaxiVehicleTypesController>(_Types());
    await t.pumpWidget(const SizedBox.shrink());
    await pumpPhone(t, const TaxiVehicleScreen(), size: const Size(411, 2400), toastHost: true);
    await _settle(t);
    await t.tap(_inSection('Number plate photo', 'Add'));
    await _settle(t);
    await t.tap(find.text('Choose from Gallery'));
    await _settle(t);
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 11));
  }

  testWidgets('plate pick with a non-image file shows the wrong-type toast and keeps the old photo', (t) async {
    ImagePickerPlatform.instance = _Picker(write('notes.jpg', 'hello there friend'.codeUnits));
    await pickPlate(t);
    expect(find.text(TaxiPhotoStrings.photoWrongType), findsOneWidget);
    expect(_inSection('Number plate photo', 'Plate'), findsOneWidget);
    expect(_localImages('Number plate photo'), findsNothing);
    await close(t);
  });

  testWidgets('plate pick with JPEG bytes under a .heic name is accepted at 85 / 1280', (t) async {
    final picker = _Picker(write('IMG_1.heic', _jpeg));
    ImagePickerPlatform.instance = picker;
    await pickPlate(t);
    expect(find.text(TaxiPhotoStrings.photoWrongType), findsNothing);
    expect(_localImages('Number plate photo'), findsOneWidget);
    expect(picker.options.single.imageQuality, 85);
    expect(picker.options.single.maxWidth, 1280);
    await close(t);
  });

  testWidgets('a picker failure shows the pick-failed toast and changes nothing', (t) async {
    ImagePickerPlatform.instance = _Picker('', fail: true);
    await pickPlate(t);
    expect(find.text(TaxiPhotoStrings.photoPickFailed), findsOneWidget);
    expect(_inSection('Number plate photo', 'Plate'), findsOneWidget);
    expect(_localImages('Number plate photo'), findsNothing);
    await close(t);
  });
}
