import 'dart:ui' as ui;

import 'package:bakhli/design/extra/ext_jobs.dart';
import 'package:bakhli/features/jobs/widgets/jobs_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/real_phone.dart';

Future<ui.Image> _photo() async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(const Rect.fromLTWH(0, 0, 400, 300), Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(0, 300), const [Color(0xFF7FB6D9), Color(0xFFD9E6EE), Color(0xFF2B7FA3)], const [0, 0.5, 0.55]));
  return rec.endRecording().toImage(400, 300);
}

void main() {
  setUpAll(() async {
    shotsDir = r'F:\Dhasu\UI_Template_resume\Mock_Final\shots\jobs';
    await loadRealFonts();
  });

  for (final (tag, size) in [('360', const Size(360, 800)), ('300', const Size(300, 800))]) {
    testWidgets('detail photo hero $tag', (t) async {
      debugDisableShadows = false;
      final img = (await t.runAsync(_photo))!;
      await pumpPhone(
        t,
        Scaffold(
          backgroundColor: JobsLook.pageColor,
          body: Column(children: [
            JobsDetailHero(tone: JobsUi.look, height: 288, photo: RawImage(image: img, fit: BoxFit.cover)),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(spacing: 8, children: [JobsTagPill(tone: JobsUi.look, label: 'JOB', solid: true), JobsTagPill(tone: JobsUi.look, label: 'Fresher')]),
            ),
          ]),
        ),
        size: size,
      );
      await settlePhone(t);
      await shot(t, 'detail_photo_$tag');
      expect(t.takeException(), isNull);
      debugDisableShadows = true;
    });
  }
}
