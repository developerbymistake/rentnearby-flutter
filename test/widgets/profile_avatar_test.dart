import 'package:bakhli/widgets/profile_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _fallbackKey = ValueKey('fallback');
const _fallback = Text('A', key: _fallbackKey);

Future<void> _pump(WidgetTester t, Widget child) async {
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));
}

void main() {
  testWidgets('no url, blank url: only the fallback, no image widget', (t) async {
    for (final url in <String?>[null, '', '   ']) {
      await _pump(t, ProfileAvatar(photoUrl: url, size: 40, fallback: _fallback));
      expect(find.byKey(_fallbackKey), findsOneWidget, reason: '$url');
      expect(find.byType(CachedNetworkImage), findsNothing, reason: '$url');
    }
  });

  testWidgets('a url builds a clipped, sized image with the fallback as placeholder and error', (t) async {
    for (final size in [24.0, 40.0, 56.0, 96.0]) {
      await _pump(t, ProfileAvatar(photoUrl: ' https://res.cloudinary.com/x/face.jpg ', size: size, fallback: _fallback));
      final img = t.widget<CachedNetworkImage>(find.byKey(ProfileAvatar.imageKey));
      expect(img.imageUrl, 'https://res.cloudinary.com/x/face.jpg');
      expect(img.memCacheWidth, (size * 3).round());
      expect(img.fit, BoxFit.cover);
      expect(find.byType(ClipOval), findsOneWidget);
      expect(t.getSize(find.byType(ProfileAvatar)), Size(size, size));
      final ctx = t.element(find.byKey(ProfileAvatar.imageKey));
      expect(((img.placeholder!(ctx, img.imageUrl) as Center).child! as Text).key, _fallbackKey);
      expect(((img.errorWidget!(ctx, img.imageUrl, Exception('404')) as Center).child! as Text).key, _fallbackKey);
      expect(t.takeException(), isNull);
    }
  });

  test('decode width is capped and never zero', () {
    expect(ProfileAvatar.decodeWidth(40, 3), 120);
    expect(ProfileAvatar.decodeWidth(0, 3), 1);
    expect(ProfileAvatar.decodeWidth(10000, 3), lessThanOrEqualTo(480));
  });
}
