import 'package:flutter/material.dart';

const Color _kBone = Color(0xFFE8EAF0);
const Color _kBoneLight = Color(0xFFF5F6F9);

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

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
            return LinearGradient(begin: Alignment(x - 0.6, 0), end: Alignment(x + 0.6, 0), colors: const [_kBone, _kBoneLight, _kBone]).createShader(rect);
          },
          child: child,
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 7});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: _kBone, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

Widget _bone({double? width, double height = 14, double radius = 7, bool round = false}) => Container(
  width: width,
  height: height,
  decoration: BoxDecoration(color: _kBone, shape: round ? BoxShape.circle : BoxShape.rectangle, borderRadius: round ? null : BorderRadius.circular(radius)),
);

class SkeletonSlimCard extends StatelessWidget {
  const SkeletonSlimCard({super.key, this.height = 116});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 36, 18, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: height,
            padding: const EdgeInsets.fromLTRB(134, 22, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
              boxShadow: [BoxShadow(color: Color(0x409E9E9E), offset: Offset(1.1, 4), blurRadius: 10)],
            ),
            child: _Shimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_bone(width: 70, height: 10, radius: 5), const SizedBox(height: 10), _bone(width: 150, height: 16, radius: 8), const SizedBox(height: 10), _bone(width: 110, height: 12, radius: 6)],
              ),
            ),
          ),
          Positioned(left: 8, top: -30, child: _Shimmer(child: _bone(width: 112, height: 112, round: true))),
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
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: _Shimmer(
        child: Row(
          children: [
            _bone(width: 52, height: 52, radius: 16),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FractionallySizedBox(widthFactor: 0.62, child: _bone()),
                  if (twoLines) ...[const SizedBox(height: 8), FractionallySizedBox(widthFactor: 0.4, child: _bone(height: 10, radius: 5))],
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
  const SkeletonFormCard({super.key, this.height = 140});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.fromLTRB(18, 46, 18, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(68), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
        boxShadow: [BoxShadow(color: Color(0x389E9E9E), offset: Offset(1.1, 1.1), blurRadius: 10)],
      ),
      child: _Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [_bone(width: 62, height: 62, radius: 18), const SizedBox(width: 14), _bone(width: 130, height: 16, radius: 8)]),
            const Spacer(),
            _bone(height: 26, radius: 13),
          ],
        ),
      ),
    );
  }
}
