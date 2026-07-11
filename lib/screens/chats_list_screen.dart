import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../controllers/chat_controller.dart';
import '../models/conversation_model.dart';
import '../services/chat_hub_service.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});
  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> with WidgetsBindingObserver {
  final _ctrl = Get.find<ChatController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatHubService.to.connect();
    _ctrl.loadConversations();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatHubService.to.connect();
      _ctrl.loadConversations();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ChatHubService.to.disconnect();
    super.dispose();
  }

  Future<void> _refresh() => _ctrl.loadConversations(forceRefresh: true);

  void _openConversation(ConversationModel c) {
    Get.toNamed(AppRoutes.chatConversation, arguments: {
      'conversationId': c.id,
      'listingType': c.listingType,
      'listingId': c.listingId,
      'otherPartyName': c.otherPartyName,
      'listingTitle': c.listingTitle,
      'isOwner': c.isOwner,
      'status': c.status,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
            child: const Text('Chats',
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          Expanded(
            child: Obx(() {
              final loading = _ctrl.conversationsLoading.value;
              final items = _ctrl.conversations;

              if (loading && items.isEmpty) return _buildShimmer();
              if (items.isEmpty) return _buildEmpty();

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: EdgeInsets.only(bottom: 16 + AppInsets.bottomViewPadding(context)),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 78, color: AppColors.divider),
                  itemBuilder: (_, i) => _conversationTile(items[i]),
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }

  Widget _conversationTile(ConversationModel c) {
    final unread = c.unreadCount > 0;
    return InkWell(
      onTap: () => _openConversation(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.surface,
              child: Text(
                c.otherPartyName.isNotEmpty ? c.otherPartyName[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
            if (!c.isActive)
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.block_rounded, size: 12, color: AppColors.textHint),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(c.otherPartyName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 14.5,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.textDark)),
                ),
                Text(_timeAgo(c.lastMessageAt),
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 11,
                        color: unread ? AppColors.primary : AppColors.textHint,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400)),
              ]),
              const SizedBox(height: 2),
              Text('${c.listingType == 'Room' ? '🏠' : '📍'} ${c.listingTitle}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight)),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(
                  child: Text(c.lastMessagePreview ?? 'Say hi 👋',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 13,
                          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                          color: unread ? AppColors.textDark : AppColors.textMedium)),
                ),
                if (unread) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                    child: Text(c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text('No conversations yet',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 6),
            const Text('Start a chat from any room or plot listing',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
          ]),
        ),
      );

  Widget _buildShimmer() => Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const CircleAvatar(radius: 26, backgroundColor: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 12, width: 120, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 180, color: Colors.white),
                ]),
              ),
            ]),
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
