import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'dialog_3d.dart';
import 'list_rows_3d.dart';
import 'pill_buttons_3d.dart';
import 'toast_3d.dart';
import 'toggle_row.dart';

abstract final class TaxiOwnerArt {
  static const String car = 'assets/images/design/travel3d/automobile.png';
}

abstract final class TaxiOwnerLook {
  static const BorderRadius card = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));
  static const Color lockHalo = Color(0x2EFFFFFF);
  static const Color band = Color(0x1C000000);
  static const Color panel = Color(0x2EFFFFFF);
  static const Color faint = Color(0x1AFFFFFF);
  static const Color soft = Color(0x38FFFFFF);
  static const Color glass = Color(0x24000000);
  static const Color cream = Color(0xFFFFF4DE);
  static const Color creamText = Color(0xFF5A3A00);
  static const Color redPill = Color(0xFFB0222C);
  static const Color live = Color(0xFF2E7D32);
  static const Color off = Color(0xFF767676);
  static const Color review = Color(0xFFB86E00);
  static const Color rejected = Color(0xFFD93A3A);
  static const Color info = Color(0xFF2633C5);
  static const Color urgent = Color(0xFFFFD27A);
  static const Color urgentText = Color(0xFF7A4A00);
  static const Color divider = Color(0x40FFFFFF);
  static const List<BoxShadow> btn = [BoxShadow(color: Color(0x33000000), offset: Offset(3, 6), blurRadius: 10)];
  static const List<BoxShadow> bar = [BoxShadow(color: Color(0x599E9E9E), offset: Offset(0, -2), blurRadius: 16)];
}

enum TaxiStepIcon { check, arrow, lock, edit, add }

class TaxiStepCard3D extends StatelessWidget {
  const TaxiStepCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.tag,
    this.current = false,
    this.onTap,
  });

  final ListingTone tone;
  final String art;
  final String step;
  final String title;
  final String subtitle;
  final TaxiStepIcon icon;
  final String? tag;
  final bool current;
  final VoidCallback? onTap;

  static const double topRoom = 36;

  IconData get _glyph => switch (icon) {
        TaxiStepIcon.check => Icons.check_rounded,
        TaxiStepIcon.arrow => Icons.arrow_forward_rounded,
        TaxiStepIcon.lock => Icons.lock_rounded,
        TaxiStepIcon.edit => Icons.edit_rounded,
        TaxiStepIcon.add => Icons.add_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final scaler = MediaQuery.textScalerOf(context);
    final locked = icon == TaxiStepIcon.lock;
    final wide = MediaQuery.sizeOf(context).width >= 380;
    final artSize = narrow ? 88.0 : (wide ? 112.0 : 102.0);
    final left = narrow ? 100.0 : (wide ? 134.0 : 120.0);
    final t = tag;

    final image = Art3D(asset: art, size: artSize, halo: artSize - 4, haloColor: locked ? TaxiOwnerLook.lockHalo : TaxiOwnerLook.soft, haloDy: 4);

    final button = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(shape: BoxShape.circle, color: locked ? TaxiOwnerLook.soft : Colors.white, boxShadow: locked ? null : TaxiOwnerLook.btn),
      child: Icon(_glyph, size: locked ? 20 : 22, color: locked ? Colors.white : tone.button),
    );

    final card = Container(
      constraints: BoxConstraints(minHeight: 132 * scaler.scale(1).clamp(1.0, 1.15)),
      padding: EdgeInsets.fromLTRB(left, 16, 14, 16),
      decoration: BoxDecoration(
        borderRadius: TaxiOwnerLook.card,
        gradient: locked ? Form3D.lockGradient : tone.gradient,
        border: current ? Border.all(color: Colors.white, width: 3, strokeAlign: BorderSide.strokeAlignOutside) : null,
        boxShadow: locked ? null : tone.glow(blur: current ? 16 : 10, dy: current ? 8 : 4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(step.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w700, Colors.white, letterSpacing: 0.7))),
                    if (t != null && t.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w700, tone.button, letterSpacing: 0)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Colors.white, height: 1.2)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white, height: 1.35, letterSpacing: 0)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          button,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, topRoom + 14, 18, 0),
      child: Tap3D(
        onTap: locked ? null : onTap,
        label: [step, title, subtitle, ?tag, if (locked) 'locked'].join(', '),
        exclude: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            Positioned(left: 6, top: -topRoom, child: image),
          ],
        ),
      ),
    );
  }
}

