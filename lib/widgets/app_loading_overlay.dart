import 'package:flutter/material.dart';
import '../design/design.dart';

class AppLoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String message;
  final Color indicatorColor;

  const AppLoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message = 'Loading...',
    this.indicatorColor = FitnessAppTheme.nearlyDarkBlue,
  });

  static Widget stackChild({
    String message = 'Loading...',
    Color indicatorColor = FitnessAppTheme.nearlyDarkBlue,
  }) {
    return Positioned.fill(child: _LoadingBody(message: message, indicatorColor: indicatorColor));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(child: _LoadingBody(message: message, indicatorColor: indicatorColor)),
      ],
    );
  }
}

class _LoadingBody extends StatefulWidget {
  final String message;
  final Color indicatorColor;
  const _LoadingBody({required this.message, required this.indicatorColor});

  @override
  State<_LoadingBody> createState() => _LoadingBodyState();
}

class _LoadingBodyState extends State<_LoadingBody> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TemplateEntrance(
      animation: templateInterval(_c, 0, 2),
      animationController: _c,
      offset: 0,
      child: Container(
        color: GateKit.scrim,
        child: Center(
          child: TemplateEntrance(
            animation: templateInterval(_c, 1, 2),
            animationController: _c,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              decoration: GateKit.cardSmall(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5, color: widget.indicatorColor),
                  const SizedBox(height: 16),
                  Text(
                    widget.message,
                    style: FitnessAppTheme.body1.copyWith(fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
