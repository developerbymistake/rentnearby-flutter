import 'package:flutter/material.dart';
import '../template/bottom_navigation_view/bottom_bar_view.dart';
import '../template/fitness_app_theme.dart';
import '../tokens/design_colors.dart';
import '../tokens/bar_metrics.dart';
import 'motion_kit.dart';

import 'package:bakhli/design/tokens/shadow_tokens.dart';
class TemplateRail extends StatelessWidget {
  const TemplateRail({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return RailReveal(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      padding: padding,
      separator: 0,
    );
  }
}

class TemplateTitleRow extends StatelessWidget {
  const TemplateTitleRow({
    super.key,
    required this.titleTxt,
    this.subTxt = '',
    this.onTap,
    this.gutter = 24,
  });

  final double gutter;
  final String titleTxt;
  final String subTxt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: gutter, right: gutter),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              titleTxt,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontFamily: FitnessAppTheme.fontName,
                fontWeight: FontWeight.w500,
                fontSize: 18,
                letterSpacing: 0.5,
                color: FitnessAppTheme.lightText,
              ),
            ),
          ),
          if (subTxt.isNotEmpty)
            InkWell(
              highlightColor: Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(4.0)),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: <Widget>[
                    Text(
                      subTxt,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontFamily: FitnessAppTheme.fontName,
                        fontWeight: FontWeight.normal,
                        fontSize: 16,
                        letterSpacing: 0.5,
                        color: FitnessAppTheme.nearlyDarkBlue,
                      ),
                    ),
                    const SizedBox(
                      height: 38,
                      width: 26,
                      child: Icon(
                        Icons.arrow_forward,
                        color: FitnessAppTheme.darkText,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TemplateNavItem {
  const TemplateNavItem({
    required this.index,
    required this.label,
    required this.image,
    String? selectedImage,
    this.itemKey,
    this.center = false,
  }) : selectedImage = selectedImage ?? image;

  final int index;
  final String label;
  final String image;
  final String selectedImage;
  final Key? itemKey;
  final bool center;
}

class TemplateBottomBar extends StatefulWidget {
  const TemplateBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.bottomInset,
  });

  final List<TemplateNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final double bottomInset;

  @override
  State<TemplateBottomBar> createState() => _TemplateBottomBarState();
}

class _TemplateBottomBarState extends State<TemplateBottomBar>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _tab(TemplateNavItem item) {
    return Expanded(
      key: ValueKey('nav_slot_${item.index}'),
      child: KeyedSubtree(
        key: item.itemKey ?? ValueKey('nav_${item.index}'),
        child: _NavTab(
          key: ValueKey('nav_tab_${item.index}'),
          item: item,
          selected: widget.selectedIndex == item.index,
          onTap: () => widget.onTap(item.index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.items.firstWhere((e) => e.center);
    final centerAt = widget.items.indexOf(center);
    final left = widget.items.sublist(0, centerAt);
    final right = widget.items.sublist(centerAt + 1);
    final curved = CurvedAnimation(
        parent: _controller, curve: Curves.fastOutSlowIn);
    return Stack(
      alignment: AlignmentDirectional.bottomCenter,
      children: <Widget>[
        AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return PhysicalShape(
              color: FitnessAppTheme.white,
              elevation: 16.0,
              clipper: TabClipper(radius: curved.value * 38.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    height: BarMetrics.barHeight,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(left: 8, right: 8, top: 4),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Row(children: [for (final i in left) _tab(i)]),
                          ),
                          SizedBox(width: curved.value * 64.0),
                          Expanded(
                            child: Row(children: [for (final i in right) _tab(i)]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: widget.bottomInset),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: EdgeInsets.only(bottom: widget.bottomInset),
          child: SizedBox(
            width: BarMetrics.centreOverflow * 2.0,
            height: BarMetrics.boxHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 38 * 2.0,
                height: 38 * 2.0,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ScaleTransition(
                    alignment: Alignment.center,
                    scale: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
                    child: KeyedSubtree(
                      key: center.itemKey ?? ValueKey('nav_${center.index}'),
                      child: _CenterButton(
                        item: center,
                        selected: widget.selectedIndex == center.index,
                        onTap: () => widget.onTap(center.index),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.bottomInset + 6,
          child: IgnorePointer(
            child: Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
                child: _NavLabel(
                    label: center.label,
                    selected: widget.selectedIndex == center.index),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      style: TextStyle(
        fontFamily: FitnessAppTheme.fontName,
        fontSize: 11,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        color: selected ? FitnessAppTheme.nearlyDarkBlue : FitnessAppTheme.grey,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
          ),
        ),
      ),
    );
  }
}

mixin _SelectPulse<T extends StatefulWidget> on State<T>, TickerProvider {
  late final AnimationController pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400))
    ..addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) pulse.reverse();
    });

  void pulseIf(bool was, bool now) {
    if (!was && now) pulse.forward(from: 0);
  }
}

class _NavTab extends StatefulWidget {
  const _NavTab({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final TemplateNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab>
    with TickerProviderStateMixin, _SelectPulse<_NavTab> {
  @override
  void didUpdateWidget(covariant _NavTab old) {
    super.didUpdateWidget(old);
    pulseIf(old.selected, widget.selected);
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  Widget _dot(double size, double begin, double end) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
          parent: pulse,
          curve: Interval(begin, end, curve: Curves.fastOutSlowIn))),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
            color: FitnessAppTheme.nearlyDarkBlue, shape: BoxShape.circle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      onTap: widget.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: <Widget>[
                ScaleTransition(
                  scale: Tween<double>(begin: 0.88, end: 1.0).animate(
                      CurvedAnimation(
                          parent: pulse,
                          curve: const Interval(0.1, 1.0,
                              curve: Curves.fastOutSlowIn))),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.fastOutSlowIn,
                    opacity: selected || widget.item.image != widget.item.selectedImage ? 1 : 0.6,
                    child: Image.asset(
                        selected ? widget.item.selectedImage : widget.item.image,
                        width: 28,
                        height: 28),
                  ),
                ),
                Positioned(top: 2, left: 8, child: _dot(8, 0.2, 1.0)),
                Positioned(top: 0, left: 8, bottom: 8, child: _dot(4, 0.5, 0.8)),
                Positioned(top: 6, right: 8, bottom: 0, child: _dot(6, 0.5, 0.6)),
              ],
            ),
          ),
          _NavLabel(label: widget.item.label, selected: selected),
        ],
      ),
    );
  }
}

class _CenterButton extends StatefulWidget {
  const _CenterButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final TemplateNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CenterButton> createState() => _CenterButtonState();
}

class _CenterButtonState extends State<_CenterButton>
    with TickerProviderStateMixin, _SelectPulse<_CenterButton> {
  @override
  void didUpdateWidget(covariant _CenterButton old) {
    super.didUpdateWidget(old);
    pulseIf(old.selected, widget.selected);
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.88, end: 1.0).animate(CurvedAnimation(
          parent: pulse,
          curve: const Interval(0.1, 1.0, curve: Curves.fastOutSlowIn))),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [
                FitnessAppTheme.nearlyDarkBlue,
                DesignColors.navAccentEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            ShadowTokens.tint(FitnessAppTheme.nearlyDarkBlue, widget.selected ? ShadowSpec.navLift : ShadowSpec.navIdle),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            splashColor: DesignColors.overlayWhiteFaint,
            highlightColor: Colors.transparent,
            focusColor: Colors.transparent,
            onTap: widget.onTap,
            child: Center(
              child: Image.asset(widget.item.image, width: 34, height: 34),
            ),
          ),
        ),
      ),
    );
  }
}
