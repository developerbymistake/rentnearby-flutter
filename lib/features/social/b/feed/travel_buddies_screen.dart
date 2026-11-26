import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../config/app_routes.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/location_controller.dart';
import '../../../../controllers/notification_controller.dart';
import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/buddy_page.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../shared/social_error_types.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/plus_widgets.dart';
import '../../shared/widgets/public_trip_card.dart';
import '../post/join_request_sheet.dart';
import '../post/trip_post_actions.dart';
import '../../a/people/people_widgets.dart';
import '../../a/widgets/social_chips_a.dart';
import '../social_nav_b.dart';
import '../social_strings_b.dart';
import '../widgets/social_widgets_b.dart';
import 'feed_filter_sheet.dart';
import 'travel_buddies_controller.dart';

class TravelBuddiesScreen extends StatefulWidget {
  const TravelBuddiesScreen({super.key, this.posted = false});

  final bool posted;

  static const Key filterKey = ValueKey('feed_filter');
  static const Key bellKey = ValueKey('feed_bell');
  static const Key postKey = ValueKey('feed_post_trip');
  static const Key searchKey = ValueKey('feed_search');
  static const Key liveKey = ValueKey('feed_live');
  static const Key liveCloseKey = ValueKey('feed_live_close');

  static String myGender() {
    final p = SocialMeController.maybe?.profile;
    if (p != null && p.gender.isNotEmpty) return p.gender;
    return Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.gender ?? '' : '';
  }

  @override
  State<TravelBuddiesScreen> createState() => _TravelBuddiesScreenState();
}

