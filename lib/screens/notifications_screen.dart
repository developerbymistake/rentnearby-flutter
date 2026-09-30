import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../config/app_shadows.dart';
import '../controllers/notification_controller.dart';
import '../models/notification_model.dart';
import '../utils/app_date_format.dart';
import '../utils/notification_visuals.dart';
import '../widgets/day_header.dart';
import '../widgets/new_pill.dart';

/// The Home-screen bell's inbox — infinite-scroll paginated, mirroring
/// WalletLedgerScreen's ScrollController + footer-loader-row pattern (this
/// app has no shared PaginatedListView widget). Row tap is fully generic —
/// no per-`type` switch: every notification already carries its own
/// actionRoute/actionArguments (see NotificationModel's doc comment), so a
/// future notification category needs zero changes here to route correctly.
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
    if (n.actionRoute != null) {
      Get.toNamed(n.actionRoute!, arguments: n.actionArguments);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
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
              if (items.isEmpty) return _buildEmpty();

              // Flat, index-addressable list of day headers + rows — recomputed on every build,
              // which is cheap (a pure O(n) pass, no state of its own) for this list's size and
              // re-groups correctly as loadMoreNotifications() appends further pages, since it
              // walks the full accumulated list each time rather than per-page.
              final cells = groupByDay<NotificationModel>(items, (n) => n.createdAt);

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + AppInsets.bottomViewPadding(context)),
                  itemCount: cells.length + (hasMore || loadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == cells.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      );
                    }
                    final cell = cells[i];
                    return switch (cell) {
                      DayHeaderCell<NotificationModel>() => DayHeader(cell.label),
                      DayItemCell<NotificationModel>(item: final n) => _NotificationRow(
                          notification: n,
                          dateText: AppDateFormat.time(n.createdAt),
                          onTap: () => _openNotification(n),
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
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'Notifications',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              Obx(() => _ctrl.notifications.any((n) => !n.isRead)
                  ? TextButton(
                      onPressed: _ctrl.markAllRead,
                      child: const Text('Mark all read',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                    )
                  : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none_rounded, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          const Text('No notifications yet',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text("You'll see updates here as they happen.",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
        ]),
      );

  Widget _buildShimmer() => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        itemCount: 6,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 90,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(16)),
          ),
        ),
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
    final tint = NotificationVisuals.color(notification.type, notification.title);
    final kind = NotificationVisuals.listingKind(notification.actionRoute);
    final isPlot = notification.actionRoute == AppRoutes.myPlots;
    final accent = isPlot ? AppColors.plot : AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isRead ? AppColors.cardBg : (isPlot ? AppColors.plotSurface : AppColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
          boxShadow: AppShadows.premium(AppColors.primary, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
              child: Icon(NotificationVisuals.icon(notification.type, notification.title), size: 18, color: tint),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        NewPill(color: accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(dateText, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                      if (kind != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            kind,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: accent),
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
    );
  }
}
