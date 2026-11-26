import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_strings.dart';
import '../social_strings_a.dart';
import 'add_buddies_controller.dart';
import 'people_widgets.dart';

class AddBuddiesScreen extends StatefulWidget {
  const AddBuddiesScreen({super.key});

  static const Key searchKey = ValueKey('add_buddies_search');

  @override
  State<AddBuddiesScreen> createState() => _AddBuddiesScreenState();
}

class _AddBuddiesScreenState extends State<AddBuddiesScreen> {
  late final String _tag = 'add-buddies-${identityHashCode(this)}';
  late final AddBuddiesController c = Get.put(AddBuddiesController(), tag: _tag);
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    if (c.changed) SocialMeController.maybe?.refreshQuiet();
    Get.delete<AddBuddiesController>(tag: _tag);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _toggle(String userId) async {
    final error = await c.toggle(userId);
    if (error != null && mounted) BuddySnack.show(context, error, danger: true);
  }

  Widget _star(PersonRow r) {
    final on = r.isBuddy;
    return Tap3D(
      tapKey: ValueKey('star_${r.person.userId}'),
      onTap: () => _toggle(r.person.userId),
      label: on ? SocialStringsA.removeBuddy : SocialStrings.addToBuddies,
      toggled: on,
      exclude: true,
      child: Container(
        width: DS.s(46),
        height: DS.s(46),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? BuddyLook.snackAction : null,
          border: on ? null : Border.all(color: BuddyLook.checkOff, width: DS.s(2)),
        ),
        child: Icon(Icons.star_rounded, size: DS.s(22), color: on ? BuddyLook.amberText : BuddyLook.checkOff),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BuddyPage(
      title: SocialStringsA.addBuddiesTitle,
      subtitle: SocialStringsA.addBuddiesSub,
      scroll: false,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - DS.s(300)) c.load(more: true);
          return false;
        },
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: DS.s(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetSearchField(
                key: AddBuddiesScreen.searchKey,
                tone: ListingTone.indigo,
                controller: _ctrl,
                focusNode: _focus,
                hint: SocialStringsA.searchFollowers,
                leadingArt: ListingArt.search,
                inputFormatters: noEmojiInputFormatters,
                onChanged: c.onQuery,
                margin: DS.gapInsets(l: 18, t: 6, r: 18),
              ),
              Obx(() {
                final items = c.list.items.toList();
                final state = PeopleStates.of(c.list.state.value,
                    empty: items.isEmpty,
                    emptyTitle: c.query.value.trim().isEmpty ? SocialStringsA.noFollowers : SocialStringsA.noMatch,
                    emptyLine: c.query.value.trim().isEmpty ? SocialStringsA.noFollowersLine : null,
                    onRetry: c.load);
                if (state != null) return state;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PeopleLabel(SocialStringsA.followersAndBuddies(c.list.total.value, c.buddies.value)),
                    PeopleCard(children: [
                      for (final r in items)
                        Row(
                          key: ValueKey('pick_${r.person.userId}'),
                          children: [
                            Expanded(child: SocialPersonTile(person: r.person, subtitle: r.isBuddy ? SocialStrings.buddy : SocialStrings.followsYou)),
                            Padding(padding: DS.insets(r: 16), child: _star(r)),
                          ],
                        ),
                    ]),
                    LoadMoreFooter(loading: c.list.loadingMore.value),
                    Padding(
                      padding: DS.gapInsets(l: 22, t: 16, r: 22),
                      child: Text(SocialStringsA.starNote, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