class TaxiRingCard3D extends StatelessWidget {
  const TaxiRingCard3D({super.key, required this.tone, required this.title, required this.value, required this.progress, this.caption});

  final ListingTone tone;
  final String title;
  final String value;
  final double progress;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final wide = MediaQuery.sizeOf(context).width >= 380;
    final artSize = narrow ? 88.0 : (wide ? 112.0 : 102.0);
    final left = narrow ? 100.0 : (wide ? 134.0 : 120.0);
    final ring = narrow ? 58.0 : 66.0;
    final cap = caption;
    final card = Container(
      constraints: const BoxConstraints(minHeight: 128),
      padding: EdgeInsets.fromLTRB(left, 16, 14, 16),
      decoration: BoxDecoration(borderRadius: TaxiOwnerLook.card, gradient: tone.gradient, boxShadow: tone.glow()),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Colors.white, height: 1.2)),
                if (cap != null && cap.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(cap, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white, height: 1.35, letterSpacing: 0)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: ring,
            height: ring,
            child: CustomPaint(
              painter: _RingPainter(progress.clamp(0.0, 1.0)),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(padding: const EdgeInsets.all(10), child: Text(value, maxLines: 1, style: Ink3D.text(15, FontWeight.w700, Colors.white, letterSpacing: 0))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 50, 18, 0),
      child: Semantics(
        label: '$title. ${cap ?? ''}',
        excludeSemantics: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            Positioned(left: 6, top: -34, child: ExcludeSemantics(child: Art3D(asset: ListingArt.star, size: artSize, halo: artSize - 4, haloColor: TaxiOwnerLook.soft, haloDy: 4))),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(4);
    final track = Paint()
      ..color = TaxiOwnerLook.soft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawOval(r, track);
    if (value <= 0) return;
    final arc = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6;
    canvas.drawArc(r, -math.pi / 2, 2 * math.pi * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

class TaxiHeaderButton extends StatelessWidget {
  const TaxiHeaderButton({super.key, required this.tone, required this.icon, required this.onTap, required this.tooltip});

  final ListingTone tone;
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Tap3D(
          onTap: onTap,
          label: tooltip,
          exclude: true,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: Ink3D.softShadow),
            child: Icon(icon, size: 24, color: tone.text),
          ),
        ),
      );
}

class TaxiRouteCard3D extends StatelessWidget {
  const TaxiRouteCard3D({super.key, required this.tone, required this.tag, required this.title, required this.subtitle, required this.onEdit, required this.onRemove});

  final ListingTone tone;
  final String tag;
  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  Widget _round(IconData icon, String tip, VoidCallback onTap) => Tooltip(
        message: tip,
        excludeFromSemantics: true,
        child: Tap3D(
          onTap: onTap,
          label: tip,
          exclude: true,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: TaxiOwnerLook.btn),
                child: Icon(icon, size: 20, color: tone.button),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final artSize = narrow ? 80.0 : 96.0;
    final left = narrow ? 92.0 : 114.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 104),
            padding: EdgeInsets.fromLTRB(left, 14, 12, 14),
            decoration: BoxDecoration(borderRadius: TaxiOwnerLook.card, gradient: tone.gradient, boxShadow: tone.glow()),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tag.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w700, Colors.white, letterSpacing: 0.7)),
                      const SizedBox(height: 2),
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Colors.white, height: 1.2)),
                      const SizedBox(height: 2),
                      FitLine3D(text: subtitle, style: Ink3D.text(12.5, FontWeight.w600, Colors.white, letterSpacing: 0), stretch: 1.6),
                    ],
                  ),
                ),
                _round(Icons.edit_rounded, 'Edit route', onEdit),
                _round(Icons.close_rounded, 'Remove route', onRemove),
              ],
            ),
          ),
          Positioned(left: 4, top: -24, child: ExcludeSemantics(child: Art3D(asset: ListingArt.compass, size: artSize, halo: artSize - 2, haloColor: TaxiOwnerLook.soft, haloDy: 3))),
        ],
      ),
    );
  }
}

