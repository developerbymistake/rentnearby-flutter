import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../design/design.dart';
import '../../../buddy/buddies/models/buddy_models.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_avatar.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../buddy/shared/widgets/note_banner.dart';
import '../../../buddy/shared/widgets/segment_tabs.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/follow_button.dart';
import '../../shared/widgets/person_actions.dart';
import '../social_strings_a.dart';
import '../widgets/social_chips_a.dart';
import 'discover/discover_view.dart';
import 'follow_requests_view.dart';
import 'people_controller.dart';
import 'people_find.dart';
import 'people_widgets.dart';
import 'scan_to_follow.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, this.tab = PeopleController.tabDiscover, this.scanToFollow = const ScanToFollow()});

  final String tab;
  final ScanToFollow scanToFollow;

  static const Key requestsRowKey = ValueKey('people_requests_row');
  static const Key scanQrKey = PeopleFindSection.scanKey;
  static const Key addFromFollowersKey = ValueKey('people_add_from_followers');
  static const List<String> tabLabels = [SocialStringsA.discoverTab, ...SocialStringsA.peopleTabs];

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  late final String _tag = 'people-${identityHashCode(this)}';
  late final PeopleController c = Get.put(PeopleController(tab: widget.tab), tag: _tag);

  @override
  void dispose() {
    Get.delete<PeopleController>(tag: _tag);
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - DS.s(300)) {
      if (c.requestsOnly) {
        c.loadRequests(more: true);
      } else {
        c.loadTab(c.selected.value, more: true);
      }
    }
    return false;
  }

  void _snack(String? error) {
    if (error != null && mounted) BuddySnack.show(context, error, danger: true);
  }

  String get _myName => Get.isRegistered<AuthController>() ? Get.find<AuthController>().profileName.value : '';

  @override
  Widget build(BuildContext context) {
    if (c.requestsOnly) {
      return Obx(() => BuddyPage(
            title: SocialStringsA.requests,
            subtitle: SocialStringsA.waiting(c.requests.total.value),
            body: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: SingleChildScrollView(padding: EdgeInsets.only(bottom: DS.s(24)), child: FollowRequestsView(c: c)),
            ),
            scroll: false,
          ));
    }
    return BuddyPage(
      title: SocialStringsA.peopleTitle,
      subtitle: _myName,
      scroll: false,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: RefreshIndicator(
          onRefresh: c.pullRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: PeopleFindSection(api: widget.scanToFollow.api, onScan: () => widget.scanToFollow.start(context))),
              SliverToBoxAdapter(child: _requestsRow()),
              SliverToBoxAdapter(
                child: Obx(() => SegmentTabs(
                      labels: PeopleScreen.tabLabels,
                      selected: c.selected.value,
                      onTap: c.select,
                      tone: ListingTone.indigo,
                      margin: DS.gapInsets(l: 18, t: 22, r: 18),
                    )),
              ),
              Obx(() => switch (c.selectedTab) {
                    PeopleController.tabDiscover => DiscoverSliver(c: c.discover),
                    PeopleController.tabFollowing => SliverToBoxAdapter(child: _following()),
                    PeopleController.tabBuddies => SliverToBoxAdapter(child: _buddies()),
                    _ => SliverToBoxAdapter(child: _followers()),
                  }),
              SliverToBoxAdapter(child: SizedBox(height: DS.s(24))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _requestsRow() => Obx(() {
        final total = c.requests.total.value;
        final items = c.requests.items.toList();
        if (total <= 0 || items.isEmpty) return const SizedBox.shrink();
        final first = items.first.person.shortName;
        return Padding(
          padding: DS.gapInsets(l: 18, t: 16, r: 18),
          child: Tap3D(
            tapKey: PeopleScreen.requestsRowKey,
            onTap: () => SocialNav.openPeople(tab: PeopleController.tabRequests),
            label: '${SocialStringsA.requests} $total',
            exclude: true,
            child: Container(
              padding: DS.sym(h: 16, v: 14),
              decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: BuddyLook.cardShadows(DS.size)),
              child: Row(
                children: [
                  BuddyAvatarStack(
                    people: [for (final r in items.take(2)) (initial: r.person.initial, seed: r.person.userId, photoUrl: r.person.photoUrl)],
                    max: 2,
                  ),
                  Gap.h(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(SocialStringsA.requests, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                          Gap.h(8),
                          Container(
                            padding: DS.sym(h: 7, v: 1),
                            constraints: BoxConstraints(minWidth: DS.s(24)),
                            decoration: BoxDecoration(color: BuddyLook.countBadge, borderRadius: DS.circular(12)),
                            child: Text('$total', textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
                          ),
                        ]),
                        Text(SocialStringsA.requestsLine(first, total),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: DS.s(22), color: BuddyLook.chevron),
                ],
              ),
            ),
          ),
        );
      });

  Future<void> _rowMenu(PersonRow r, {required bool follower}) => PersonActions.showMenu(
        context,
        person: r.person,
        contextName: BuddyContext.profile,
        onBlocked: () => c.onBlocked(r.person.userId),
        extra: [
          if (follower)
            PersonMenuItem(
              art: BuddyArt.panda,
              title: SocialStringsA.removeFollower,
              subtitle: SocialStringsA.removeFollowerLine,
              onSelected: () async => _snack(await c.removeFollower(r.person.userId)),
            ),
          if (r.isBuddy)
            PersonMenuItem(
              art: ListingArt.star,
              title: SocialStringsA.removeBuddy,
              subtitle: SocialStringsA.removeBuddyLine,
              onSelected: () async => _snack(await c.removeBuddy(r.person.userId)),
            ),
        ],
      );

  Widget _personRows(List<PersonRow> items, {required bool follower}) => PeopleCard(children: [
        for (final r in items)
          SocialPersonTile(
            key: ValueKey('${follower ? 'follower' : 'following'}_${r.person.userId}'),
            person: r.person,
            subtitle: SocialPersonTile.relationLine(followsMe: r.followsMe, iFollow: r.iFollow),
            mutualText: SocialPersonTile.mutualOf(r),
            star: r.isBuddy,
            onTap: () => SocialNav.openTraveller(r.person.userId),
            onMenu: () => _rowMenu(r, follower: follower),
            actions: Align(
              alignment: Alignment.centerLeft,
              child: FollowButton(
                userId: r.person.userId,
                iFollow: r.iFollow,
                followRequested: r.followRequested,
                followsMe: r.followsMe,
                compact: true,
                onChanged: (f, q) => c.onFollowChanged(r.person.userId, f, q),
              ),
            ),
          ),
      ]);

  Widget _followers() => Obx(() {
        final list = c.followers;
        final items = list.items.toList();
        final state = PeopleStates.of(list.state.value,
            empty: items.isEmpty, emptyTitle: SocialStringsA.noFollowers, emptyLine: SocialStringsA.noFollowersLine, onRetry: () => c.loadKey(PeopleController.tabFollowers));
        if (state != null) return state;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PeopleLabel(SocialStringsA.followersCount(list.total.value)),
          _personRows(items, follower: true),
          LoadMoreFooter(loading: list.loadingMore.value),
        ]);
      });

  Widget _following() => Obx(() {
        final list = c.following;
        final items = list.items.toList();
        final state = PeopleStates.of(list.state.value,
            empty: items.isEmpty, emptyTitle: SocialStringsA.noFollowing, emptyLine: SocialStringsA.noFollowingLine, onRetry: () => c.loadKey(PeopleController.tabFollowing));
        if (state != null) return state;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PeopleLabel(SocialStringsA.followingCount(list.total.value)),
          _personRows(items, follower: false),
          LoadMoreFooter(loading: list.loadingMore.value),
        ]);
      });

  Widget _addRow() => _actionRow(
        key: PeopleScreen.addFromFollowersKey,
        icon: Icons.add_rounded,
        title: SocialStringsA.addFromFollowers,
        line: SocialStringsA.onlyYouSee,
        top: 24,
        onTap: () async {
          await SocialNav.openAddBuddies();
          c.loadKey(PeopleController.tabBuddies);
        },
      );

  Widget _actionRow({required Key key, required IconData icon, required String title, required String line, required double top, required VoidCallback onTap}) => Padding(
        padding: DS.gapInsets(l: 18, t: top, r: 18),
        child: Tap3D(
          tapKey: key,
          onTap: onTap,
          label: title,
          exclude: true,
          child: Container(
            padding: DS.sym(h: 16, v: 14),
            decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: BuddyLook.cardShadows(DS.size)),
            child: Row(
              children: [
                Container(
                  width: DS.s(44),
                  height: DS.s(44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: BuddyLook.snackAction.withValues(alpha: Alpha.v40)),
                  child: Icon(icon, size: DS.s(24), color: BuddyLook.amberText),
                ),
                Gap.h(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                      Text(line, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: DS.s(22), color: BuddyLook.chevron),
              ],
            ),
          ),
        ),
      );

  Widget _buddies() => Obx(() {
        final list = c.buddies;
        final items = list.items.toList();
        final state = PeopleStates.of(list.state.value,
            empty: items.isEmpty, emptyTitle: SocialStringsA.noBuddies, emptyLine: SocialStringsA.noBuddiesLine, onRetry: () => c.loadKey(PeopleController.tabBuddies));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _addRow(),
          if (state != null)
            state
          else ...[
            PeopleLabel(SocialStringsA.buddiesCount(list.total.value)),
            PeopleCard(children: [
              for (final b in items)
                SocialPersonTile(
                  key: ValueKey('buddy_${b.userId}'),
                  person: SocialPerson(userId: b.userId, name: b.name, username: b.username, photoUrl: b.photoUrl, initial: b.initial, gender: b.gender),
                  subtitle: SocialStrings.buddyLine(b.tripsTogether),
                  mutualText: b.mutualCount > 0 ? SocialStrings.mutualCount(b.mutualCount) : null,
                  star: true,
                  onTap: () => SocialNav.openTraveller(b.userId),
                  onMenu: () => PersonActions.showMenu(
                    context,
                    person: SocialPerson(userId: b.userId, name: b.name, username: b.username, photoUrl: b.photoUrl, initial: b.initial),
                    contextName: BuddyContext.buddy,
                    onBlocked: () => c.onBlocked(b.userId),
                    extra: [
                      PersonMenuItem(
                        art: ListingArt.star,
                        title: SocialStringsA.removeBuddy,
                        subtitle: SocialStringsA.removeBuddyLine,
                        onSelected: () async => _snack(await c.removeBuddy(b.userId)),
                      ),
                    ],
                  ),
                  actions: Align(
                    alignment: Alignment.centerLeft,
                    child: WhitePillButton(
                      tone: ListingTone.indigo,
                      label: SocialStrings.message,
                      height: SocialButtonsA.smallHeight,
                      fontSize: SocialButtonsA.smallFont,
                      expand: false,
                      onTap: () => SocialNav.openDirectChat(userId: b.userId, name: b.name, photoUrl: b.photoUrl),
                    ),
                  ),
                ),
            ]),
            LoadMoreFooter(loading: list.loadingMore.value),
          ],
          const NoteBanner(art: BuddyArt.panda, text: SocialStringsA.buddiesNote),
        ]);
      });
}
