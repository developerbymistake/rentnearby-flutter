import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_chat.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/chat_controller.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl.loadConversations();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        _ctrl.loadMoreConversations();
      }
    });
    _searchAutoFetchWorker = ever<List<ConversationModel>>(_ctrl.conversations, (_) => _maybeFetchMoreForSearch());
  }

  void _maybeFetchMoreForSearch() {
    if (!mounted || _query.trim().isEmpty) return;
    if (_autoFetchCount >= _maxAutoFetchPages) return;
    if (!_ctrl.hasMoreConversations.value || _ctrl.loadingMoreConversations.value) return;
    if (_filtered(_ctrl.conversations).length >= _minFilteredForNoAutoFetch) return;
    _autoFetchCount++;
    _ctrl.loadMoreConversations();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ctrl.loadConversations();
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
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Row(
                  children: [
                    ChatRoundButton3D(icon: Icons.chevron_left_rounded, onTap: () => Get.back(), tooltip: 'Back', tone: _tone),
                    const Spacer(),
                    ChatRoundButton3D(
                      icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                      onTap: _toggleSearch,
                      tooltip: _searchOpen ? 'Close search' : 'Search',
                      tone: _tone,
                      gradient: true,
                      size: 46,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: ModuleTitleBar(tone: _tone, art: ListingArt.speechBalloon, title: 'Messages'),
              ),
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
                child: Obx(() {
                  final loading = _ctrl.conversationsLoading.value;
                  final items = _ctrl.conversations;

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
                      padding: EdgeInsets.only(bottom: KitMetrics.gutter + AppInsets.bottomViewPadding(context)),
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
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return SearchPill(
      tone: _tone,
      value: '',
      buttonArt: '',
      inline: true,
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      buttonChild: const Icon(Icons.search_rounded, size: 24, color: DesignColors.onPrimary),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
    );
  }

  Widget _buildLoadMoreSpinner() => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 16),
    child: Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 3, color: _tone.g2, backgroundColor: _tone.haloBase.withValues(alpha: Alpha.soft)),
      ),
    ),
  );

  Widget _buildEmpty() => ListView(
    physics: const NeverScrollableScrollPhysics(),
    children: [
      ChatStateCard3D(
        tone: _tone,
        art: ListingArt.speechBalloon,
        title: 'No conversations yet',
        message: 'Start a chat from any stay.',
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
