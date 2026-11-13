import 'package:flutter/material.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'pill_buttons_3d.dart';
import 'skeleton_3d.dart';

abstract final class Report3D {
  static ListingTone tone(String listingType) => switch (listingType) {
    'Stay' => ListingTone.forest,
    'Taxi' => ListingTone.coral,
    _ => ListingTone.indigo,
  };

  static Color page(String listingType) => switch (listingType) {
    'Stay' => ListingPalette.forest.page,
    'Taxi' => ListingPalette.coral.page,
    _ => ListingPalette.indigo.page,
  };

  static const Color indigoPage = Color(0xFFF2F3F8);

  static String art(String listingType) => switch (listingType) {
    'Stay' => ListingArt.hotel,
    'Taxi' => ListingArt.taxi,
    'Job' => ListingArt.luggage,
    _ => ListingArt.clipboard,
  };

  static const Color pendingText = Color(0xFFB26A00);
  static const Color pendingDot = Color(0xFFF59E0B);
  static const Color resolvedText = Color(0xFF1E7A3C);
  static const Color resolvedDot = Color(0xFF22A55A);

  static const Color fieldFill = Color(0xFFF4F5FA);
  static const Color fieldLine = Color(0xFFE3E6EE);
  static const Color warnFill = Color(0xFFFFF1DE);
  static const Color warnText = Color(0xFF6A4A1A);
  static const Color menuShadow = Color(0x33000000);

  static const BoxDecoration sheetDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    boxShadow: [BoxShadow(color: menuShadow, offset: Offset(0, -4), blurRadius: 24)],
  );

  static const BorderRadius wideRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));
  static const BorderRadius noteRadius = BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));

  static bool pending(String status) => status == 'Pending';
  static Color statusText(String status) => pending(status) ? pendingText : resolvedText;
  static Color statusDot(String status) => pending(status) ? pendingDot : resolvedDot;
}

class ReportHeader3D extends StatelessWidget {
  const ReportHeader3D({super.key, required this.tone, required this.title, this.subtitle, this.onBack});

  final ListingTone tone;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final art = narrow ? 80.0 : 104.0;
    final tip = MaterialLocalizations.of(context).backButtonTooltip;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: narrow ? 118 : 140),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 8,
            top: 0,
            child: ExcludeSemantics(child: Art3D(asset: ListingArt.clipboard, size: art, halo: art + 6, haloColor: tone.halo, haloDy: 4, shadowAlpha: 0.24)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 12, art + 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: tip,
                  excludeFromSemantics: true,
                  child: Tap3D(
                    onTap: onBack,
                    label: tip,
                    exclude: true,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: Ink3D.softShadow),
                      child: Icon(Icons.chevron_left_rounded, size: 28, color: tone.text),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(narrow ? 20 : 22, FontWeight.w700, Ink3D.title, height: 1.2)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 18),
                            child: Text(subtitle ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.sub, letterSpacing: 0, height: 1.45)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReportCountLabel extends StatelessWidget {
  const ReportCountLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, Ink3D.sub, letterSpacing: 0.6)),
    );
  }
}

class ReportStatusPill extends StatelessWidget {
  const ReportStatusPill({super.key, required this.status, this.plain = false});

  final String status;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: plain ? 9 : 10, height: plain ? 9 : 10, decoration: BoxDecoration(shape: BoxShape.circle, color: Report3D.statusDot(status))),
        SizedBox(width: plain ? 8 : 7),
        Flexible(
          child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(plain ? 14.5 : 13, plain ? FontWeight.w600 : FontWeight.w700, Report3D.statusText(status), height: 1.4)),
        ),
      ],
    );
    if (plain) return row;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: Ink3D.whiteBtn),
      child: row,
    );
  }
}

