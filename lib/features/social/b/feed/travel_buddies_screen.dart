import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../controllers/location_controller.dart';
import '../../../../controllers/notification_controller.dart';
import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../shared/data/follow_api.dart';
import '../../shared/social_live.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../a/people/discover/discover_rail.dart';
import '../social_nav_b.dart';
import '../social_strings_b.dart';
import '../widgets/find_buddies_post_card.dart';
import '../widgets/sliding_tabs.dart';
import 'explore_tab.dart';
import 'feed_filter_sheet.dart';
import 'my_posts_controller.dart';
import 'my_posts_tab.dart';
import 'travel_buddies_controller.dart';

class TravelBuddiesScreen extends StatefulWidget {
  const TravelBuddiesScreen({super.key, this.posted = false, this.myPosts = false});

  final bool posted;
  final bool myPosts;

  static const Key filterKey = ValueKey('feed_filter');
  static const Key bellKey = ValueKey('feed_bell');
  static const Key postKey = ValueKey('feed_post_trip');
  static const Key postHintKey = ValueKey('feed_post_hint');
  static const Key searchKey = ValueKey('feed_search');
  static const Key liveKey = ValueKey('feed_live');
  static const Key liveCloseKey = ValueKey('feed_live_close');
  static const Key railKey = ValueKey('feed_discover_rail');
  static const Key tabsKey = ValueKey('groups_tabs');
  static const Key exploreKey = ValueKey('groups_explore');
  static const Key mineKey = ValueKey('groups_mine');
  static const Key mineEmptyKey = ValueKey('groups_mine_empty');
  static const int tabExplore = 0;
  static const int tabMine = 1;
  static const int railAfter = 2;
  static const int railSize = 5;

  @override
  State<TravelBuddiesScreen> createState() => _TravelBuddiesScreenState();
}

class _TravelBuddiesScreenState extends State<TravelBuddiesScreen> {
  late final String _tag = 'travel-buddies-${identityHashCode(this)}';
  late final TravelBuddiesController c;
  late final MyPostsController mine;
  late int _tab = widget.posted || widget.myPosts ? TravelBuddiesScreen.tabMine : TravelBuddiesScreen.tabExplore;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  Worker? _ready;
  Worker? _nearFailed;
  Worker? _postedAgain;
  Worker? _followChange;
  bool _snackShown = false;
  String? _liveTitle;
  String? _liveNote;
  bool _live = false;
  Timer? _liveTimer;
  final _rail = <DiscoverPerson>[].obs;
  int _railGen = 0;

