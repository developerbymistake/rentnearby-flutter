import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/chat_kit.dart';
import 'package:bakhli/design/extra/ext_notifications.dart';
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

  static final ListingTone _tone = ListingTone.indigo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.indigo.page,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          final loading = _ctrl.isLoading.value;
          final loadingMore = _ctrl.isLoadingMore.value;
          final items = _ctrl.notifications;
          final hasMore = _ctrl.hasMoreNotifications.value;
          if (loading && items.isEmpty) return _withHeader(_buildShimmer());
          if (items.isEmpty && _ctrl.loadFailed.value) {
            return _withHeader(_centred(StateCard3D(
              tone: ListingTone.cC,
              art: TravelIcon.route,
              title: NotificationStrings.loadFailedTitle,
              message: NotificationStrings.loadFailedBody,
              actionLabel: NotificationStrings.retry,
              onAction: _refresh,
              layout: StateLayout.tall,
              actionBelow: true,
            )));
          }
          if (items.isEmpty) return _withHeader(_buildEmpty());

          final cells = groupByDay<NotificationModel>(items, (n) => n.createdAt);
          final extra = hasMore || loadingMore ? 1 : 0;
          return RefreshIndicator(
            color: _tone.g2,
            backgroundColor: DesignColors.surface,
            edgeOffset: NotificationHeader3D.heightFor(context),
            displacement: 30,
            onRefresh: _refresh,
            child: ListView.builder(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: EdgeInsets.only(bottom: 20 + AppInsets.bottomViewPadding(context)),
              itemCount: 1 + cells.length + extra,
              itemBuilder: (_, index) {
                if (index == 0) return _buildHeader();
                final i = index - 1;
                if (i == cells.length) return const NotificationMoreSpinner();
                final cell = cells[i];
                return switch (cell) {
                  DayHeaderCell<NotificationModel>() => DayLabel3D(cell.label),
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
    );
  }

  Widget _withHeader(Widget body) => Column(children: [_buildHeader(), Expanded(child: body)]);

  Widget _buildHeader() {
    return NotificationHeader3D(
      tone: _tone,
      title: 'Notifications',
      art: NotificationLook.bell,
      onBack: () => Get.back(),
      action: Obx(() => _ctrl.notifications.any((n) => !n.isRead)
          ? GradientPillButton(
              tone: _tone,
              label: 'Mark all read',
              onTap: _ctrl.markAllRead,
              icon: _roomy(context) ? Icons.check_rounded : null,
              height: 40,
              fontSize: 14,
              expand: false,
            )
          : const SizedBox.shrink()),
    );
  }

  bool _roomy(BuildContext context) => MediaQuery.sizeOf(context).width >= 340 && MediaQuery.textScalerOf(context).scale(1) <= 1.15;

  Widget _centred(Widget child) => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 20 + AppInsets.bottomViewPadding(context)),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - 20 - AppInsets.bottomViewPadding(context)),
            child: Center(child: child),
          ),
        ),
      );

  Widget _buildEmpty() => _centred(StateCard3D(
        tone: _tone,
        art: NotificationLook.bell,
        title: 'No notifications yet',
        message: "You'll see updates here as they happen.",
        layout: StateLayout.tall,
      ));

  Widget _buildShimmer() => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: 6,
        itemBuilder: (_, i) => i == 0 ? const NotificationDaySkeleton() : const NotificationCardSkeleton(),
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
    final route = notification.actionRoute;
    final cut = dateText.lastIndexOf(' ');
    return NotificationCard3D(
      tone: NotificationTone.of(kindName),
      art: look.asset,
      title: notification.title,
      body: notification.body,
      time: cut < 0 ? dateText : dateText.substring(0, cut),
      unit: cut < 0 ? '' : dateText.substring(cut + 1),
      tag: kind,
      isNew: !isRead,
      read: isRead,
      opens: route != null && route != AppRoutes.notifications,
      onTap: onTap,
    );
  }
}