class _TravelBuddiesScreenState extends State<TravelBuddiesScreen> {
  late final String _tag = 'travel-buddies-${identityHashCode(this)}';
  late final TravelBuddiesController c = Get.put(TravelBuddiesController(), tag: _tag);
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  Worker? _ready;
  Worker? _nearFailed;
  Worker? _postedAgain;
  bool _snackShown = false;
  String? _liveTitle;
  bool _live = false;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    SocialNavB.feedOpened();
    _scroll.addListener(_onScroll);
    _postedAgain = ever<int>(SocialNavB.posted, (_) => _afterPost());
    if (widget.posted) {
      _ready = ever<FeedLoad>(c.state, (_) => _showLive());
      WidgetsBinding.instance.addPostFrameCallback((_) => _showLive());
    }
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
    SocialNavB.feedClosed();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    Get.delete<TravelBuddiesController>(tag: _tag);
    super.dispose();
  }

  void _showLive() {
    if (_snackShown || !mounted || c.state.value != FeedLoad.ready) return;
    _snackShown = true;
    final city = c.mine.isEmpty || c.mine.first.cityNames.isEmpty ? null : c.mine.first.cityNames.first;
    setState(() {
      _liveTitle = city == null ? null : SocialStringsB.liveTitle(city);
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
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(16), boxShadow: DS.shadows(Form3D.cardShadow)),
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
                  Text(SocialStringsB.liveBody, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
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
    await c.load();
    _showLive();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - DS.s(300)) c.loadMore();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => c.setQuery(v));
  }

  Future<void> _openFilter() async {
    final limits = SocialMeController.maybe?.me.value?.limits;
    final picked = await FeedFilterSheet.show(context, initial: c.filter.value.copyWith(q: _search.text.trim()), myGender: TravelBuddiesScreen.myGender(), nearMe: limits?.nearMe ?? false);
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

  Future<void> _postTrip() async {
    final limits = SocialMeController.maybe?.me.value?.limits;
    if (limits != null && limits.publicTrips.reached) {
      await PlusSheets.limitReached(context, errorType: SocialErrorTypes.publicTripLimit, data: {'limit': limits.publicTrips.limit}, from: 'post');
      return;
    }
    if (limits != null && limits.activeTrips.reached) {
      await PlusSheets.limitReached(context, errorType: SocialErrorTypes.tripLimitReached, data: {'limit': limits.activeTrips.limit}, from: 'post');
      return;
    }
    await SocialNav.openPostTrip();
  }

  Future<void> _request(PublicTrip t) async {
    final ok = await JoinRequestSheet.show(context, t);
    if (!ok || !mounted) return;
    c.applyMyJoin(t.tripId, 'requested');
    BuddySnack.show(context, SocialStringsB.requestSent);
  }

  Widget _bell() {
    final ctrl = Get.isRegistered<NotificationController>() ? Get.find<NotificationController>() : null;
    final button = KitRoundButton(key: TravelBuddiesScreen.bellKey, icon: Icons.notifications_none_rounded, onTap: () => Get.toNamed(AppRoutes.notifications));
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

  Widget _postButton() {
    final me = SocialMeController.maybe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: DS.gapInsets(l: 18, t: 4, r: 18, b: 8),
          child: GradientPillButton(key: TravelBuddiesScreen.postKey, tone: ListingTone.indigo, icon: Icons.add_rounded, label: SocialStringsB.postYourTrip, onTap: _postTrip),
        ),
        if (me != null)
          Obx(() {
            final l = me.me.value?.limits;
            if (l == null || l.isPlus) return const SizedBox.shrink();
            return Padding(
              padding: DS.gapInsets(l: 22, r: 22, b: 12),
              child: Text(SocialStringsB.freeLine(l), textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
            );
          }),
      ],
    );
  }

  Widget _footer(PublicTrip t) {
    final teal = BuddyLook.teal;
    if (t.isMine) {
      final n = t.waitingRequests ?? 0;
      if (n <= 0) {
        return Text(SocialStringsB.noRequestsYet, textAlign: TextAlign.center, style: Ink3D.text(13.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0));
      }
      return GradientPillButton(
        tone: teal,
        label: SocialStringsB.requests(n),
        height: SocialButtonsA.midHeight,
        fontSize: SocialButtonsA.midFont,
        onTap: () => SocialNav.openJoinRequests(t.tripId),
      );
    }
    switch (t.myJoin) {
      case 'requested':
        return WhitePillButton(
          tone: ListingTone.indigo,
          neutral: true,
          icon: Icons.check_rounded,
          label: SocialStringsB.requested,
          height: SocialButtonsA.midHeight,
          fontSize: SocialButtonsA.midFont,
          onTap: () => SocialNav.openTripPost(t.tripId),
        );
      case 'member':
        return WhitePillButton(
          tone: teal,
          label: SocialStringsB.openTrip,
          height: SocialButtonsA.midHeight,
          fontSize: SocialButtonsA.midFont,
          onTap: () => Get.toNamed(AppRoutes.tripView, arguments: {'tripId': t.tripId}),
        );
      case 'declined':
        return GradientPillButton(tone: teal, label: SocialStringsB.notThisTime, enabled: false, height: SocialButtonsA.midHeight, fontSize: SocialButtonsA.midFont, onTap: null);
    }
    if (t.seatsLeft <= 0) {
      return GradientPillButton(tone: teal, label: SocialStringsB.full, enabled: false, height: SocialButtonsA.midHeight, fontSize: SocialButtonsA.midFont, onTap: null);
    }
    return GradientPillButton(
      key: ValueKey('feed_request_${t.tripId}'),
      tone: teal,
      label: SocialStringsB.requestToJoin,
      height: SocialButtonsA.midHeight,
      fontSize: SocialButtonsA.midFont,
      onTap: () => _request(t),
    );
  }

  Widget _card(PublicTrip t) => Padding(
        padding: DS.gapInsets(l: 18, r: 18, b: 16),
        child: PublicTripCard(
          key: ValueKey('feed-${t.tripId}'),
          trip: t,
          onTap: () => SocialNav.openTripPost(t.tripId),
          footer: _footer(t),
          onMenu: t.isMine ? null : () => TripPostActions.showMenu(context, trip: t, onBlocked: () => c.removeOwner(t.owner.userId)),
        ),
      );

  Widget _state(Widget card) => Padding(padding: DS.gapInsets(t: 24, b: 24), child: card);

  Widget _body() {
    return Obx(() {
      final st = c.state.value;
      final mine = c.mine.toList();
      final items = c.items.toList();
      final f = c.filter.value;
      final children = <Widget>[
        if (mine.isEmpty) const PlusBanner(from: 'feed'),
        _postButton(),
        for (final t in mine) _card(t),
      ];
      switch (st) {
        case FeedLoad.loading:
          children.addAll([
            for (var i = 0; i < 2; i++)
              Padding(padding: DS.gapInsets(l: 18, r: 18, b: 16), child: SkeletonBox(height: DS.s(300), borderRadius: SocialLookB.cardRadius)),
          ]);
        case FeedLoad.offline:
          children.add(_state(StateCard.error(title: SocialStrings.offline, actionLabel: SocialStrings.retry, onAction: c.load)));
        case FeedLoad.failed:
          children.add(_state(StateCard.error(title: SocialStrings.failed, actionLabel: SocialStrings.retry, onAction: c.load)));
        case FeedLoad.ready:
          if (items.isEmpty) {
            final filtered = f.count > 0;
            children.add(_state(StateCard(
              title: filtered ? (f.q.trim().isNotEmpty ? SocialStringsB.noMatch(f.q.trim()) : SocialStringsB.noMatchFilters) : SocialStringsB.feedEmptyTitle,
              message: filtered ? null : SocialStringsB.feedEmptyBody,
              asset: ListingArt.panda,
              actionLabel: filtered ? SocialStringsB.clearFilters : null,
              onAction: filtered
                  ? () {
                      _search.clear();
                      c.applyFilter(FeedFilter.none);
                    }
                  : null,
            )));
          } else {
            children.addAll([for (final t in items) _card(t)]);
            if (c.loadingMore.value) children.add(Padding(padding: DS.gapInsets(b: 20), child: const LoadMoreFooter(loading: true)));
          }
      }
      return RefreshIndicator(
        color: ListingTone.indigo.g2,
        onRefresh: c.load,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: DS.s(40) + MediaQuery.paddingOf(context).bottom),
          children: children,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BuddyPage(
      title: SocialStringsB.travelBuddies,
      trailing: [_bell()],
      top: _searchRow(),
      scroll: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _body(),
          if (_live)
            Positioned(
              left: DS.s(18),
              right: DS.s(18),
              bottom: DS.s(24) + MediaQuery.paddingOf(context).bottom,
              child: _liveCard(),
            ),
        ],
      ),
    );
  }
}
