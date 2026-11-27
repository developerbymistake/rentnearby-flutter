import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../../../utils/app_toast.dart';
import '../../trip_strings_hub.dart';
import 'hub_tile_config.dart';
import 'hub_tokens.dart';

class HubTile extends StatelessWidget {
  const HubTile({super.key, required this.config, required this.onTap});

  static const double height = 160;
  static const double artWidth = 158;
  static const double artTop = -46;
  static const double artBottom = 2;

  final HubTileConfig config;
  final VoidCallback onTap;

  bool get _soon => config.status == HubTileStatus.soon;
  bool get _textLeft => config.side == HubTileSide.textLeft;

  void _tap() {
    if (_soon) {
      AppToast.info(TripStringsHub.comingSoon);
      return;
    }
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    final c = config;
    final label = '${c.line} ${c.title}${_soon ? ', ${TripStringsHub.comingSoon}' : ''}';
    return Semantics(
      button: true,
      enabled: !_soon,
      label: label,
      excludeSemantics: true,
      onTap: _tap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: SizedBox(
          height: DS.s(height),
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: HubTileShapePainter(c1: c.c1, c2: c.c2, mirrored: _textLeft, soon: _soon),
                    ),
                  ),
                  _artLayer(w),
                  _text(w),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _artLayer(double w) {
    final items = <Widget>[for (final a in config.art) _art(a)];
    return Positioned(
      top: DS.s(artTop),
      bottom: DS.s(artBottom),
      width: DS.s(artWidth),
      left: _textLeft ? null : DS.s(12),
      right: _textLeft ? DS.s(12) : null,
      child: ClipRect(
        clipper: _ArtClipper(),
        child: Stack(clipBehavior: Clip.none, children: items),
      ),
    );
  }

  Widget _art(HubArtItem a) {
    Widget img = Art3D(
      asset: a.asset,
      size: a.size,
      shadowBlur: 12,
      shadowOffset: const Offset(5, 8),
      shadowAlpha: _soon ? 0.18 : 0.22,
    );
    if (a.flipX) img = Transform.flip(flipX: true, child: img);
    final useBottom = a.top == null;
    return Positioned(
      left: a.left == null ? null : DS.s(a.left!),
      right: a.right == null ? null : DS.s(a.right!),
      top: a.top == null ? null : DS.s(a.top!),
      bottom: useBottom ? DS.s(a.bottom ?? 0) : null,
      width: DS.s(a.size),
      height: DS.s(a.size),
      child: ExcludeSemantics(child: img),
    );
  }

  Widget _text(double w) {
    final c = config;
    final align = _textLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final ta = _textLeft ? TextAlign.left : TextAlign.right;
    final textW = math.min(w, HubTileShapePainter.boxW) * c.textWidthFactor;
    return Positioned(
      top: 0,
      bottom: 0,
      left: _textLeft ? DS.s(26) : null,
      right: _textLeft ? null : DS.s(26),
      width: textW,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: _textLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: SizedBox(
            width: textW,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: align,
              children: [
                Text(
                  c.line,
                  textAlign: ta,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(16, FontWeight.w400, c.text, height: 1.28, letterSpacing: 0),
                ),
                SizedBox(height: DS.s(3)),
                Text(
                  c.title,
                  textAlign: ta,
                  style: Ink3D.text(22, FontWeight.w700, c.text, height: 1.12, letterSpacing: 0.2),
                ),
                if (_soon) ...[
                  SizedBox(height: DS.s(8)),
                  Container(
                    padding: DS.sym(h: 10, v: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: Alpha.v92),
                      borderRadius: DS.circular(12),
                    ),
                    child: Text(
                      TripStringsHub.comingSoon,
                      style: Ink3D.text(11, FontWeight.w700, const Color(0xFF555555), letterSpacing: 0),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtClipper extends CustomClipper<Rect> {
  _ArtClipper();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(DS.s(-90), DS.s(-60), size.width + DS.s(30), size.height - DS.s(8));

  @override
  bool shouldReclip(_ArtClipper old) => false;
}

class HubTileShapePainter extends CustomPainter {
  const HubTileShapePainter({required this.c1, required this.c2, required this.mirrored, required this.soon});

  static const double boxW = 360;
  static const double boxH = 132;

  final Color c1;
  final Color c2;
  final bool mirrored;
  final bool soon;

  static Path shape() => Path()
    ..moveTo(30, 4)
    ..quadraticBezierTo(8, 4, 8, 26)
    ..lineTo(8, 106)
    ..quadraticBezierTo(8, 128, 30, 128)
    ..lineTo(322, 114)
    ..quadraticBezierTo(352, 112, 352, 86)
    ..lineTo(352, 50)
    ..quadraticBezierTo(352, 24, 322, 22)
    ..close();

  static Path _hexTile() => Path()
    ..moveTo(13, 0)
    ..lineTo(26, 7.5)
    ..lineTo(26, 22.5)
    ..lineTo(13, 30)
    ..lineTo(0, 22.5)
    ..lineTo(0, 7.5)
    ..close()
    ..moveTo(0, 30)
    ..lineTo(13, 37.5)
    ..lineTo(13, 45)
    ..moveTo(26, 30)
    ..lineTo(13, 37.5);

  static Path _hexPattern() {
    final tile = _hexTile();
    final p = Path();
    for (double x = -26; x <= boxW; x += 26) {
      for (double y = -45; y <= boxH; y += 45) {
        p.addPath(tile, Offset(x, y));
      }
    }
    return p;
  }

  static final Path _pattern = _hexPattern();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / boxW;
    final sy = size.height / boxH;
    final m = Matrix4.identity();
    if (mirrored) {
      m.translateByDouble(size.width, 0, 0, 1);
      m.scaleByDouble(-sx, sy, 1, 1);
    } else {
      m.scaleByDouble(sx, sy, 1, 1);
    }
    final Float64List storage = m.storage;
    final p = shape();
    final device = p.transform(storage);

    if (soon) canvas.saveLayer((Offset.zero & size).inflate(DS.s(48)), Paint()..color = const Color(0xE6FFFFFF));

    final under = Path.combine(PathOperation.union, device, device.shift(Offset(0, DS.s(5))));
    final white = Paint()..color = Colors.white.withValues(alpha: Alpha.v90);
    canvas.drawPath(under.shift(Offset(0, DS.s(-1))), white);
    canvas.drawPath(
      under.shift(Offset(0, DS.s(13))),
      Paint()
        ..color = Colors.white.withValues(alpha: Alpha.v90)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, DS.s(12)),
    );
    canvas.drawPath(
      under.shift(Offset(0, DS.s(14))),
      Paint()
        ..color = HubTokens.deviceShadowFar
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, DS.s(12)),
    );
    canvas.drawPath(device.shift(Offset(0, DS.s(5))), Paint()..color = HubTokens.deviceShadowNear);

    canvas.save();
    canvas.transform(storage);
    final bounds = p.getBounds();
    canvas.drawPath(p, Paint()..shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, [c1, c2]));
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: Alpha.v90),
    );
    canvas.save();
    canvas.clipPath(p);
    canvas.drawPath(
      _pattern,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: Alpha.v55),
    );
    canvas.restore();
    canvas.restore();

    if (soon) canvas.restore();
  }

  @override
  bool shouldRepaint(HubTileShapePainter o) => o.c1 != c1 || o.c2 != c2 || o.mirrored != mirrored || o.soon != soon;
}
