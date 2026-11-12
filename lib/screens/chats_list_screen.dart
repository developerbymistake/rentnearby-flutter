import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(
        children: [
          ModuleHeader(
            title: 'Messages',
            tone: KitTone.stay,
            onBack: () => Get.back(),
            trailing: [
              IconButton(
                onPressed: () {
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
                },
                icon: Icon(
                  _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                  color: DesignColors.textInverse,
                ),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                children: [
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
                        color: DesignColors.primary,
                        backgroundColor: DesignColors.surface,
                        onRefresh: _refresh,
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          padding: EdgeInsets.fromLTRB(
                            0,
                            KitMetrics.cardGap,
                            0,
                            KitMetrics.gutter + AppInsets.bottomViewPadding(context),
                          ),
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
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 14, KitMetrics.gutter, 6),
      child: Container(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(38)),
          boxShadow: ShadowTokens.elev1,
        ),
        child: TextField(
          controller: _searchCtrl,
          inputFormatters: noEmojiInputFormatters,
          onChanged: (v) {
            setState(() => _query = v);
            _autoFetchCount = 0;
            _maybeFetchMoreForSearch();
          },
          cursorColor: DesignColors.primary,
          style: TypeTokens.style(16, FontWeight.w400, color: DesignColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search by name or address',
            hintStyle: TypeTokens.style(16, FontWeight.w400, color: DesignColors.textMuted),
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: DesignColors.textMuted),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _conversationCard(ConversationModel c) {
    final unread = c.unreadCount > 0;
    final kind = ChatKindStyle.of(c.listingType);
    final tone = KitTone(
      accent: kind.accent,
      accentDark: kind.dark,
      tint: kind.tint,
      gradient: kind.gradient,
      glow: kind.dark,
    );
    final statusLabel = c.isActive
        ? null
        : switch (c.status) {
            'ListingInactive' => 'Listing inactive',
            'ListingRemoved' => 'Listing removed',
            'Blocked' => 'Blocked',
            _ => 'Unavailable',
          };
    final place = '${c.listingTitle}${c.area != null && c.area!.isNotEmpty ? ' · ${c.area}' : ''}';
    return ListRow(
      title: c.otherPartyName,
      subtitle: place,
      tag: ListingKindVisuals.labelOf(c.listingType),
      notice: statusLabel,
      tone: tone,
      showChevron: false,
      dimmed: !c.isActive,
      onTap: () => _openConversation(c),
      leading: Container(
        width: ListRow.tileSizeCompact,
        height: ListRow.tileSizeCompact,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: kind.gradient,
          borderRadius: KitMetrics.tileSmall,
        ),
        child: Text(
          c.otherPartyName.isNotEmpty ? c.otherPartyName[0].toUpperCase() : '?',
          style: TypeTokens.style(20, FontWeight.w700, color: DesignColors.surface),
        ),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _timeAgo(c.lastMessageAt),
            style: TypeTokens.style(12, unread ? FontWeight.w600 : FontWeight.w400,
                color: unread ? kind.dark : TypeTokens.secondary),
          ),
          if (unread) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: kind.dark, borderRadius: CardRadius.pill),
              child: Text(
                c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                style: TypeTokens.style(11, FontWeight.w700, color: DesignColors.surface),
              ),
            ),
          ],
        ],
      ),
      footer: Text(
        c.lastMessagePreview ?? 'Say hi',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TypeTokens.style(14, unread ? FontWeight.w600 : FontWeight.w400,
            color: unread ? DesignColors.textPrimary : TypeTokens.secondary),
      ),
    );
  }

  Widget _buildLoadMoreSpinner() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: DesignColors.primary),
      ),
    ),
  );

  Widget _buildEmpty() => const Align(
    alignment: Alignment.topCenter,
    child: StateCard(
      asset: TravelIcon.chat,
      title: 'No conversations yet',
      message: 'Start a chat from any stay.',
    ),
  );

  Widget _buildNoMatches() => Align(
    alignment: Alignment.topCenter,
    child: StateCard(asset: TravelIcon.route, title: 'No matches for "$_query"'),
  );

  Widget _buildShimmer() => ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.only(top: KitMetrics.cardGap),
    itemCount: 6,
    itemBuilder: (_, i) => ListRow.skeleton(compact: true),
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