class ReportCard3D extends StatelessWidget {
  const ReportCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    required this.subtitle,
    required this.status,
    this.eyebrow,
    this.onTap,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String subtitle;
  final String status;
  final String? eyebrow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final artSize = narrow ? 112.0 : 144.0;
    final left = narrow ? 128.0 : 160.0;
    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: Report3D.wideRadius, boxShadow: tone.glow()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: Padding(
              padding: EdgeInsets.fromLTRB(left, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 14 * scale),
                    child: Text((eyebrow ?? '').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w700, Colors.white.withValues(alpha: 0.9), letterSpacing: 0.6, height: 1.3)),
                  ),
                  const SizedBox(height: 2),
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: 46 * scale),
                    child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(19, FontWeight.w700, Colors.white, height: 1.2)),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white.withValues(alpha: 0.96), height: 1.5)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              children: [
                Flexible(child: Align(alignment: Alignment.centerLeft, child: ReportStatusPill(status: status))),
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(color: Color(0xFFFAFAFA), shape: BoxShape.circle, boxShadow: Ink3D.goBtn),
                  child: Icon(Icons.arrow_forward_rounded, size: 24, color: tone.button),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 66, 14, 8),
      child: Tap3D(
        onTap: onTap,
        label: '${eyebrow == null || eyebrow!.isEmpty ? '' : '$eyebrow, '}$title, $subtitle, $status',
        exclude: true,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            Positioned(
              left: 6,
              top: narrow ? -40 : -52,
              child: ExcludeSemantics(child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: const Color(0x3DFAFAFA), haloDy: 3)),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportCardSkeleton extends StatelessWidget {
  const ReportCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artSize = narrow ? 112.0 : 144.0;
    final left = narrow ? 128.0 : 160.0;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 66, 14, 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFE3E6EE), Color(0xFFF1F2F7), Color(0xFFE3E6EE)], stops: [0.2, 0.4, 0.6]),
                borderRadius: Report3D.wideRadius,
                boxShadow: [BoxShadow(color: Color(0x409E9E9E), offset: Offset(1.1, 4), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 112,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(left, 18, 20, 0),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 60, height: 10, radius: 5),
                          SizedBox(height: 10),
                          SkeletonBox(width: 150, height: 20, radius: 7),
                          SizedBox(height: 10),
                          SkeletonBox(width: 110, height: 14, radius: 7),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SkeletonBox(width: 104, height: 30, radius: 16),
                        SkeletonBox(width: 42, height: 42, radius: 21),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 4,
              top: narrow ? -40 : -52,
              child: SkeletonBox(width: artSize, height: artSize, radius: artSize / 2),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportReasonCard extends StatelessWidget {
  const ReportReasonCard({super.key, required this.tone, required this.label, required this.reason});

  final ListingTone tone;
  final String label;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artSize = narrow ? 112.0 : 144.0;
    final left = narrow ? 128.0 : 160.0;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 66, 14, 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 124),
            padding: EdgeInsets.fromLTRB(left, 24, 20, 18),
            decoration: BoxDecoration(gradient: tone.gradient, borderRadius: Report3D.wideRadius, boxShadow: tone.glow()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w700, Colors.white.withValues(alpha: 0.9), letterSpacing: 0.6, height: 1.3)),
                const SizedBox(height: 2),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 52 * scale),
                  child: Text(reason, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(narrow ? 19 : 21, FontWeight.w700, Colors.white, height: 1.24)),
                ),
              ],
            ),
          ),
          Positioned(
            left: 6,
            top: narrow ? -40 : -52,
            child: ExcludeSemantics(child: Art3D(asset: ListingArt.pushpin, size: artSize, halo: artSize + 4, haloColor: const Color(0x3DFAFAFA), haloDy: 3)),
          ),
        ],
      ),
    );
  }
}

class ReportNote3D extends StatelessWidget {
  const ReportNote3D({super.key, required this.art, required this.text, required this.fill, required this.color, this.margin = const EdgeInsets.fromLTRB(18, 22, 18, 0)});

  final String art;
  final String text;
  final Color fill;
  final Color color;
  final EdgeInsets margin;

  factory ReportNote3D.privacy({Key? key, required ListingTone tone, required String text}) =>
      ReportNote3D(key: key, art: ListingArt.key, text: text, fill: tone.haloBase.withValues(alpha: 0.13), color: Ink3D.sub);