class TaxiPlateTile extends StatelessWidget {
  const TaxiPlateTile({super.key, required this.tone, required this.photo, required this.onRemove});

  final ListingTone tone;
  final Widget photo;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(18), child: photo)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(gradient: tone.gradient, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18))),
              child: Text('Plate', textAlign: TextAlign.center, maxLines: 1, style: Ink3D.text(11, FontWeight.w700, Colors.white)),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: 'Remove photo',
              excludeFromSemantics: true,
              child: Tap3D(
                onTap: onRemove,
                label: 'Remove photo',
                exclude: true,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: TaxiOwnerLook.btn),
                    child: Icon(Icons.close_rounded, size: 16, color: Form3D.error),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class TaxiAddPhotoTile extends StatelessWidget {
  const TaxiAddPhotoTile({super.key, required this.tone, required this.onTap, this.error = false});

  final ListingTone tone;
  final VoidCallback? onTap;
  final bool error;

  @override
  Widget build(BuildContext context) => Tap3D(
        onTap: onTap,
        label: 'Add photo',
        exclude: true,
        child: Container(
          decoration: BoxDecoration(
            color: error ? Form3D.fillError : tone.tint,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: error ? Form3D.error : tone.g1, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(ListingArt.camera, width: 40, height: 40),
              const SizedBox(height: 4),
              Text('Add', maxLines: 1, style: Ink3D.text(12, FontWeight.w700, error ? Form3D.errorText : tone.text)),
            ],
          ),
        ),
      );
}

class TaxiBucketChip extends StatelessWidget {
  const TaxiBucketChip({super.key, required this.tone, required this.art, required this.label, required this.selected, required this.onTap, this.compact = false});

  final ListingTone tone;
  final String art;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  Widget _pill() => Tap3D(
        onTap: onTap,
        label: label,
        selected: selected,
        exclude: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? null : Colors.white,
            gradient: selected ? tone.gradient : null,
            borderRadius: BorderRadius.circular(19),
            boxShadow: selected ? tone.glow(blur: 8) : Ink3D.whiteBtn,
          ),
          child: Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(14, FontWeight.w700, selected ? Colors.white : tone.button, letterSpacing: 0)),
        ),
      );

  @override
  Widget build(BuildContext context) => compact ? _pill() : Tap3D(
        onTap: onTap,
        label: label,
        selected: selected,
        exclude: true,
        child: Opacity(
          opacity: selected ? 1 : 0.62,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 46),
                  padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < Form3D.narrow ? 62 : 70, 10, 10, 10),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                    gradient: tone.gradient,
                    boxShadow: selected ? tone.glow(blur: 8) : const [],
                  ),
                  child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(14, FontWeight.w700, Colors.white, letterSpacing: 0))),
                ),
              ),
              Positioned(left: 6, top: 0, child: Art3D(asset: art, size: 56, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
            ],
          ),
        ),
      );
}

enum TaxiLeadButtonKind { solid, glass }

class TaxiLeadButton {
  const TaxiLeadButton({required this.label, required this.onTap, this.kind = TaxiLeadButtonKind.glass, this.busy = false});

  final String label;
  final VoidCallback? onTap;
  final TaxiLeadButtonKind kind;
  final bool busy;
}

