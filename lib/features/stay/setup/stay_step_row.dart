import 'package:flutter/material.dart';
import '../../../design/design.dart';

enum StayStepState { locked, current, done }

class StayStepRow extends StatefulWidget {
  final int number;
  final String title;
  final String subtitle;
  final StayStepState state;
  final VoidCallback? onTap;
  final Color accent;
  final IconData? icon;
  final String? trailing;
  final String? asset;
  final LinearGradient gradient;

  const StayStepRow({
    super.key,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.state,
    this.onTap,
    required this.accent,
    this.icon,
    this.trailing,
    this.asset,
    this.gradient = SetupKit.sky,
  });

  @override
  State<StayStepRow> createState() => _StayStepRowState();
}

class _StayStepRowState extends State<StayStepRow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
  late final Animation<double> _scale =
      Tween<double>(begin: 0.88, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.fastOutSlowIn));

  bool get _optional => widget.icon != null;

  @override
  void initState() {
    super.initState();
    _c.value = 1;
  }

  @override
  void didUpdateWidget(StayStepRow old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state && widget.state != StayStepState.locked) {
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = !_optional && widget.state == StayStepState.locked;
    final current = !_optional && widget.state == StayStepState.current;
    final end = widget.gradient.colors.last;
    final reduce = MediaQuery.of(context).disableAnimations;
    final dur = reduce ? Duration.zero : const Duration(milliseconds: 300);
    return PressScale(
      enabled: !locked && widget.onTap != null,
      child: AnimatedContainer(
        duration: dur,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: locked ? DesignColors.surfaceMuted : DesignColors.surface,
          borderRadius: PickKit.cardRadius,
          boxShadow: current ? ShadowTokens.elev3 : ShadowTokens.elev1,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: PickKit.cardRadius,
            splashColor: DesignColors.splash,
            highlightColor: Colors.transparent,
            onTap: locked ? null : widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
              child: Row(children: [
                ScaleTransition(scale: _scale, child: _circle(locked, end)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TripKit.text(14, color: locked ? DesignColors.textMuted : DesignColors.textPrimary).copyWith(letterSpacing: 0.2)),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TripKit.text(12, color: locked ? DesignColors.textMuted : TypeTokens.secondary)),
                  ]),
                ),
                const SizedBox(width: 8),
                _trailing(),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circle(bool locked, Color end) {
    final done = !_optional && widget.state == StayStepState.done;
    final asset = widget.asset ?? SetupAssets.hotel;
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: locked ? SetupKit.grey : widget.gradient,
            boxShadow: locked
                ? const []
                : ShadowTokens.elev1,
          ),
          child: locked
              ? Center(
                  child: Text('${widget.number}',
                      style: TripKit.text(13, weight: FontWeight.w700, color: DesignColors.textSecondary)))
              : Padding(padding: const EdgeInsets.all(6), child: Image.asset(asset)),
        ),
        if (done)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: DesignColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, size: 12, color: DesignColors.onPrimary),
            ),
          ),
      ]),
    );
  }

  Widget _trailing() {
    const blue = DesignColors.primary;
    if (_optional) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        if (widget.trailing != null)
          Text(widget.trailing!, style: TripKit.text(12, weight: FontWeight.w600, color: blue)),
        const Icon(Icons.chevron_right_rounded, size: 20, color: blue),
      ]);
    }
    switch (widget.state) {
      case StayStepState.done:
        return Text('Edit', style: TripKit.text(12, weight: FontWeight.w600, color: blue));
      case StayStepState.current:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: PickKit.stayTint, borderRadius: BorderRadius.circular(999)),
            child: Text('Start', style: TripKit.text(10, weight: FontWeight.w700, color: PickKit.stayDark)),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_right_rounded, size: 20, color: blue),
        ]);
      case StayStepState.locked:
        return const Icon(Icons.lock_outline_rounded, size: 16, color: DesignColors.textMuted);
    }
  }
}
