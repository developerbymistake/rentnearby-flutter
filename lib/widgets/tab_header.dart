import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../config/shell_kind.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/notification_controller.dart';
import '../design/design.dart';
import '../features/trip/enquiries/my_enquiry_count_controller.dart';

double _u(double v) => DS.s(v, scaled: false);

class TabHeaderIcons extends StatelessWidget {
  const TabHeaderIcons({super.key});

  static RxInt? _count<T extends GetxController>(RxInt Function(T) read) =>
      Get.isRegistered<T>() ? read(Get.find<T>()) : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: _u(2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabHeaderIcon(
            asset: ListingArt.bell,
            label: 'Notifications',
            unread: _count<NotificationController>((c) => c.unreadCount),
            onTap: () => Get.toNamed(AppRoutes.notifications),
          ),
          SizedBox(width: _u(10)),
          _TabHeaderIcon(
            asset: ListingArt.speechBalloon,
            label: 'Chats',
            unread: _count<ChatController>((c) => c.unreadCount),
            onTap: () => Get.toNamed(AppRoutes.chatsList),
          ),
          if (Get.isRegistered<AuthController>())
            Obx(() {
              if (Get.find<AuthController>().shellKind.value != ShellKind.seeker) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(left: _u(10)),
                child: _TabHeaderIcon(
                  asset: ListingArt.clipboard,
                  label: 'Enquiries',
                  unread: _count<MyEnquiryCountController>((c) => c.offers),
                  onTap: () => Get.toNamed(AppRoutes.myEnquiries),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TabHeaderIcon extends StatelessWidget {
  const _TabHeaderIcon({required this.asset, required this.label, required this.unread, required this.onTap});

  final String asset;
  final String label;
  final RxInt? unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = unread;
    return RoundIconButton3D(
      asset: asset,
      semanticsLabel: label,
      scaled: false,
      onTap: onTap,
      badge: count == null
          ? null
          : IgnorePointer(
              child: Obx(() {
                final n = count.value;
                if (n <= 0) return const SizedBox.shrink();
                return RoundIconButton3D.count(n > 99 ? '99+' : '$n', scaled: false);
              }),
            ),
    );
  }
}

class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, required this.subtitle, required this.color});

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Padding(
          padding: EdgeInsets.fromLTRB(_u(18), _u(10), _u(18), _u(14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(title, maxLines: 1, style: Ink3D.text(28, FontWeight.w700, Ink3D.title, height: 1.25, scaled: false)),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: _u(3)),
                      child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w400, Ink3D.sub, letterSpacing: 0, scaled: false)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: _u(10)),
              const TabHeaderIcons(),
            ],
          ),
        ),
      ),
    );
  }
}

class TabHeaderFrame extends StatelessWidget {
  const TabHeaderFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KitStatusBar(
      lightIcons: false,
      child: Column(
        children: [
          TabHeader(title: title, subtitle: subtitle, color: color),
          Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
        ],
      ),
    );
  }
}