class TaxiLeadCard3D extends StatelessWidget {
  const TaxiLeadCard3D({
    super.key,
    required this.tone,
    required this.guest,
    required this.city,
    required this.pills,
    required this.summary,
    this.urgent,
    this.journey,
    this.places = '',
    this.detail,
    this.extra,
    this.pillColor,
    this.onMenu,
    this.menuKey,
    this.buttons = const [null, null, null],
    this.highlighted = false,
  });

  final ListingTone tone;
  final String guest;
  final String city;
  final String? urgent;
  final List<String> pills;
  final String summary;
  final String? journey;
  final String places;
  final String? detail;
  final String? extra;
  final Color? pillColor;
  final VoidCallback? onMenu;
  final Key? menuKey;
  final List<TaxiLeadButton?> buttons;
  final bool highlighted;

  static const double topRoom = 50;

  Widget _pill(String text, {bool hot = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: hot ? TaxiOwnerLook.urgent : Colors.white,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(14), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
        ),
        child: Text(text.toUpperCase(), maxLines: 1, style: Ink3D.text(11, FontWeight.w700, hot ? TaxiOwnerLook.urgentText : (pillColor ?? tone.button), letterSpacing: 0.4)),
      );

  Widget _button(TaxiLeadButton? b, double h) {
    if (b == null) {
      return ExcludeSemantics(child: Container(height: h, decoration: BoxDecoration(color: TaxiOwnerLook.faint, borderRadius: BorderRadius.circular(h / 2))));
    }
    final solid = b.kind == TaxiLeadButtonKind.solid;
    final live = b.onTap != null && !b.busy;
    final box = Container(
      height: h,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: solid ? Colors.white : TaxiOwnerLook.glass,
        borderRadius: BorderRadius.circular(h / 2),
        boxShadow: solid ? TaxiOwnerLook.btn : null,
      ),
      child: b.busy
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: solid ? tone.button : Colors.white))
          : FittedBox(fit: BoxFit.scaleDown, child: Text(b.label, maxLines: 1, softWrap: false, style: Ink3D.text(13.5, FontWeight.w700, solid ? tone.button : Colors.white, letterSpacing: 0))),
    );
    return Tap3D(onTap: live ? b.onTap : null, label: b.label, exclude: true, child: box);
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final artSize = narrow ? 104.0 : 136.0;
    final left = narrow ? 116.0 : 156.0;
    final h = 44.0 * scale.clamp(1.0, 1.2);
    final j = journey;
    final d = detail;
    final x = extra;
    final u = urgent;
    final bs = [for (var i = 0; i < 3; i++) i < buttons.length ? buttons[i] : null];

    final head = ConstrainedBox(
      constraints: BoxConstraints(minHeight: narrow ? 70 : 92),
      child: Padding(
        padding: EdgeInsets.fromLTRB(left, 14, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FitLine3D(text: guest, style: Ink3D.text(18, FontWeight.w700, Colors.white, height: 1.25), stretch: 1.7),
                  Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w500, Colors.white, letterSpacing: 0)),
                ],
              ),
            ),
            if (onMenu == null)
              const SizedBox(width: 44, height: 44)
            else
              Tooltip(
                message: 'More',
                excludeFromSemantics: true,
                child: Tap3D(
                  onTap: onMenu,
                  tapKey: menuKey,
                  label: 'More',
                  exclude: true,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(color: TaxiOwnerLook.soft, shape: BoxShape.circle),
                        child: const Icon(Icons.more_vert_rounded, size: 22, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24 * scale.clamp(1.0, 1.3),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (u != null) ...[_pill(u, hot: true), const SizedBox(width: 6)],
                for (var i = 0; i < pills.length; i++) ...[if (i > 0) const SizedBox(width: 6), _pill(pills[i])],
              ]),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: (narrow ? 53 : 36) * scale,
            child: Text(summary, maxLines: narrow ? 3 : 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w600, Colors.white, height: 1.4, letterSpacing: 0)),
          ),
          if (j != null && j.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 32 * scale.clamp(1.0, 1.3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: TaxiOwnerLook.cream, borderRadius: BorderRadius.circular(12)),
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(j, maxLines: 1, softWrap: false, style: Ink3D.text(11.5, FontWeight.w700, TaxiOwnerLook.creamText, letterSpacing: 0))),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    final strip = Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: BoxConstraints(minHeight: 38 * scale.clamp(1.0, 1.3)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      color: TaxiOwnerLook.band,
      child: Row(
        children: [
          Image.asset(ListingArt.roundPushpin, width: 18, height: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(places, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white, letterSpacing: 0))),
        ],
      ),
    );

    final detailLine = d == null && x == null && (j == null || j.isEmpty)
        ? const SizedBox(height: 10)
        : Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 36 * scale),
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (d != null) Text(d, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, Colors.white, height: 1.35, letterSpacing: 0)),
              if (x != null) Text(x, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white, height: 1.35, letterSpacing: 0)),
            ],
          ),
        ),
      ),
    );

    final actions = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(bs[0], h),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _button(bs[1], h)), const SizedBox(width: 10), Expanded(child: _button(bs[2], h))]),
        ],
      ),
    );

    final card = Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: TaxiOwnerLook.card,
        boxShadow: tone.glow(),
        border: highlighted ? Border.all(color: Colors.white, width: 3, strokeAlign: BorderSide.strokeAlignOutside) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [head, body, strip, detailLine, actions],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, topRoom, 14, 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(left: 4, top: narrow ? -30 : -44, child: IgnorePointer(child: ExcludeSemantics(child: Art3D(asset: ListingArt.taxi, size: artSize, halo: artSize + 4, haloColor: TaxiOwnerLook.soft, haloDy: 4)))),
        ],
      ),
    );
  }
}

