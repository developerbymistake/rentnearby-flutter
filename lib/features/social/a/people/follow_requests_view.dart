import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../buddy/buddies/models/buddy_models.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../buddy/shared/widgets/note_banner.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/widgets/person_actions.dart';
import '../social_strings_a.dart';
import '../widgets/social_chips_a.dart';
import 'people_controller.dart';
import 'people_widgets.dart';

class FollowRequestsView extends StatelessWidget {
  const FollowRequestsView({super.key, required this.c});

  final PeopleController c;

  Future<void> _answer(BuildContext context, PersonRow r, bool accept) async {
    final error = await c.answerRequest(r.person.userId, accept: accept);
    if (error != null && context.mounted) BuddySnack.show(context, error, danger: true);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = c.requests;
      final items = list.items.toList();
      final state = PeopleStates.of(list.state.value,
          empty: items.isEmpty, emptyTitle: SocialStringsA.noRequests, emptyLine: SocialStringsA.requestsNote, onRetry: c.loadRequests);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state != null)
            state
          else ...[
            Gap.v(16),
            PeopleCard(children: [
              for (final r in items)
                SocialPersonTile(
                  key: ValueKey('request_${r.person.userId}'),
                  person: r.person,
                  subtitle: SocialStringsA.wantsToFollow,
                  mutualText: SocialPersonTile.mutualOf(r),
                  onTap: () => SocialNav.openTraveller(r.person.userId),
                  onMenu: () => PersonActions.showMenu(context,
                      person: r.person, contextName: BuddyContext.profile, onBlocked: () => c.onBlocked(r.person.userId)),
                  actions: Row(
                    children: [
                      Expanded(
                        child: GradientPillButton(
                          key: ValueKey('accept_${r.person.userId}'),
                          tone: BuddyLook.teal,
                          label: SocialStringsA.accept,
                          height: SocialButtonsA.midHeight,
                          fontSize: SocialButtonsA.midFont,
                          onTap: () => _answer(context, r, true),
                        ),
                      ),
                      Gap.h(12),
                      Expanded(
                        child: WhitePillButton(
                          key: ValueKey('decline_${r.person.userId}'),
                          tone: ListingTone.indigo,
                          label: SocialStringsA.decline,
                          neutral: true,
                          height: SocialButtonsA.midHeight,
                          fontSize: SocialButtonsA.midFont,
                          onTap: () => _answer(context, r, false),
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
            LoadMoreFooter(loading: list.loadingMore.value),
            const NoteBanner(art: BuddyArt.locked, text: SocialStringsA.requestsNote),
          ],
        ],
      );
    });
  }
}
