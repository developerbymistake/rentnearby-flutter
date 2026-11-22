import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import 'package:bakhli/features/buddy/viewer/models/viewer_models.dart';
import 'package:bakhli/features/buddy/viewer/screens/trip_invite_screen.dart';
import 'package:bakhli/features/buddy/shared/widgets/buddy_avatar.dart';
import 'package:bakhli/widgets/profile_avatar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = 'https://res.cloudinary.com/x/image/upload/face.jpg';

Future<void> _pump(WidgetTester t, Widget child, {double width = 392}) async {
  t.view.physicalSize = Size(width * 2, 1600);
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))));
}

Widget _card(String? url) => ChatThreadCard(
      tone: ListingTone.forest,
      initial: 'P',
      sticker: ChatLook3D.artFor('Stay'),
      tag: 'STAY',
      title: 'Priya Sharma',
      subtitle: 'Snow View Homestay',
      time: '10:24',
      preview: 'Hello',
      photoUrl: url,
    );

Widget _header(String? url) => ChatHeader3D(
      tone: ListingTone.forest,
      initial: 'P',
      name: 'Priya Sharma',
      subtitle: 'Snow View Homestay',
      sticker: ChatLook3D.artFor('Stay'),
      art: ChatLook3D.artFor('Stay'),
      onBack: () {},
      onMore: null,
      photoUrl: url,
    );

void main() {
  for (final entry in {'list card': _card, 'header': _header}.entries) {
    testWidgets('${entry.key}: no photo shows today\'s initial only', (t) async {
      for (final url in <String?>[null, '', ' ']) {
        await _pump(t, entry.value(url));
        expect(find.text('P'), findsOneWidget);
        expect(find.byType(CachedNetworkImage), findsNothing);
      }
    });

    testWidgets('${entry.key}: a photo shows the image with the initial as fallback', (t) async {
      for (final width in [320.0, 392.0]) {
        await _pump(t, entry.value(_url), width: width);
        final img = t.widget<CachedNetworkImage>(find.byKey(ProfileAvatar.imageKey));
        expect(img.imageUrl, _url);
        final ctx = t.element(find.byKey(ProfileAvatar.imageKey));
        expect(((img.errorWidget!(ctx, _url, Exception('x')) as Center).child! as Text).data, 'P');
        expect(t.takeException(), isNull);
      }
    });
  }

  testWidgets('list card skeleton has no image and no initial', (t) async {
    await _pump(t, const ChatThreadCard.skeleton());
    expect(find.byType(ProfileAvatar), findsNothing);
  });

  testWidgets('trip invite: inviter photo only when the owner has one', (t) async {
    expect(TripInviteScreen.inviterPhoto(const TripOwnerRef(name: 'Rahul')), isNull);
    expect(TripInviteScreen.inviterPhoto(const TripOwnerRef(name: 'Rahul', photoUrl: '  ')), isNull);
    final w = TripInviteScreen.inviterPhoto(const TripOwnerRef(name: 'Rahul', username: 'Bakhli#1', photoUrl: _url))! as BuddyAvatar;
    expect(w.photoUrl, _url);
    expect(w.initial, 'R');
    expect(w.size, BuddyAvatarSize.sm);
    expect(w.key, TripInviteScreen.inviterPhotoKey);
  });
}
