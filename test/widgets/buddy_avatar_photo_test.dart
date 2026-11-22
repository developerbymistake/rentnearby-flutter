import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_avatar.dart';
import 'package:bakhli/widgets/profile_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://res.cloudinary.com/x/image/upload/face.jpg';

Future<void> _pump(WidgetTester t, Widget child) async {
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: child))));
}

Container _frame(WidgetTester t) => t.widget<Container>(find.descendant(of: find.byType(BuddyAvatar), matching: find.byType(Container)).first);

void main() {
  testWidgets('no photo, blank photo: the frame child is the initial text itself, no image widget', (t) async {
    for (final url in <String?>[null, '', '  ']) {
      for (final size in BuddyAvatarSize.values) {
        for (final ring in [false, true]) {
          await _pump(t, BuddyAvatar(initial: 'R', seed: 's', size: size, ring: ring, photoUrl: url));
          final frame = _frame(t);
          expect(frame.child, isA<Text>(), reason: '$url $size $ring');
          expect((frame.child! as Text).data, 'R');
          expect(find.byType(ProfileAvatar), findsNothing);
          expect(find.byType(CachedNetworkImage), findsNothing);
          expect(t.getSize(find.byType(BuddyAvatar)), Size.square(DS.s(size.box)));
        }
      }
    }
  });

  testWidgets('a photo fills the inner circle for every size; initial is placeholder and error widget', (t) async {
    for (final size in BuddyAvatarSize.values) {
      for (final ring in [false, true]) {
        await _pump(t, BuddyAvatar(initial: 'A', seed: 's', size: size, ring: ring, photoUrl: ' $_url '));
        final box = DS.s(size.box);
        final inner = ring ? box - 2 * DS.s(2.5) : box;
        final frame = _frame(t);
        final deco = frame.decoration! as BoxDecoration;
        expect(deco.gradient, isNotNull, reason: 'frame look stays');
        expect(deco.shape, BoxShape.circle);
        expect(find.byType(ProfileAvatar), findsOneWidget);
        expect(t.widget<ProfileAvatar>(find.byType(ProfileAvatar)).size, inner, reason: '$size $ring');
        final img = t.widget<CachedNetworkImage>(find.byKey(ProfileAvatar.imageKey));
        expect(img.imageUrl, _url);
        final ctx = t.element(find.byKey(ProfileAvatar.imageKey));
        expect(((img.placeholder!(ctx, _url) as Center).child! as Text).data, 'A');
        expect(((img.errorWidget!(ctx, _url, Exception('x')) as Center).child! as Text).data, 'A');
        expect(t.getSize(find.byType(BuddyAvatar)), Size.square(box));
        expect(t.takeException(), isNull);
      }
    }
  });

  testWidgets('stack: mixed people keep their own photo; the more dot is unchanged', (t) async {
    await _pump(
      t,
      const BuddyAvatarStack(
        people: [
          (initial: 'R', seed: 'r', photoUrl: _url),
          (initial: 'A', seed: 'a', photoUrl: null),
          (initial: 'P', seed: 'p', photoUrl: ''),
          (initial: 'K', seed: 'k', photoUrl: _url),
        ],
        extra: 2,
      ),
    );
    final avatars = t.widgetList<BuddyAvatar>(find.byType(BuddyAvatar)).toList();
    expect(avatars.map((a) => a.initial), ['R', 'A', 'P']);
    expect(avatars.map((a) => a.photoUrl), [_url, null, '']);
    expect(avatars.every((a) => a.ring), isTrue);
    expect(find.byType(ProfileAvatar), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
  });
}
