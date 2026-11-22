import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// Device frame rules (D-19, D-20, D-22): phones portrait only, tablets rotate; content capped at 640 wide on tablets.
abstract final class AppFrame {
  static const double tabletShortestSide = 600;
  static const double tabletMaxWidth = 640;

  static const double minTextScale = 1.0;
  static const double maxTextScale = 1.3;

  // D-20: follow the phone's font size between 1.0 and 1.3.
  static TextScaler textScalerFor(TextScaler system) => system.clamp(minScaleFactor: minTextScale, maxScaleFactor: maxTextScale);

  static List<DeviceOrientation> orientationsFor(double shortestSide) =>
      shortestSide < tabletShortestSide ? const [DeviceOrientation.portraitUp] : const [];

  // Null while the engine has not sent the first view size (it can be 0x0 at start).
  static double? shortestSideOf(Size physicalSize, double devicePixelRatio) {
    if (physicalSize.isEmpty || devicePixelRatio <= 0) return null;
    return (physicalSize / devicePixelRatio).shortestSide;
  }

  static double? _currentShortestSide() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return null;
    return shortestSideOf(views.first.physicalSize, views.first.devicePixelRatio);
  }

  // A size not known yet is decided at the first metrics, so a tablet is never locked as a phone.
  static Future<void> applyOrientation() async {
    final side = _currentShortestSide();
    if (side != null) return SystemChrome.setPreferredOrientations(orientationsFor(side));
    WidgetsBinding.instance.addObserver(_FirstMetrics());
  }

  static Widget capWidth(BuildContext context, Widget child) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < tabletShortestSide) return child;
    final width = mq.size.width < tabletMaxWidth ? mq.size.width : tabletMaxWidth;
    return Center(
      child: SizedBox(
        width: width,
        child: MediaQuery(data: mq.copyWith(size: Size(width, mq.size.height)), child: child),
      ),
    );
  }
}

class _FirstMetrics with WidgetsBindingObserver {
  @override
  void didChangeMetrics() {
    final side = AppFrame._currentShortestSide();
    if (side == null) return;
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(AppFrame.orientationsFor(side));
  }
}
