import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../config/notification_strings.dart';
import '../controllers/auth_controller.dart';
import '../controllers/notification_controller.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../utils/app_date_format.dart';
import '../utils/app_toast.dart';
import '../utils/notification_visuals.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _ctrl = Get.find<NotificationController>();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl.loadNotifications(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _ctrl.loadMoreNotifications();
    }
  }

  Future<void> _refresh() => _ctrl.loadNotifications(reset: true);

  void _openNotification(NotificationModel n) {
    _ctrl.markRead(n.id);
    final route = n.actionRoute;
    if (route == null || route == AppRoutes.notifications) return;
    if (!Get.find<AuthController>().canOpenRoute(route)) {
      AppToast.info('This is no longer available.');
      return;
    }
    NotificationService.to.openActionRoute(route, n.actionArguments);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.scaffold,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Obx(() {
              final loading = _ctrl.isLoading.value;
              final loadingMore = _ctrl.isLoadingMore.value;
              final items = _ctrl.notifications;
              final hasMore = _ctrl.hasMoreNotifications.value;
              if (loading && items.isEmpty) return _buildShimmer();
              if (items.isEmpty && _ctrl.loadFailed.value) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: StateCard.error(
                    title: NotificationStrings.loadFailedTitle,
                    message: NotificationStrings.loadFailedBody,
                    actionLabel: NotificationStrings.retry,
                    onAction: _refresh,
                  ),
                );
              }
              if (items.isEmpty) return _buildEmpty();

              final cells = groupByDay<NotificationModel>(items, (n) => n.createdAt);
              return RefreshIndicator(
                color: DesignColors.primary,
                backgroundColor: DesignColors.surface,
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(KitMetrics.gutter, KitMetrics.cardGap, KitMetrics.gutter,
                      KitMetrics.gutter + AppInsets.bottomViewPadding(context)),
                  itemCount: cells.length + (hasMore || loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == cells.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: DesignColors.primary)),
                      );
                    }
                    final cell = cells[i];
                    return switch (cell) {
                      DayHeaderCell<NotificationModel>() => ChatDayLabel(cell.label),
                      DayItemCell<NotificationModel>(item: final n) => EntranceOnce(
                          key: ValueKey(n.id),
                          index: i,
                          child: _NotificationRow(
                            notification: n,
                            dateText: AppDateFormat.time(n.createdAt),
                            onTap: () => _openNotification(n),
                          ),
                        ),
                    };
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ModuleHeader(
      title: 'Notifications',
      tone: KitTone.stay,
      onBack: () => Get.back(),
      trailing: [
        Obx(() => _ctrl.notifications.any((n) => !n.isRead)
            ? TextButton(
                onPressed: _ctrl.markAllRead,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(KitMetrics.touch, KitMetrics.touch),
                ),
                child: Text('Mark all read',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.textInverse)),
              )
            : const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildEmpty() => const Align(
        alignment: Alignment.topCenter,
        child: StateCard(
          asset: NotificationLook.bell,
          title: 'No notifications yet',
          message: "You'll see updates here as they happen.",
        ),
      );

  Widget _buildShimmer() => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: KitMetrics.cardGap),
        itemCount: 6,
        itemBuilder: (_, i) => ListRow.skeleton(compact: true),
      );
}

class _NotificationRow extends StatelessWidget {
  final NotificationModel notification;
  final String dateText;
  final VoidCallback onTap;

  const _NotificationRow({required this.notification, required this.dateText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    final kindName = NotificationVisuals.kind(notification.type, notification.title).name;
    final look = NotificationLook.of(kindName);
    final kind = NotificationVisuals.listingKind(notification.actionRoute);
    return ListRow(
      title: notification.title,
      titleMaxLines: 1,
      subtitle: notification.body,
      subtitleLines: 2,
      dimmed: isRead,
      showChevron: false,
      margin: const EdgeInsets.only(bottom: KitMetrics.cardGap),
      onTap: onTap,
      leading: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: DesignColors.tint(look.color, Alpha.tint), borderRadius: KitMetrics.tileSmall),
        child: Image.asset(look.asset, width: 28, height: 28),
      ),
      trailing: isRead
          ? null
          : const ChatPill(label: 'NEW', fill: RepliesTone.accentSurface, color: DesignColors.primary),
      body: Row(
        children: [
          Flexible(child: Text(dateText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption)),
          if (kind != null) ...[
            const SizedBox(width: 8),
            ChatPill(label: kind, fill: RepliesTone.accentSurface, color: DesignColors.primary),
          ],
        ],
      ),
    );
  }
}
