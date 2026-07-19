import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../models/conversation_model.dart';
import '../utils/input_formatters.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});
  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen>
    with WidgetsBindingObserver {
  final _ctrl = Get.find<ChatController>();
  final _auth = Get.find<AuthController>();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';
  bool _searchOpen = false;
  Worker? _chatsTabWorker;
  Worker? _searchAutoFetchWorker;
  // Bounded auto-fetch counter for the search-stalls-on-few-results gap below — reset
  // whenever the query changes or search closes, so a fresh search always gets its own
  // budget of pages to look through.
  int _autoFetchCount = 0;
  static const _minFilteredForNoAutoFetch = 8;
  static const _maxAutoFetchPages = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl.loadConversations();
    // Fires near the bottom of whatever's currently loaded — searches over the
    // already-loaded list too, so scrolling to load more naturally widens what a
    // search can match (there's no server-side text search endpoint to query directly).
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        _ctrl.loadMoreConversations();
      }
    });
    // ChatsListScreen lives inside main_screen.dart's IndexedStack, so this State is
    // never disposed on tab switch — without this, a search left open would stay open
    // when leaving and returning to the Chats tab. Same reset-on-revisit pattern
    // profile_screen.dart already uses via profileTabTrigger.
    _chatsTabWorker = ever(_auth.chatsTabTrigger, (_) => _closeSearch());
    // A narrow search query can filter the currently-loaded list down to a handful of rows
    // that don't even fill the viewport — the scroll listener above then structurally never
    // fires (there's nothing to scroll), so loadMoreConversations() would never run even
    // though more matching conversations may exist in unfetched pages. This re-checks every
    // time a new page actually lands (not just on each keystroke), continuing the fetch
    // chain started by _maybeFetchMoreForSearch below.
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

  void _closeSearch() {
    if (!mounted) return;
    setState(() {
      _searchOpen = false;
      _query = '';
    });
    _searchCtrl.clear();
    _autoFetchCount = 0;
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
    _chatsTabWorker?.dispose();
    _searchAutoFetchWorker?.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    // No ChatHubService.disconnect() here anymore — MainScreen owns this connection's
    // lifecycle for the whole session now (see main_screen.dart), not this screen.
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
        'roomTypeId': c.roomTypeId,
        'plotTypeId': c.plotTypeId,
        'otherPartyId': c.otherPartyId,
        'otherPartyName': c.otherPartyName,
        'listingTitle': c.listingTitle,
        'area': c.area,
        'isOwner': c.isOwner,
        'status': c.status,
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
    // SafeArea lives INSIDE the gradient Container (not wrapping it) — same pattern
    // chat_conversation_screen.dart's and explore_screen.dart's headers already use — so the
    // gradient's own paint area starts at the very top of the screen, genuinely extending
    // behind the status bar, and only the title text gets padded down to clear it. This
    // screen then inherits the app-wide light-icon default, same as every other
    // gradient-headed screen, instead of needing its own AnnotatedRegion override.
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Messages',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final opening = !_searchOpen;
                        setState(() {
                          _searchOpen = opening;
                          if (!opening) _query = '';
                        });
                        if (!opening) _searchCtrl.clear();
                      },
                      icon: Icon(
                        _searchOpen
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _searchOpen
                        ? AnimatedOpacity(
                            duration: const Duration(milliseconds: 220),
                            opacity: _searchOpen ? 1 : 0,
                            child: _buildSearchBox(),
                          )
                        : const SizedBox(width: double.infinity),
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
                        color: AppColors.primary,
                        onRefresh: _refresh,
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            14,
                            8,
                            14,
                            14 + AppInsets.bottomViewPadding(context),
                          ),
                          itemCount: filtered.length + (loadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i >= filtered.length)
                              return _buildLoadMoreSpinner();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
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

  // Same field/style as the location picker's search box (location_switch_sheet.dart) —
  // reusing the app's one established search-field pattern rather than inventing another.
  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: TextField(
        controller: _searchCtrl,
        inputFormatters: noEmojiInputFormatters,
        onChanged: (v) {
          setState(() => _query = v);
          _autoFetchCount = 0;
          _maybeFetchMoreForSearch();
        },
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Search by name or address',
          hintStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.5,
            color: AppColors.textHint,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textHint,
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _conversationCard(ConversationModel c) {
    final unread = c.unreadCount > 0;
    return Material(
      // Background is always white now — unread is signaled by the bold name/preview
      // text and the count badge instead of a background tint or border.
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openConversation(c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // No border, and a neutral black-based shadow (not primary-tinted) — a
            // colored border/shadow was reading as "the card itself looks dark/tinted"
            // even though the fill was already pure white. Matches the shadow pattern
            // already used elsewhere in the app (create_banner_screen.dart's fields,
            // question_templates_screen.dart's cards).
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: AppColors.primary,
                    child: Opacity(
                      opacity: c.isActive ? 1 : 0.55,
                      child: Text(
                        c.otherPartyName.isNotEmpty
                            ? c.otherPartyName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (!c.isActive)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: AppColors.divider),
                          ),
                        ),
                        child: const Icon(
                          Icons.block_rounded,
                          size: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.otherPartyName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14.5,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        Text(
                          _timeAgo(c.lastMessageAt),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: unread
                                ? AppColors.primary
                                : AppColors.textHint,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${c.listingType == 'Room' ? '🏠' : '📍'} ${c.listingTitle}'
                      '${c.area != null && c.area!.isNotEmpty ? ' · ${c.area}' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        color: AppColors.textLight,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            c.lastMessagePreview ?? 'Say hi 👋',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: unread
                                  ? AppColors.textDark
                                  : AppColors.textMedium,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreSpinner() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 56,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            'No conversations yet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start a chat from any room or plot listing',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildNoMatches() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 48,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 14),
          Text(
            'No matches for "$_query"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildShimmer() => Shimmer.fromColors(
    baseColor: AppColors.shimmerBase,
    highlightColor: AppColors.shimmerHighlight,
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const CircleAvatar(radius: 23, backgroundColor: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12, width: 120, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 180, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
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
