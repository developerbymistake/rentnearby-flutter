import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../navigation/traveller_gate.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../a/widgets/social_chips_a.dart';
import '../../shared/social_error_types.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_nav.dart';
import '../../shared/widgets/plus_widgets.dart';
import '../social_strings_b.dart';
import 'social_widgets_b.dart';

// The one way into the Post your trip wizard from Home, My Trips and the feed: the live post cap and the publish rate are checked first.
abstract final class PostTripEntry {
  /// [tripId] = post an existing trip (trip overview menu).
  static Future<void> open(BuildContext context, {String? tripId}) async {
    final me = SocialMeController.maybe;
    if (me != null && me.me.value == null) await me.refreshQuiet();
    if (!context.mounted) return;
    final limits = me?.me.value?.limits;
    if (limits != null && limits.publicTrips.reached) {
      await PlusSheets.limitReached(context, errorType: SocialErrorTypes.publicTripLimit, data: {'limit': limits.publicTrips.limit}, from: 'post');
      return;
    }
    if (limits != null && limits.publishes.reached) {
      BuddySnack.show(context, SocialStringsB.publishLimit(limits.publishNextAt?.toLocal()), danger: true);
      return;
    }
    await SocialNav.openPostTrip(tripId: tripId);
  }

  /// The line the post entries show in place of their invitation once the live post cap is reached ('' = none).
  static String hint() => SocialStringsB.postEntryHint(SocialMeController.maybe?.me.value?.limits);
}

enum FindBuddiesPostPlace { home, myTrips }

// Spec 23.6/23.7: Home card right below the hero and Find travellers card, built like the Home hero banner (WorkoutCard, 3D art, white action pill);
// My Trips card on top in the compact row look; both in the coral family. Both open the Post your trip wizard.
class FindBuddiesPostCard extends StatelessWidget {
  const FindBuddiesPostCard({super.key, required this.place, this.margin});

  final FindBuddiesPostPlace place;
  final EdgeInsets? margin;

  static const Key homeKey = ValueKey('find_buddies_post_home');
  static const Key myTripsKey = ValueKey('find_buddies_post_my_trips');
  static const Key postKey = ValueKey('find_buddies_post_button');

  // Spec 23.10: both Post your trip cards use the coral colour family (ListingPalette.coral).
  static final ListingTone tone = ListingTone.coral;

  bool get _home => place == FindBuddiesPostPlace.home;

  @override
  Widget build(BuildContext context) {
    if (!TravellerGate.allowed) return const SizedBox.shrink();
    final me = SocialMeController.maybe;
    if (me == null) return _card(context, '');
    return Obx(() {
      me.me.value;
      return _card(context, PostTripEntry.hint());
    });
  }

  Widget _card(BuildContext context, String hint) {
    if (_home) {
      final line = hint.isEmpty ? SocialStringsB.homePostLine : hint;
      return KeyedSubtree(
        key: homeKey,
        child: WorkoutCard(
          key: postKey,
          tone: tone,
          art: ListingArt.backpack,
          eyebrow: SocialStringsB.homePostEyebrow,
          title: SocialStringsB.homePostTitle,
          subtitle: line,
          actionLabel: SocialStringsB.post,
          margin: DS.insets(l: 18, r: 18, b: 4, scaled: false),
          semanticsLabel: '${SocialStringsB.homePostEyebrow} ${SocialStringsB.homePostTitle}. $line ${SocialStringsB.post}',
          onTap: () => PostTripEntry.open(context),
        ),
      );
    }
    const title = SocialStringsB.myTripsPostTitle;
    final line = hint.isEmpty ? SocialStringsB.myTripsPostLine : hint;
    const art = ListingArt.backpack;
    void open() => PostTripEntry.open(context);
    return Padding(
      key: myTripsKey,
      padding: margin ?? DS.gapInsets(l: 18, t: 4, r: 18, b: 14),
      child: Tap3D(
        onTap: open,
        label: '$title. $line. ${SocialStringsB.post}',
        exclude: true,
        child: Container(
          padding: DS.insets(l: 12, t: 12, r: 12, b: 12),
          decoration: BoxDecoration(color: DesignColors.surface, borderRadius: SocialLookB.cardRadius, boxShadow: DS.shadows(Form3D.cardShadow)),
          child: Row(
            children: [
              Container(
                width: DS.s(56),
                height: DS.s(56),
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.br(CardRadius.card), boxShadow: tone.glow(dy: 4, blur: 8)),
                child: ExcludeSemantics(child: Art3D(asset: art, size: 40, shadowBlur: 3, shadowOffset: const Offset(1, 3))),
              ),
              Gap.h(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                    Gap.v(2),
                    Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                  ],
                ),
              ),
              Gap.h(10),
              GradientPillButton(
                key: postKey,
                tone: tone,
                icon: Icons.add_rounded,
                label: SocialStringsB.post,
                expand: false,
                height: SocialButtonsA.smallHeight,
                fontSize: SocialButtonsA.smallFont,
                onTap: open,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
