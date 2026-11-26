import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../config/shell_kind.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../features/social/c/chat/models/chat_models.dart';
import '../features/social/c/chat/rooms_controller.dart';
import '../features/social/c/chat/social_rooms_tabs.dart';
import '../features/social/c/social_strings_c.dart';
import '../features/social/c/widgets/icon_title_header.dart';
import '../features/social/shared/social_nav.dart';
import '../models/conversation_model.dart';
import '../utils/input_formatters.dart';
import '../utils/listing_kind_visuals.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});
  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _ctrl = Get.find<ChatController>();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final AnimationController _searchAnim =
      AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
  late final Animation<double> _searchSize = CurvedAnimation(parent: _searchAnim, curve: Curves.fastOutSlowIn);
  String _query = '';
  bool _searchOpen = false;
  Worker? _searchAutoFetchWorker;
  int _autoFetchCount = 0;
  static const _minFilteredForNoAutoFetch = 8;
  static const _maxAutoFetchPages = 5;
  late final RoomsController? _rooms = _socialRooms();

  static RoomsController? _socialRooms() {
    if (!Get.isRegistered<AuthController>()) return null;
    final auth = Get.find<AuthController>();
    if (auth.shellKind.value != ShellKind.seeker || !auth.canUseTravellerFeatures) return null;
    return RoomsController.maybe;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl.loadConversations();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        _ctrl.loadMoreConversations();
        _rooms?.loadMore(RoomBucket.people);
      }
    });
    _searchAutoFetchWorker = ever<List<ConversationModel>>(_ctrl.conversations, (_) => _maybeFetchMoreForSearch());
  }

  void _maybeFetchMoreForSearch() {
    if (!mounted) return;
    // Hidden enquiry-only rows can leave a page nearly empty: fetch on.
    if (_query.trim().isEmpty) {
      if (_ctrl.hasMoreConversations.value && !_ctrl.loadingMoreConversations.value && _ctrl.visibleConversations.length < _minFilteredForNoAutoFetch) {
        _ctrl.loadMoreConversations();
      }
      return;
    }
    if (_autoFetchCount >= _maxAutoFetchPages) return;
    if (!_ctrl.hasMoreConversations.value || _ctrl.loadingMoreConversations.value) return;
    if (_filtered(_ctrl.visibleConversations).length >= _minFilteredForNoAutoFetch) return;
    _autoFetchCount++;
    _ctrl.loadMoreConversations();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ctrl.loadConversations();
      _rooms?.reloadAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchAutoFetchWorker?.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _searchAnim.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _ctrl.loadConversations(forceRefresh: true);

  void _openConversation(ConversationModel c) {
    Get.toNamed(
      AppRoutes.chatConversation,
      arguments: {
        'conversationId': c.id,
        'listingType': c.listingType,
        'listingId': c.listingId,
        'stayTypeId': c.stayTypeId,
        'otherPartyId': c.otherPartyId,
        'otherPartyName': c.otherPartyName,
        'otherPartyPhotoUrl': c.otherPartyPhotoUrl,
        'listingTitle': c.listingTitle,
        'area': c.area,
        'isOwner': c.isOwner,
        'status': c.status,
        'isBlockedByMe': c.isBlockedByMe,
      },
    );
  }

  List<ConversationModel> _filtered(List<ConversationModel> items) {
    if (_query.trim().isEmpty) return items;
    final q = _query.trim().toLowerCase();
    return items
        .where(
          (c) =>
              c.otherPartyName.toLowerCase().contains(q) ||
              c.listingTitle.toLowerCase().contains(q) ||
              (c.area?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  static final ListingTone _tone = ListingTone.forest;

  void _toggleSearch() {
    final opening = !_searchOpen;
    setState(() {
      _searchOpen = opening;
      if (!opening) _query = '';
    });
    if (opening) {
      _searchAnim.forward();
    } else {
      _searchAnim.reverse();
      _searchCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KitStatusBar(
      lightIcons: false,
      child: Scaffold(
        backgroundColor: ListingPalette.forest.page,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              IconTitleHeader(
                tone: _tone,
                title: 'Messages',
                art: ListingArt.speechBalloon,
                onBack: () => Get.back(),
                trailing: ChatRoundButton3D(
                  icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  onTap: _toggleSearch,
                  tooltip: _searchOpen ? 'Close search' : 'Search',
                  tone: _tone,
                  gradient: true,
                  size: IconTitleHeader.button,
                ),
              ),
              Gap.v(14),
              SizeTransition(
                sizeFactor: _searchSize,
                alignment: Alignment.topCenter,
                child: FadeTransition(
                  opacity: _searchAnim,
                  child: (!_searchAnim.isDismissed || _searchOpen)
                      ? _buildSearchBox()
                      : const SizedBox(width: double.infinity),
                ),
              ),
              Expanded(
                child: _body(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final rooms = _rooms;
    if (rooms == null) return _listingList();
    return SocialRoomsTabs(rooms: rooms, people: (_, r) => _peopleList(r));
  }

  Widget _peopleList(RoomsController rooms) => Obx(() {
        final convs = _filtered(_ctrl.visibleConversations);
        final q = _query.trim().toLowerCase();
        final social = rooms.people.items.where((r) => q.isEmpty || (r.peer?.name.toLowerCase().contains(q) ?? false)).toList();
        final state = rooms.people.state.value;
        final loading = (_ctrl.conversationsLoading.value || state == RoomsLoad.loading || state == RoomsLoad.idle) && convs.isEmpty && social.isEmpty;
        if (loading) return _buildShimmer();
        if (convs.isEmpty && social.isEmpty) return q.isEmpty ? _buildSocialEmpty() : _buildNoMatches();
        final entries = <(DateTime, Widget)>[
          for (var i = 0; i < social.length; i++) (social[i].lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true), KeyedSubtree(key: ValueKey('room_${social[i].roomId}'), child: SocialPersonRoomRow(room: social[i], index: i))),
          for (final c in convs) (c.lastMessageAt, KeyedSubtree(key: ValueKey('conv_${c.id}'), child: _conversationCard(c))),
        ]..sort((a, b) => b.$1.compareTo(a.$1));
        final loadingMore = _ctrl.loadingMoreConversations.value || rooms.people.loadingMore.value;
        return RefreshIndicator(
          color: _tone.g2,
          backgroundColor: DesignColors.surface,
          onRefresh: () => Future.wait([_refresh(), rooms.load(RoomBucket.people)]),
          child: ListView.builder(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.only(bottom: DS.s(KitMetrics.gutter) + AppInsets.bottomViewPadding(context)),
            itemCount: entries.length + (loadingMore ? 1 : 0),
            itemBuilder: (_, i) {
              if (i >= entries.length) return _buildLoadMoreSpinner();
              return EntranceOnce(key: entries[i].$2.key, index: i < 6 ? i : 6, child: entries[i].$2);
            },
          ),
        );
      });

  Widget _buildSocialEmpty() => ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ChatStateCard3D(tone: _tone, art: ListingArt.speechBalloon, title: SocialStringsC.noChats, message: SocialStringsC.noChatsLine),
          Padding(
            padding: DS.gapInsets(l: 60, t: 18, r: 60),
            child: GradientPillButton(tone: ListingTone.indigo, label: SocialStringsC.findBuddies, onTap: SocialNav.openTravelBuddies),
          ),
        ],
      );

  Widget _listingList() => Obx(() {
      final loading = _ctrl.conversationsLoading.value;
      final items = _ctrl.visibleConversations;

      if (loading && items.isEmpty) return _buildShimmer();
      if (items.isEmpty) return _buildEmpty();

      final filtered = _filtered(items);
      if (filtered.isEmpty) return _buildNoMatches();

      final loadingMore = _ctrl.loadingMoreConversations.value;
      return RefreshIndicator(
        color: _tone.g2,
        backgroundColor: DesignColors.surface,
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.only(bottom: DS.s(KitMetrics.gutter) + AppInsets.bottomViewPadding(context)),
          itemCount: filtered.length + (loadingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= filtered.length) {
              return _buildLoadMoreSpinner();
            }
            return EntranceOnce(
              key: ValueKey(filtered[i].id),
              index: i < 6 ? i : 6,
              child: _conversationCard(filtered[i]),
            );
          },
        ),
      );
      });

  Widget _buildSearchBox() {
    return SearchPill(
      tone: _tone,
      value: '',
      buttonArt: '',
      inline: true,
      margin: EdgeInsets.fromLTRB(DS.s(18), DS.gv(18), DS.s(18), 0),
      buttonChild: Icon(Icons.search_rounded, size: DS.s(24), color: DesignColors.onPrimary),
      field: TextField(
        controller: _searchCtrl,
        inputFormatters: noEmojiInputFormatters,
        onChanged: (v) {
          setState(() => _query = v);
          _autoFetchCount = 0;
          _maybeFetchMoreForSearch();
        },
        cursorColor: _tone.g2,
        style: Ink3D.text(16, FontWeight.w400, Ink3D.body, letterSpacing: 0),
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          contentPadding: EdgeInsets.symmetric(vertical: DS.s(10)),
          hintText: 'Search by name or address',
          hintStyle: Ink3D.text(16, FontWeight.w400, Ink3D.hint, letterSpacing: 0),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _conversationCard(ConversationModel c) {
    final unread = c.unreadCount > 0;
    final statusLabel = c.isActive
        ? null
        : switch (c.status) {
            'ListingInactive' => 'Listing inactive',
            'ListingRemoved' => 'Listing removed',
            'Blocked' => 'Blocked',
            _ => 'Unavailable',
          };
    final kindLabel = ListingKindVisuals.labelOf(c.listingType);
    final place = '${c.listingTitle}${c.area != null && c.area!.isNotEmpty ? ' · ${c.area}' : ''}';
    return ChatThreadCard(
      tone: ChatLook3D.toneFor(c.listingType),
      initial: ChatLook3D.initialOf(c.otherPartyName),
      sticker: ChatLook3D.artFor(c.listingType),
      tag: statusLabel == null ? kindLabel : '$kindLabel · ${statusLabel.toUpperCase()}',
      title: c.otherPartyName,
      subtitle: place,
      time: _timeAgo(c.lastMessageAt),
      unread: unread ? (c.unreadCount > 99 ? '99+' : '${c.unreadCount}') : '',
      preview: c.lastMessagePreview ?? 'Say hi',
      dimmed: !c.isActive,
      onTap: () => _openConversation(c),
      photoUrl: c.otherPartyPhotoUrl,
    );
  }

  Widget _buildLoadMoreSpinner() => Padding(
    padding: EdgeInsets.only(top: DS.s(26), bottom: DS.s(16)),
    child: Center(
      child: SizedBox(
        width: DS.s(24),
        height: DS.s(24),
        child: CircularProgressIndicator(strokeWidth: DS.s(3), color: _tone.g2, backgroundColor: _tone.haloBase.withValues(alpha: Alpha.soft)),
      ),
    ),
  );

  Widget _buildEmpty() => ListView(
    physics: const NeverScrollableScrollPhysics(),
    children: [
      ChatStateCard3D(
        tone: _tone,
        art: ListingArt.speechBalloon,
        title: 'No chats yet',
      ),
    ],
  );

  Widget _buildNoMatches() => ListView(
    physics: const NeverScrollableScrollPhysics(),
    children: [
      ChatStateCard3D(tone: _tone, art: ListingArt.compass, title: 'No matches for "$_query"'),
    ],
  );

  Widget _buildShimmer() => ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 6,
    itemBuilder: (_, i) => const ChatThreadCard.skeleton(),
  );

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
