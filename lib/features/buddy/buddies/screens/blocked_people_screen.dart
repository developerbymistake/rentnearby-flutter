import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_avatar.dart';
import '../../shared/widgets/buddy_page.dart';
import '../../shared/widgets/note_banner.dart';
import '../../shared/widgets/person_row.dart';
import '../../shared/widgets/small_pill.dart';
import '../buddies_strings.dart';
import '../controllers/blocked_people_controller.dart';
import '../controllers/buddies_controller.dart';
import '../data/buddies_api.dart';
import '../widgets/buddy_empty_state.dart';
import '../widgets/my_buddies_tab.dart';

class BlockedPeopleScreen extends StatefulWidget {
  const BlockedPeopleScreen({super.key, this.api = const BuddiesApi()});

  final BuddiesApi api;

  @override
  State<BlockedPeopleScreen> createState() => _BlockedPeopleScreenState();
}

class _BlockedPeopleScreenState extends State<BlockedPeopleScreen> {
  late final String _tag = 'blocked-${identityHashCode(this)}';
  late final BlockedPeopleController _c = Get.put(BlockedPeopleController(api: widget.api), tag: _tag);

  @override
  void dispose() {
    Get.delete<BlockedPeopleController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 200) _c.loadMore();
          return false;
        },
        child: Obx(() {
          final ready = _c.state.value == BuddyListState.ready;
          final empty = ready && _c.items.isEmpty;
          final total = _c.count.value > _c.items.length ? _c.count.value : _c.items.length;
          return BuddyPage(
            title: BuddiesStrings.blockedTitle,
            subtitle: ready && !empty ? BuddiesStrings.people(total) : null,
            onBack: Get.back,
            body: switch (_c.state.value) {
              BuddyListState.loading => Padding(padding: EdgeInsets.only(top: DS.s(24)), child: const BuddyListSkeleton()),
              BuddyListState.failed => BuddyLoadFailed(onRetry: _c.load),
              BuddyListState.ready when empty => const BuddyEmptyState(art: BuddyArt.shield, title: BuddiesStrings.noOneBlocked),
              BuddyListState.ready => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PersonListCard(
                      margin: DS.insets(l: 18, t: 24, r: 18),
                      children: [
                        for (final p in _c.items)
                          PersonRow(
                            key: ValueKey('blocked-${p.userId}'),
                            avatar: BuddyAvatar(initial: p.initial, seed: p.userId),
                            title: p.name,
                            subtitle: BuddiesStrings.blockedLine(p.username ?? '', p.blockedAt == null ? '' : BuddyFormat.dayMonth(p.blockedAt!.toLocal())),
                            trailing: SmallPill(label: BuddiesStrings.unblock, busy: _c.busy.contains(p.userId), onTap: () => _c.unblock(p.userId)),
                          ),
                      ],
                    ),
                    if (_c.loadingMore.value) Padding(padding: EdgeInsets.only(top: DS.s(12)), child: const BuddyListSkeleton()),
                    NoteBanner(art: BuddyArt.shield, text: BuddiesStrings.blockedNote, tone: NoteTone.teal, margin: DS.insets(l: 18, t: 28, r: 18)),
                  ],
                ),
            },
          );
        }),
      );
}