class TaxiEmptyCard3D extends StatelessWidget {
  const TaxiEmptyCard3D({super.key, required this.tone, required this.art, required this.title, required this.message, required this.actionLabel, required this.onAction});

  final ListingTone tone;
  final String art;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    const artSize = 150.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24 + artSize / 2, 18, 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, artSize / 2 + 22, 24, 26),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(68), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
              boxShadow: [BoxShadow(color: Color(0x299E9E9E), offset: Offset(2, 4), blurRadius: 12)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, height: 1.25))),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center, style: Ink3D.text(14.5, FontWeight.w400, Ink3D.sub, height: 1.45)),
                const SizedBox(height: 22),
                GradientPillButton(tone: tone, label: actionLabel, onTap: onAction),
              ],
            ),
          ),
          Positioned(
            top: -artSize / 2,
            child: ExcludeSemantics(child: Art3D(asset: art, size: artSize, halo: artSize - 10, haloColor: tone.haloBase.withValues(alpha: 0.18), shadowBlur: 8, shadowOffset: const Offset(6, 10), shadowAlpha: 0.28)),
          ),
        ],
      ),
    );
  }
}

class TaxiPayBar extends StatelessWidget {
  const TaxiPayBar({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(18, 12, 18, 14 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16)), boxShadow: TaxiOwnerLook.bar),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ToastDock(),
            Row(
              children: [
                Image.asset(ListingArt.moneyBag, width: 40, height: 40),
                const SizedBox(width: 12),
                Expanded(child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w600, Ink3D.sub, height: 1.4, letterSpacing: 0))),
              ],
            ),
          ],
        ),
      );
}

class TaxiOwnerStatus {
  const TaxiOwnerStatus(this.label, this.color);
  final String label;
  final Color color;

  static const live = TaxiOwnerStatus('LIVE', TaxiOwnerLook.live);
  static const offline = TaxiOwnerStatus('OFFLINE', TaxiOwnerLook.off);
  static const review = TaxiOwnerStatus('UNDER REVIEW', TaxiOwnerLook.review);
  static const rejected = TaxiOwnerStatus('REJECTED', TaxiOwnerLook.rejected);
  static const draft = TaxiOwnerStatus('DRAFT', TaxiOwnerLook.off);
}

