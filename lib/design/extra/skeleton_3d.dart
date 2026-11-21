import 'package:flutter/material.dart';
import 'package:bakhli/design/tokens/design_scale.dart';

const Color _kBone = Color(0xFFE8EAF0);
const Color _kBoneLight = Color(0xFFF5F6F9);
const Color _kSunBone = Color(0xFFF3E2CB);
const Color _kSunBoneLight = Color(0xFFFBEFDF);

enum SkeletonTone { bone, sunrise }

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child, this.tone = SkeletonTone.bone});

  final Widget child;
  final SkeletonTone tone;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final x = -1.5 + 3 * _c.value;
            final sun = widget.tone == SkeletonTone.sunrise;
            return LinearGradient(begin: Alignment(x - 0.6, 0), end: Alignment(x + 0.6, 0), colors: sun ? const [_kSunBone, _kSunBoneLight, _kSunBone] : const [_kBone, _kBoneLight, _kBone]).createShader(rect);
          },
          child: child,
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius, this.borderRadius, this.tone = SkeletonTone.bone});

  final double? width;
  final double? height;
  final double? radius;
  final BorderRadius? borderRadius;
  final SkeletonTone tone;

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      tone: tone,
      child: Container(
        width: width,
        height: height ?? DS.s(14),
        decoration: BoxDecoration(
          color: tone == SkeletonTone.sunrise ? _kSunBone : _kBone,
          borderRadius: borderRadius ?? BorderRadius.circular(radius ?? DS.radius(7)),
        ),
      ),
    );
  }
}

Widget _bone({double? width, double height = 14, double radius = 7, bool round = false}) => Container(
  width: width == null ? null : DS.s(width),
  height: DS.s(height),
  decoration: BoxDecoration(color: _kBone, shape: round ? BoxShape.circle : BoxShape.rectangle, borderRadius: round ? null : DS.circular(radius)),
);

class SkeletonSlimCard extends StatelessWidget {
  const SkeletonSlimCard({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(36), DS.s(18), 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: height ?? DS.s(116),
            padding: EdgeInsets.fromLTRB(DS.s(134), DS.s(22), DS.s(20), DS.s(16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(54)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
              boxShadow: [BoxShadow(color: Color(0x409E9E9E), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(10))],
            ),
            child: _Shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_bone(width: 70, height: 10, radius: 5), SizedBox(height: DS.s(10)), _bone(width: 150, height: 16, radius: 8), SizedBox(height: DS.s(10)), _bone(width: 110, height: 12, radius: 6)],
              ),
            ),
          ),
          Positioned(left: DS.s(8), top: DS.s(-30), child: _Shimmer(child: _bone(width: 112, height: 112, round: true))),
        ],
      ),
    );
  }
}

class SkeletonListRow extends StatelessWidget {
  const SkeletonListRow({super.key, this.twoLines = false});

  final bool twoLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(76)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(20), vertical: DS.s(12)),
      child: _Shimmer(
        child: Row(
          children: [
            _bone(width: 52, height: 52, radius: 16),
            SizedBox(width: DS.s(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FractionallySizedBox(widthFactor: 0.62, child: _bone()),
                  if (twoLines) ...[SizedBox(height: DS.s(8)), FractionallySizedBox(widthFactor: 0.4, child: _bone(height: 10, radius: 5))],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonFormCard extends StatelessWidget {
  const SkeletonFormCard({super.key, this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? DS.s(140),
      margin: EdgeInsets.fromLTRB(DS.s(18), DS.gv(46), DS.s(18), 0),
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(18), DS.s(18), DS.s(18)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(68)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
        boxShadow: [BoxShadow(color: Color(0x389E9E9E), offset: DS.shadowOffset(const Offset(1.1, 1.1)), blurRadius: DS.shadowBlur(10))],
      ),
      child: _Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [_bone(width: 62, height: 62, radius: 18), SizedBox(width: DS.s(14)), _bone(width: 130, height: 16, radius: 8)]),
            const Spacer(),
            _bone(height: 26, radius: 13),
          ],
        ),
      ),
    );
  }
}
