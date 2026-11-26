import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/app_routes.dart';
import '../config/shell_kind.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/notification_controller.dart';
import '../design/design.dart';
import '../features/social/c/chat/rooms_controller.dart';
import '../features/trip/enquiries/my_enquiry_count_controller.dart';

double _u(double v) => DS.s(v, scaled: false);

class TabHeaderIcons extends StatelessWidget {
  const TabHeaderIcons({super.key, this.onSettings, this.settingsOnly = false});

  static const Key settingsKey = ValueKey('tab_header_settings');
  static Color get gearTint => ListingPalette.coral.g1;

  final VoidCallback? onSettings;
  final bool settingsOnly;

  static RxInt? _count<T extends GetxController>(RxInt Function(T) read) =>
      Get.isRegistered<T>() ? read(Get.find<T>()) : null;

  static int Function()? _read(RxInt? rx) => rx == null ? null : () => rx.value;

  static int Function()? _chatCount() {
    final listing = _count<ChatController>((c) => c.unreadCount);
    final rooms = RoomsController.maybe;
    if (rooms == null) return _read(listing);
    return () => (listing?.value ?? 0) + rooms.unread.value.total;
  }

  @override
  Widget build(BuildContext context) {
    final settings = onSettings;
    if (settingsOnly && settings != null) {
      return Padding(
        padding: EdgeInsets.only(bottom: _u(2)),
        child: _TabHeaderIcon(key: settingsKey, asset: ListingArt.gear, label: 'Settings', unread: null, onTap: settings, tint: gearTint),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: _u(2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabHeaderIcon(
            asset: ListingArt.bell,
            label: 'Notifications',
            unread: _read(_count<NotificationController>((c) => c.unreadCount)),
            onTap: () => Get.toNamed(AppRoutes.notifications),
          ),
          SizedBox(width: _u(10)),
          _TabHeaderIcon(
            asset: ListingArt.speechBalloon,
            label: 'Chats',
            unread: _chatCount(),
            onTap: () => Get.toNamed(AppRoutes.chatsList),
          ),
          if (Get.isRegistered<AuthController>())
            Obx(() {
              final auth = Get.find<AuthController>();
              if (auth.shellKind.value != ShellKind.seeker || !auth.canUseTravellerFeatures) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.only(left: _u(10)),
                child: _TabHeaderIcon(
                  asset: ListingArt.clipboard,
                  label: 'Enquiries',
                  unread: _read(_count<MyEnquiryCountController>((c) => c.offers)),
                  onTap: () => Get.toNamed(AppRoutes.myEnquiries),
                ),
              );
            }),
          if (onSettings != null)
            Padding(
              padding: EdgeInsets.only(left: _u(10)),
              child: _TabHeaderIcon(key: settingsKey, asset: ListingArt.gear, label: 'Settings', unread: null, onTap: onSettings!, tint: gearTint),
            ),
        ],
      ),
    );
  }
}

class _TabHeaderIcon extends StatelessWidget {
  const _TabHeaderIcon({super.key, required this.asset, required this.label, required this.unread, required this.onTap, this.tint});

  final String asset;
  final String label;
  final int Function()? unread;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final count = unread;
    return RoundIconButton3D(
      asset: asset,
      semanticsLabel: label,
      scaled: false,
      tint: tint,
      onTap: onTap,
      badge: count == null
          ? null
          : IgnorePointer(
              child: Obx(() {
                final n = count();
                if (n <= 0) return const SizedBox.shrink();
                return RoundIconButton3D.count(n > 99 ? '99+' : '$n', scaled: false);
              }),
            ),
    );
  }
}

class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, required this.subtitle, required this.color, this.onSettings, this.settingsOnly = false});

  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onSettings;
  final bool settingsOnly;

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
              TabHeaderIcons(onSettings: onSettings, settingsOnly: settingsOnly),
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
    this.onSettings,
    this.settingsOnly = false,
  });

  final String title;
  final String subtitle;
  final Color color;
  final Widget child;
  final VoidCallback? onSettings;
  final bool settingsOnly;

  @override
  Widget build(BuildContext context) {
    return KitStatusBar(
      lightIcons: false,
      child: Column(
        children: [
          TabHeader(title: title, subtitle: subtitle, color: color, onSettings: onSettings, settingsOnly: settingsOnly),
          Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: child)),
        ],
      ),
    );
  }
}