class TaxiOwnerRoute {
  const TaxiOwnerRoute({required this.title, required this.trip, required this.fare, this.onEdit});
  final String title;
  final String trip;
  final String fare;
  final VoidCallback? onEdit;
}

class TaxiOwnerLink {
  const TaxiOwnerLink({required this.art, required this.title, required this.subtitle, required this.pill, this.red = false, this.onTap});
  final String art;
  final String title;
  final String subtitle;
  final String pill;
  final bool red;
  final VoidCallback? onTap;
}

class TaxiOwnerAction {
  const TaxiOwnerAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class TaxiOwnerCard3D extends StatelessWidget {
  const TaxiOwnerCard3D({
    super.key,
    required this.tone,
    required this.status,
    required this.title,
    required this.ago,
    required this.vehicleLabel,
    required this.vehicle,
    required this.fromLabel,
    required this.from,
    required this.available,
    required this.onAvailable,
    required this.onAvailableLocked,
    required this.actions,
    this.report,
    this.onReport,
    this.routes = const [],
    this.links = const [],
    this.stripArt,
    this.strip,
    this.stripAction,
    this.onStrip,
  });

  final ListingTone tone;
  final TaxiOwnerStatus status;
  final String title;
  final String ago;
  final String vehicleLabel;
  final String vehicle;
  final String fromLabel;
  final String from;
  final bool available;
  final ValueChanged<bool>? onAvailable;
  final VoidCallback? onAvailableLocked;
  final List<TaxiOwnerAction> actions;
  final String? report;
  final VoidCallback? onReport;
  final List<TaxiOwnerRoute> routes;
  final List<TaxiOwnerLink> links;
  final String? stripArt;
  final String? strip;
  final String? stripAction;
  final VoidCallback? onStrip;

  Widget _panel(Widget child) => Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(color: TaxiOwnerLook.panel, borderRadius: BorderRadius.circular(14)),
        child: child,
      );

