import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../design/design.dart';
import '../../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../shared/data/follow_api.dart';
import '../../../shared/social_me_controller.dart';
import '../../../shared/social_models.dart';
import '../../../shared/social_nav.dart';
import '../../social_strings_a.dart';
import '../people_widgets.dart';
import 'discover_card.dart';
import 'discover_chips.dart';
import 'discover_controller.dart';

/// Discover tab body as slivers: chips, header (or the Plus card of a locked Near you), 2-column cards, footer.
class DiscoverSliver extends StatelessWidget {
  const DiscoverSliver({super.key, required this.c, this.api = const FollowApi()});

  final DiscoverController c;
  final FollowApi api;

  static const Key plusCardKey = ValueKey('discover_near_plus');

  String _header(String chip) {
    if (chip == DiscoverChips.forYou) return SocialStringsA.travellersForYou;
    final trip = c.myTrip.value;
    if (chip == DiscoverChips.sameTrip && trip != null) return SocialStringsA.alsoGoingTo(trip.cityName, trip.month);
    return SocialStringsA.chipLabel(chip);
  }

  Future<void> _hide(BuildContext context, String userId) async {
    final error = await c.hide(userId);
    if (error != null && context.mounted) BuddySnack.show(context, error, danger: true);
  }

  Widget _plusCard() {
    final canUpgrade = SocialMeController.maybe?.limits.canUpgrade ?? true;
    return Padding(
      key: plusCardKey,
      padding: DS.gapInsets(l: 18, t: 16, r: 18),
      child: StateCard(
        title: SocialStringsA.nearLockedTitle,
        message: SocialStringsA.nearLockedLine,
        asset: ListingArt.roundPushpin,
        actionLabel: canUpgrade ? SocialStringsA.getPlus : null,
        onAction: canUpgrade ? () => SocialNav.openPlus(from: 'discoverNear') : null,
      ),
    );
  }

  Widget _row(BuildContext context, List<DiscoverPerson> items, int r) {
    Widget cell(int i) {
      if (i >= items.length) return const SizedBox.shrink();
      final p = items[i];
      return DiscoverCard(
        key: ValueKey('discover_card_${p.userId}'),
        item: p,
        reason: SocialStringsA.reasonLine(p.reason),
        api: api,
        onHide: () => _hide(context, p.userId),
        onFollowChanged: (f, q) => c.onFollowChanged(p.userId, f, q),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: r == 0 ? 0 : DS.gv(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: cell(r * 2)), Gap.h(10), Expanded(child: cell(r * 2 + 1))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final chip = c.chip.value;
        final locked = c.nearLocked;
        final showLock = chip == DiscoverChips.near && locked;
        final listChip = showLock ? DiscoverChips.forYou : chip;
        final list = c.lists[listChip]!;
        final items = list.items.toList();
        final state = PeopleStates.of(
          list.state.value,
          empty: items.isEmpty,
          emptyTitle: listChip == DiscoverChips.near ? SocialStringsA.noNearYou : SocialStringsA.noSuggestions,
          emptyLine: listChip == DiscoverChips.near ? null : SocialStringsA.noSuggestionsLine,
          onRetry: c.load,
        );
        final rows = (items.length + 1) ~/ 2;
        return SliverMainAxisGroup(slivers: [
          SliverToBoxAdapter(child: DiscoverChipsRow(selected: chip, nearLocked: locked, onSelect: c.selectChip)),
          if (showLock) SliverToBoxAdapter(child: _plusCard()),
          SliverToBoxAdapter(child: PeopleLabel(showLock ? SocialStringsA.chipForYou : _header(listChip))),
          if (state != null)
            SliverToBoxAdapter(child: state)
          else ...[
            SliverPadding(
              padding: DS.insets(l: 18, r: 18),
              sliver: SliverList.builder(itemCount: rows, itemBuilder: (_, r) => _row(context, items, r)),
            ),
            SliverToBoxAdapter(child: LoadMoreFooter(loading: list.loadingMore.value)),
          ],
        ]);
      });
}
