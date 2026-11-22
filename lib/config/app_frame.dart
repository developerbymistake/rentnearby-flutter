import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// Device frame rules (D-19, D-22): phones portrait only, tablets rotate; content capped at 640 wide on tablets.
abstract final class AppFrame {
  static const double tabletShortestSide = 600;
  static const double tabletMaxWidth = 640;

  static List<DeviceOrientation> orientationsFor(double shortestSide) =>
      shortestSide < tabletShortestSide ? const [DeviceOrientation.portraitUp] : const [];

  static Future<void> applyOrientation() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return SystemChrome.setPreferredOrientations(const []);
    final view = views.first;
    final logical = view.physicalSize / view.devicePixelRatio;
    return SystemChrome.setPreferredOrientations(orientationsFor(logical.shortestSide));
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