  @override
  void initState() {
    super.initState();
    SocialNavB.feedOpened();
    c = Get.put(TravelBuddiesController(), tag: _tag);
    mine = Get.put(MyPostsController(), tag: _tag);
    _scroll.addListener(_onScroll);
    _postedAgain = ever<int>(SocialNavB.posted, (_) => _afterPost());
    if (widget.posted) {
      _ready = ever<FeedLoad>(mine.state, (_) => _showLive());
      WidgetsBinding.instance.addPostFrameCallback((_) => _showLive());
    }
    _loadRail();
    _followChange = ever<(String, bool, bool)?>(SocialLive.followChange, (e) {
      if (e == null) return;
      _railFollowChanged(e.$1, e.$2, e.$3);
      c.applyFollow(e.$1, e.$2);
    });
    _nearFailed = ever<String?>(c.nearFailed, (m) {
      if (m != null && mounted) BuddySnack.show(context, m, danger: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _liveTimer?.cancel();
    _ready?.dispose();
    _nearFailed?.dispose();
    _postedAgain?.dispose();
    _followChange?.dispose();
    SocialNavB.feedClosed();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    Get.delete<TravelBuddiesController>(tag: _tag);
    Get.delete<MyPostsController>(tag: _tag);
    super.dispose();
  }

  void _showLive() {
    if (_snackShown || !mounted || mine.state.value != FeedLoad.ready) return;
    _snackShown = true;
    final city = mine.items.isEmpty || mine.items.first.cityNames.isEmpty ? null : mine.items.first.cityNames.first;
    final note = SocialNavB.takePostedNote();
    setState(() {
      _liveTitle = city == null ? null : SocialStringsB.liveTitle(city);
      _liveNote = note;
      _live = true;
    });
    _liveTimer?.cancel();
    _liveTimer = Timer(BuddySnack.duration * 2, _hideLive);
  }

  void _hideLive() {
    _liveTimer?.cancel();
    if (mounted && _live) setState(() => _live = false);
  }

  Widget _liveCard() {
    final title = _liveTitle;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: TravelBuddiesScreen.liveKey,
        padding: DS.insets(l: 14, t: 12, r: 4, b: 12),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: DS.shadows(Form3D.cardShadow)),
        child: Row(
          children: [
            Container(
              width: DS.s(36),
              height: DS.s(36),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: BuddyLook.teal.gradient),
              child: Icon(Icons.check_rounded, size: DS.s(20), color: DesignColors.onPrimary),
            ),
            Gap.h(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                  Text(_liveNote ?? SocialStringsB.liveBody, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                ],
              ),
            ),
            Tap3D(
              tapKey: TravelBuddiesScreen.liveCloseKey,
              onTap: _hideLive,
              label: SocialStringsB.close,
              exclude: true,
              child: SizedBox(
                width: DS.s(KitMetrics.touch),
                height: DS.s(KitMetrics.touch),
                child: Icon(Icons.close_rounded, size: DS.s(22), color: Form3D.hint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _afterPost() async {
    if (!mounted) return;
    _snackShown = false;
    setState(() => _tab = TravelBuddiesScreen.tabMine);
    _loadRail();
    unawaited(c.load());
    await mine.load();
    _showLive();
  }

  Future<void> _loadRail() async {
    final gen = ++_railGen;
    final r = await const FollowApi().discover(limit: TravelBuddiesScreen.railSize);
    if (gen != _railGen || !mounted) return;
    _rail.assignAll(switch (r) {
      BuddyOk<DiscoverPage>(:final value) => value.items,
      _ => const <DiscoverPerson>[],
    });
  }

  Future<void> _refresh() => Future.wait<void>([c.load(), _loadRail()]);

  void _clearFilters() {
    _search.clear();
    c.applyFilter(FeedFilter.none);
  }

  void _selectTab(int i) {
    if (i == _tab) return;
    FocusScope.of(context).unfocus();
    setState(() => _tab = i);
  }

  void _railFollowChanged(String userId, bool iFollow, bool requested) {
    final i = _rail.indexWhere((p) => p.userId == userId);
    if (i != -1) _rail[i] = _rail[i].copyWith(iFollow: iFollow, followRequested: requested);
  }

  Widget _discoverRail(List<DiscoverPerson> people) => KeyedSubtree(
        key: TravelBuddiesScreen.railKey,
        child: DiscoverRail(
          people: people,
          onSeeAll: () => SocialNav.openPeople(tab: 'discover'),
          onFollowChanged: _railFollowChanged,
          margin: DS.gapInsets(l: 18, r: 18, b: 16),
        ),
      );

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent - DS.s(300)) c.loadMore();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => c.setQuery(v));
  }

  Future<void> _openFilter() async {
    final limits = SocialMeController.maybe?.me.value?.limits;
    final picked = await FeedFilterSheet.show(context, initial: c.filter.value.copyWith(q: _search.text.trim()), nearMe: limits?.nearMe ?? false);
    if (picked == null || !mounted) return;
    var f = picked;
    if (f.near) {
      final loc = Get.isRegistered<LocationController>() ? Get.find<LocationController>().userLocation.value : null;
      if (loc == null) {
        BuddySnack.show(context, SocialStringsB.nearMeNoLocation, danger: true);
        f = f.copyWith(near: false);
      } else {
        c.setLocation(loc.latitude, loc.longitude);
      }
    }
    if (_search.text.trim() != f.q) _search.text = f.q;
    await c.applyFilter(f);
  }

  Future<void> _postTrip() => PostTripEntry.open(context);

  Widget _bell() {
    final ctrl = Get.isRegistered<NotificationController>() ? Get.find<NotificationController>() : null;
    // Same 3D header icon as the Trip overview chat button on a gradient band (mock D9b: coloured 3D bell, not a grey glyph).
    final button = Tap3D(
      tapKey: TravelBuddiesScreen.bellKey,
      onTap: () => Get.toNamed(AppRoutes.notifications),
      label: SocialStringsB.notificationsLabel,
      child: Container(
        width: DS.s(44),
        height: DS.s(44),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: DesignColors.tint(DesignColors.onPrimary, Alpha.v22), shape: BoxShape.circle),
        child: const ExcludeSemantics(child: Art3D(asset: ListingArt.bell, size: 28, shadowBlur: 2, shadowOffset: Offset(1, 2))),
      ),
    );
    if (ctrl == null) return button;
    return Obx(() {
      final n = ctrl.unreadCount.value;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          if (n > 0)
            Positioned(
              right: DS.s(2),
              top: DS.s(2),
              child: IgnorePointer(
                child: Container(
                  constraints: BoxConstraints(minWidth: DS.s(20)),
                  padding: DS.sym(h: 5, v: 1),
                  decoration: BoxDecoration(color: BuddyLook.countBadge, borderRadius: DS.circular(10)),
                  child: Text(n > 99 ? '99+' : '$n', textAlign: TextAlign.center, style: Ink3D.text(11, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _searchRow() {
    final tone = ListingTone.indigo;
    return Padding(
      padding: DS.gapInsets(l: 18, t: 12, r: 18, b: 4),
      child: Row(
        children: [
          Expanded(
            child: SheetSearchField(
              key: TravelBuddiesScreen.searchKey,
              tone: tone,
              controller: _search,
              hint: SocialStringsB.searchHint,
              leadingArt: ListingArt.search,
              inputFormatters: noEmojiInputFormatters,
              onChanged: _onSearch,
              margin: EdgeInsets.zero,
            ),
          ),
          Gap.h(10),
          Obx(() {
            final n = c.filter.value.count;
            return Tap3D(
              tapKey: TravelBuddiesScreen.filterKey,
              onTap: _openFilter,
              label: SocialStringsB.filters,
              exclude: true,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: DS.s(52),
                    height: DS.s(52),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: tone.gradient, boxShadow: tone.glow(dy: 5, blur: 10)),
                    child: Icon(Icons.tune_rounded, size: DS.s(24), color: DesignColors.onPrimary),
                  ),
                  if (n > 0)
                    Positioned(
                      right: -DS.s(2),
                      top: -DS.s(2),
                      child: Container(
                        width: DS.s(20),
                        height: DS.s(20),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: BuddyLook.countBadge, shape: BoxShape.circle),
                        child: Text('$n', style: Ink3D.text(11, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _postBar() {
    final me = SocialMeController.maybe;
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(12), DS.s(18), DS.s(16) + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: DesignColors.surface, boxShadow: DS.shadows(Ink3D.topEdge)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientPillButton(key: TravelBuddiesScreen.postKey, tone: ListingTone.indigo, icon: Icons.add_rounded, label: SocialStringsB.postYourTrip, onTap: _postTrip),
          if (me != null)
            Obx(() {
              final l = me.me.value?.limits;
              final hint = SocialStringsB.postEntryHint(l);
              if (hint.isEmpty && (l == null || l.isPlus)) return const SizedBox.shrink();
              return Padding(
                padding: DS.gapInsets(l: 4, t: 8, r: 4),
                child: Text(
                  hint.isEmpty ? SocialStringsB.freeLine(l!) : hint,
                  key: hint.isEmpty ? null : TravelBuddiesScreen.postHintKey,
                  textAlign: TextAlign.center,
                  style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BuddyPage(
      title: SocialStringsB.travelGroups,
      subtitle: SocialStringsB.travelGroupsSub,
      trailing: [_bell()],
      top: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SlidingTabs(
            key: TravelBuddiesScreen.tabsKey,
            labels: const [SocialStringsB.tabExplore, SocialStringsB.tabMyPosts],
            selected: _tab,
            onTap: _selectTab,
            tone: ListingTone.indigo,
            margin: DS.gapInsets(l: 18, t: 12, r: 18),
          ),
          if (_tab == TravelBuddiesScreen.tabExplore) _searchRow(),
        ],
      ),
      scroll: false,
      bottomBar: _postBar(),
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: _tab,
            sizing: StackFit.expand,
            children: [
              ExploreTab(
                c: c,
                mine: mine,
                rail: _rail,
                scroll: _scroll,
                onRefresh: _refresh,
                onClearFilters: _clearFilters,
                railBuilder: _discoverRail,
              ),
              MyPostsTab(c: mine),
            ],
          ),
          if (_live)
            Positioned(
              left: DS.s(18),
              right: DS.s(18),
              bottom: DS.s(16),
              child: _liveCard(),
            ),
        ],
      ),
    );
  }
}
