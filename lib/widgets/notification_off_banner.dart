import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../design/design.dart';
import '../services/notification_service.dart';

class NotificationOffBanner extends StatefulWidget {
  const NotificationOffBanner({super.key, this.isDenied, this.openSettings});

  final Future<bool> Function()? isDenied;
  final Future<void> Function()? openSettings;

  static const String title = 'Turn on notifications';
  static const String body = 'You will miss new enquiries until notifications are on.';
  static const String action = 'Open settings';

  @override
  State<NotificationOffBanner> createState() => _NotificationOffBannerState();
}

class _NotificationOffBannerState extends State<NotificationOffBanner> with WidgetsBindingObserver {
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<bool> _ask() async {
    final custom = widget.isDenied;
    if (custom != null) return custom();
    return Get.isRegistered<NotificationService>() ? await NotificationService.to.isPermissionDenied() : false;
  }

  Future<void> _check() async {
    final denied = await _ask();
    if (mounted && denied != _denied) setState(() => _denied = denied);
  }

  Future<void> _open() async {
    final custom = widget.openSettings;
    if (custom != null) {
      await custom();
    } else {
      await ph.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_denied) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(KitMetrics.gutter, 12, KitMetrics.gutter, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: DesignColors.tint(DesignColors.warning, Alpha.tint), borderRadius: KitMetrics.tileSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.notifications_off_outlined, size: 18, color: DesignColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(NotificationOffBanner.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: TypeTokens.style(14, FontWeight.w700, color: DesignColors.textPrimary)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(NotificationOffBanner.body,
                maxLines: 3, overflow: TextOverflow.ellipsis, style: TypeTokens.style(12, FontWeight.w500, color: DesignColors.textSecondary)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _open,
                child: Text(NotificationOffBanner.action, style: TypeTokens.style(13, FontWeight.w700, color: DesignColors.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