  factory ReportNote3D.warn({Key? key, required String text}) =>
      ReportNote3D(key: key, art: ListingArt.star, text: text, fill: Report3D.warnFill, color: Report3D.warnText, margin: EdgeInsets.zero);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(color: fill, borderRadius: Report3D.noteRadius),
      child: Row(
        children: [
          ExcludeSemantics(child: Art3D(asset: art, size: 40, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Ink3D.text(12.5, FontWeight.w500, color, letterSpacing: 0, height: 1.4))),
        ],
      ),
    );
  }
}

class ReportSheetBand extends StatelessWidget {
  const ReportSheetBand({super.key, required this.tone, required this.title});

  final ListingTone tone;
  final String title;

  static const double artRoom = 80;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 146),
      padding: const EdgeInsets.fromLTRB(24, 70, 24, 22),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      alignment: Alignment.bottomCenter,
      child: Semantics(
        header: true,
        child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(22, FontWeight.w700, Colors.white, height: 1.25)),
      ),
    );
  }
}

class ReportSheetArt extends StatelessWidget {
  const ReportSheetArt({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: Art3D(asset: ListingArt.pushpin, size: 136, halo: 140, haloColor: Color(0x4DFFFFFF), haloDy: 3, shadowBlur: 7, shadowOffset: Offset(5, 9), shadowAlpha: 0.3),
    );
  }
}

abstract final class ReportField3D {
  static OutlineInputBorder _border(double r, Color c, double w) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(r), borderSide: BorderSide(color: c, width: w));

  static TextStyle get text => Ink3D.text(15, FontWeight.w400, Ink3D.body, letterSpacing: 0);
  static TextStyle get hint => Ink3D.text(15, FontWeight.w400, Form3D.hint, letterSpacing: 0);

  static InputDecorationTheme pickerTheme(ListingTone tone) => InputDecorationTheme(
    hintStyle: hint,
    filled: true,
    fillColor: Report3D.fieldFill,
    contentPadding: const EdgeInsets.fromLTRB(22, 16, 8, 16),
    border: _border(28, Report3D.fieldLine, 1),
    enabledBorder: _border(28, Report3D.fieldLine, 1),
    focusedBorder: _border(28, tone.g2, 1.5),
  );

  static Widget caret(ListingTone tone) => Container(
    width: 40,
    height: 40,
    margin: const EdgeInsets.only(right: 8),
    decoration: BoxDecoration(gradient: tone.gradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: tone.g2.withValues(alpha: 0.45), offset: const Offset(2, 4), blurRadius: 8)]),
    child: const Icon(Icons.arrow_drop_down_rounded, size: 24, color: Colors.white),
  );

  static MenuStyle menuStyle = const MenuStyle(
    backgroundColor: WidgetStatePropertyAll(Colors.white),
    surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
    shadowColor: WidgetStatePropertyAll(Report3D.menuShadow),
    elevation: WidgetStatePropertyAll(8),
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)), side: BorderSide(color: Report3D.fieldLine))),
  );

  static ButtonStyle entryStyle(ListingTone tone, bool selected) => ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20)),
    backgroundColor: WidgetStatePropertyAll(selected ? tone.haloBase.withValues(alpha: 0.12) : Colors.white),
    foregroundColor: WidgetStatePropertyAll(selected ? tone.text : Ink3D.body),
    textStyle: WidgetStatePropertyAll(Ink3D.text(15, selected ? FontWeight.w700 : FontWeight.w500, selected ? tone.text : Ink3D.body, letterSpacing: 0)),
  );

  static Widget check(ListingTone tone) => Icon(Icons.check_rounded, size: 20, color: tone.text);

  static InputDecoration area(ListingTone tone, {required String hintText, required bool focused}) => InputDecoration(
    hintText: hintText,
    hintStyle: Ink3D.text(14.5, FontWeight.w400, Form3D.hint, letterSpacing: 0),
    filled: true,
    fillColor: focused ? Colors.white : Report3D.fieldFill,
    contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    border: _border(24, Report3D.fieldLine, 1),
    enabledBorder: _border(24, Report3D.fieldLine, 1),
    focusedBorder: _border(24, tone.g2, 1.5),
    counterStyle: Ink3D.text(12, FontWeight.w400, Form3D.hint, letterSpacing: 0),
  );

  static TextStyle get areaText => Ink3D.text(14.5, FontWeight.w400, Ink3D.body, letterSpacing: 0, height: 1.5);
}