  Widget _divided(List<Widget> rows) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: TaxiOwnerLook.divider),
            rows[i],
          ],
        ],
      );

  Widget _route(TaxiOwnerRoute r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Colors.white, letterSpacing: 0)),
                  Text(r.trip, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w500, Colors.white, letterSpacing: 0)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.fare, maxLines: 1, style: Ink3D.text(15, FontWeight.w700, Colors.white, letterSpacing: 0)),
                if (r.onEdit != null) ...[const SizedBox(height: 4), OnCardPill(label: 'Edit fare', color: tone.button, width: 76, onTap: r.onEdit)],
              ],
            ),
          ],
        ),
      );

  Widget _link(TaxiOwnerLink l) => Tap3D(
        onTap: l.onTap,
        label: '${l.title}, ${l.subtitle}, ${l.pill}',
        exclude: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: TaxiOwnerLook.soft),
                  child: Center(child: Image.asset(l.art, width: 44, height: 44)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, Colors.white, letterSpacing: 0)),
                      if (l.subtitle.isNotEmpty)
                        Text(l.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w500, Colors.white, letterSpacing: 0)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                l.red
                    ? Container(
                        constraints: const BoxConstraints(minWidth: 64, minHeight: 28),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: TaxiOwnerLook.redPill, borderRadius: BorderRadius.circular(16)),
                        child: Text(l.pill, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, Colors.white, letterSpacing: 0)),
                      )
                    : OnCardPill(label: l.pill, color: tone.button, width: l.pill.length <= 6 ? 64 : null, onTap: l.onTap),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final artSize = narrow ? 104.0 : 136.0;
    final left = narrow ? 120.0 : 156.0;
    final rep = report;
    final st = strip;

    final head = Padding(
      padding: EdgeInsets.fromLTRB(left, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Text(status.label, maxLines: 1, style: Ink3D.text(11, FontWeight.w700, status.color, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 6),
          FitLine3D(text: title, style: Ink3D.text(19, FontWeight.w700, Colors.white, height: 1.25), stretch: 1.6),
          Text(ago, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w500, Colors.white, letterSpacing: 0)),
          const SizedBox(height: 8),
          Text(vehicleLabel, maxLines: 1, style: Ink3D.text(10.5, FontWeight.w700, Colors.white, letterSpacing: 0.6)),
          Text(vehicle.replaceAll(' seats', '\u00A0seats'), maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white, letterSpacing: 0)),
        ],
      ),
    );

    final reportRow = rep == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: OnCardRow(title: rep, art: ListingArt.warning, light: true, onTap: onReport, trailing: Icon(Icons.chevron_right_rounded, color: Form3D.errorText)),
          );

    final price = Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(fromLabel, maxLines: 1, style: Ink3D.text(11, FontWeight.w700, Colors.white, letterSpacing: 0.5))),
          const SizedBox(width: 8),
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(from, maxLines: 1, style: Ink3D.text(28, FontWeight.w500, Colors.white, letterSpacing: 0, height: 1.2)))),
        ],
      ),
    );

    final availableRow = Tap3D(
      onTap: onAvailable == null ? onAvailableLocked : () => onAvailable!(!available),
      label: 'Available now',
      toggled: available,
      exclude: true,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Expanded(child: Text('Available now', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Colors.white, letterSpacing: 0))),
            IgnorePointer(child: Switch3D(tone: tone, value: available, onGradient: true, onChanged: onAvailable)),
          ],
        ),
      ),
    );

    final stripRow = st == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: OnCardRow(
              title: st,
              art: stripArt,
              onTap: onStrip,
              trailing: stripAction == null
                  ? null
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 124),
                      child: FittedBox(fit: BoxFit.scaleDown, child: OnCardPill(label: stripAction!, color: tone.button, onTap: onStrip)),
                    ),
            ),
          );

    final bar = Container(
      margin: const EdgeInsets.only(top: 14),
      color: TaxiOwnerLook.band,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1, thickness: 1, color: TaxiOwnerLook.divider),
              Expanded(
                child: Tap3D(
                  onTap: actions[i].onTap,
                  label: actions[i].label,
                  exclude: true,
                  child: Opacity(
                    opacity: actions[i].onTap == null ? 0.5 : 1,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 64),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Icon(actions[i].icon, size: 16, color: tone.text),
                          ),
                          const SizedBox(height: 4),
                          Text(actions[i].label, maxLines: 1, style: Ink3D.text(13, FontWeight.w700, Colors.white, letterSpacing: 0)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final card = Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: TaxiOwnerLook.card, boxShadow: tone.glow()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          head,
          ?reportRow,
          price,
          _panel(availableRow),
          if (routes.isNotEmpty) _panel(_divided([for (final r in routes) _route(r)])),
          if (links.isNotEmpty) _panel(_divided([for (final l in links) _link(l)])),
          ?stripRow,
          if (actions.isNotEmpty) bar else const SizedBox(height: 16),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 50, 14, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(left: 4, top: -44, child: IgnorePointer(child: ExcludeSemantics(child: Art3D(asset: ListingArt.taxi, size: artSize, halo: artSize + 4, haloColor: TaxiOwnerLook.soft, haloDy: 4)))),
        ],
      ),
    );
  }
}

Future<bool?> showTaxiOwnerDialog(
  BuildContext context, {
  required String art,
  required String title,
  required String body,
  required String cancelLabel,
  required String confirmLabel,
  bool destructive = false,
  bool barrierDismissible = true,
}) {
  return Dialog3D.show<bool>(
    context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => Dialog3D(
      tone: ListingTone.coral,
      art: art,
      title: title,
      body: body,
      secondaryLabel: cancelLabel,
      onSecondary: () => Navigator.of(ctx).pop(false),
      primaryLabel: confirmLabel,
      primaryDanger: destructive,
      tight: true,
      familyCorner: true,
      onPrimary: () => Navigator.of(ctx).pop(true),
    ),
  );
}
