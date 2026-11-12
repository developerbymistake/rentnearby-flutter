import '../tokens/alpha_tokens.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../template/fitness_app_theme.dart';
import 'motion_kit.dart';

class TemplateTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SharedAxisTransition(
      fillColor: FitnessAppTheme.background,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: SharedAxisTransitionType.horizontal,
      child: child,
    );
  }
}

const Duration templateTransitionDuration = Duration(milliseconds: 300);
const Duration templateTransitionReverseDuration = Duration(milliseconds: 250);

Animation<double> templateInterval(
  AnimationController controller,
  int index,
  int count,
) {
  return controller.drive(CurveTween(
      curve: Interval((1 / count) * index, 1.0, curve: Curves.fastOutSlowIn)));
}

class TemplateEntrance extends StatelessWidget {
  const TemplateEntrance({
    super.key,
    required this.animation,
    required this.animationController,
    required this.child,
    this.offset = 30,
    this.dx = 0,
  });

  final Animation<double> animation;
  final AnimationController animationController;
  final Widget child;
  final double offset;
  final double dx;

  @override
  Widget build(BuildContext context) {
    if (KitMotion.reduce(context)) return child;
    return AnimatedBuilder(
      animation: animationController,
      builder: (BuildContext context, Widget? _) {
        return FadeTransition(
          opacity: animation,
          child: Transform(
            transform: Matrix4.translationValues(
                dx * (1.0 - animation.value), offset * (1.0 - animation.value), 0.0),
            child: child,
          ),
        );
      },
    );
  }
}

class TemplateStagger extends StatefulWidget {
  const TemplateStagger({
    super.key,
    required this.children,
    this.duration,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final CrossAxisAlignment crossAxisAlignment;
  final List<Widget> children;
  final Duration? duration;

  @override
  State<TemplateStagger> createState() => _TemplateStaggerState();
}

class _TemplateStaggerState extends State<TemplateStagger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
          duration: widget.duration ??
              Duration(milliseconds: KitMotion.staggerTotalMs(widget.children.length)),
          vsync: this);

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.children.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        for (var i = 0; i < count; i++)
          TemplateEntrance(
            animation: widget.duration == null
                ? _controller.drive(CurveTween(curve: KitMotion.staggerInterval(i, count)))
                : templateInterval(_controller, i, count),
            animationController: _controller,
            child: widget.children[i],
          ),
      ],
    );
  }
}

class TemplatePlaceholder extends StatefulWidget {
  const TemplatePlaceholder({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 8,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<TemplatePlaceholder> createState() => _TemplatePlaceholderState();
}

class _TemplatePlaceholderState extends State<TemplatePlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      duration: const Duration(milliseconds: 1200), vsync: this);
  late final CurvedAnimation _animation = CurvedAnimation(
      parent: _controller, curve: Curves.fastOutSlowIn);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KitMotion.reduce(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(FitnessAppTheme.background,
                FitnessAppTheme.grey.withValues(alpha: Alpha.soft), _animation.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}
