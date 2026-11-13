import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'motion_kit.dart';
import 'pill_buttons_3d.dart';

abstract final class AuthInk {
  static const Color page = Color(0xFFF2F3F8);
  static const Color input = Color(0xFF253840);
  static const Color warn = Color(0xFFE07A00);
  static const Color box = Color(0xFFC3C7D0);
  static const Color linkOff = Color(0xFFB0B4BD);
  static const Color ringBad = Color(0xFFFA7D82);
  static const Color pendBg = Color(0xFFE6E8FB);
  static const Color pendText = Color(0xFF2633C5);
  static const Color badBg = Color(0xFFFFE6E8);
  static const Color badText = Color(0xFFB83A40);
  static const Color laterBg = Color(0xFFFFF1DE);
  static const Color laterText = Color(0xFFA55B00);
  static const Color bone = Color(0xFFE3E6EE);
  static const Color boneLight = Color(0xFFEEF0F5);
  static const Color boneLine = Color(0xFFF4F5F9);
  static const String automobile = 'assets/images/design/travel3d/automobile.png';

  static const BorderRadius cardRadius =
      BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8));
  static const List<BoxShadow> cardShadow = [BoxShadow(color: Color(0x4D9E9E9E), offset: Offset(1.1, 4), blurRadius: 16)];
  static const List<BoxShadow> chipShadow = [BoxShadow(color: Color(0x4D9E9E9E), offset: Offset(2, 4), blurRadius: 8)];
  static const List<BoxShadow> artShadow = [BoxShadow(color: Color(0x40000000), offset: Offset(3, 4), blurRadius: 6)];

  static List<BoxShadow> heroShadow(ListingTone tone) => [BoxShadow(color: tone.haloBase.withValues(alpha: 0.35), offset: const Offset(0, 8), blurRadius: 20)];
  static List<BoxShadow> focusShadow(Color c) => [BoxShadow(color: c.withValues(alpha: 0.22), offset: const Offset(3, 6), blurRadius: 12)];
  static Color white(double a) => Colors.white.withValues(alpha: a);

  static ListingTone lerp(ListingTone a, ListingTone b, double t) => ListingTone(
        g1: Color.lerp(a.g1, b.g1, t)!,
        g2: Color.lerp(a.g2, b.g2, t)!,
        shadow: Color.lerp(a.shadow, b.shadow, t)!,
        haloBase: Color.lerp(a.haloBase, b.haloBase, t)!,
        text: Color.lerp(a.text, b.text, t)!,
      );

  static Color pageOf(ListingTone tone) {
    if (identical(tone, ListingTone.forest)) return ListingPalette.forest.page;
    if (identical(tone, ListingTone.coral)) return ListingPalette.coral.page;
    return page;
  }
}

/// Lays out [hero] above [card]: the card overlaps the hero by [overlap], sits [bottomGap] above the bottom,
/// and the hero takes the rest of [minHeight] (never less than [minHero]).
class AuthHeroLayout extends MultiChildRenderObjectWidget {
  AuthHeroLayout({super.key, required Widget hero, required Widget card, required this.minHeight, required this.minHero, this.overlap = 48, this.bottomGap = 24})
      : super(children: [hero, card]);

  final double minHeight;
  final double minHero;
  final double overlap;
  final double bottomGap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderAuthHero(minHeight, minHero, overlap, bottomGap);

  @override
  void updateRenderObject(BuildContext context, RenderAuthHero renderObject) {
    renderObject
      ..minHeight = minHeight
      ..minHero = minHero
      ..overlap = overlap
      ..bottomGap = bottomGap;
  }
}

class _AuthHeroData extends ContainerBoxParentData<RenderBox> {}

class RenderAuthHero extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _AuthHeroData>, RenderBoxContainerDefaultsMixin<RenderBox, _AuthHeroData> {
  RenderAuthHero(this._minHeight, this._minHero, this._overlap, this._bottomGap);

  double _minHeight;
  double _minHero;
  double _overlap;
  double _bottomGap;

  set minHeight(double v) {
    if (v == _minHeight) return;
    _minHeight = v;
    markNeedsLayout();
  }

  set minHero(double v) {
    if (v == _minHero) return;
    _minHero = v;
    markNeedsLayout();
  }

  set overlap(double v) {
    if (v == _overlap) return;
    _overlap = v;
    markNeedsLayout();
  }

  set bottomGap(double v) {
    if (v == _bottomGap) return;
    _bottomGap = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _AuthHeroData) child.parentData = _AuthHeroData();
  }

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    final hero = firstChild!;
    final card = childAfter(hero)!;
    card.layout(BoxConstraints(minWidth: w, maxWidth: w), parentUsesSize: true);
    final c = card.size.height;
    final heroH = math.max(_minHero, _minHeight - c - _bottomGap + _overlap);
    hero.layout(BoxConstraints.tightFor(width: w, height: heroH));
    (hero.parentData! as _AuthHeroData).offset = Offset.zero;
    (card.parentData! as _AuthHeroData).offset = Offset(0, heroH - _overlap);
    size = constraints.constrain(Size(w, heroH - _overlap + c + _bottomGap));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

class AuthHeroScaffold extends StatelessWidget {
  const AuthHeroScaffold({super.key, required this.hero, required this.card});

  final Widget hero;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AuthInk.page,
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: AuthHeroLayout(
                minHeight: box.maxHeight,
                minHero: AuthHero.minHeight(context),
                bottomGap: 24 + MediaQuery.paddingOf(context).bottom,
                hero: hero,
                card: card,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthHero extends StatelessWidget {
  const AuthHero({super.key, required this.tone, required this.art, required this.title, required this.subtitle, this.smallTitle = false, this.onBack});

  final ListingTone tone;
  final String art;
  final String title;
  final String subtitle;
  final bool smallTitle;
  final VoidCallback? onBack;

  static double topPad(BuildContext context) => MediaQuery.paddingOf(context).top + 78;

  static double minHeight(BuildContext context) {
    final s = MediaQuery.textScalerOf(context).scale(1);
    return topPad(context) + 70 + 130 + 70 * s;
  }

  @override
  Widget build(BuildContext context) {
    final top = topPad(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: AuthInk.heroShadow(tone),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(22, top, 22, 70),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ExcludeSemantics(
                        child: Art3D(asset: art, size: 220, halo: 232, haloColor: AuthInk.white(0.18), shadowBlur: 8, shadowOffset: const Offset(6, 10), shadowAlpha: 0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(smallTitle ? 24 : 30, FontWeight.w700, Colors.white, height: 1.15),
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(14, FontWeight.w400, AuthInk.white(0.92), height: 1.35)),
              ],
            ),
          ),
          if (onBack != null)
            Positioned(
              left: 18,
              top: top,
              child: Tooltip(
                message: 'Back',
                child: Tap3D(
                  onTap: onBack,
                  label: 'Back',
                  exclude: true,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: AuthInk.white(0.25), shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_left_rounded, size: 30, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.children, this.fixedHeight});

  final List<Widget> children;
  final double? fixedHeight;

  @override
  Widget build(BuildContext context) {
    final fixed = fixedHeight;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      constraints: BoxConstraints(minHeight: fixed ?? 0),
      padding: fixed != null ? const EdgeInsets.fromLTRB(24, 26, 24, 22) : const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: AuthInk.cardRadius, boxShadow: AuthInk.cardShadow),
      child: Column(
        mainAxisAlignment: fixed != null ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class AuthHeading extends StatelessWidget {
  const AuthHeading(this.title, {super.key, required this.tone, this.onBack});

  final String title;
  final ListingTone tone;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: onBack != null ? 36 : 28),
      child: Row(
        children: [
          if (onBack != null) ...[
            Tooltip(
              message: 'Back',
              child: Tap3D(
                onTap: onBack,
                label: 'Back',
                exclude: true,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: AuthInk.page, shape: BoxShape.circle),
                      child: Icon(Icons.chevron_left_rounded, size: 24, color: tone.text),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Ink3D.text(19, FontWeight.w700, Ink3D.title, height: 1.3)),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthCaption extends StatelessWidget {
  const AuthCaption(this.text, {super.key, this.lines});

  final String text;
  final int? lines;

  @override
  Widget build(BuildContext context) {
    final style = Ink3D.text(13, FontWeight.w400, Ink3D.grey, height: 1.45);
    final t = Text(text, style: style);
    final l = lines;
    if (l == null) return Padding(padding: const EdgeInsets.only(top: 4), child: t);
    final h = MediaQuery.textScalerOf(context).scale(13) * 1.45 * l;
    return Padding(padding: const EdgeInsets.only(top: 4), child: ConstrainedBox(constraints: BoxConstraints(minHeight: h), child: t));
  }
}

class AuthWarnLine extends StatelessWidget {
  const AuthWarnLine(this.text, {super.key});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.textScalerOf(context).scale(13) * 1.5;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        height: h,
        child: Text(text ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, AuthInk.warn, height: 1.5)),
      ),
    );
  }
}

class AuthArtLine extends StatelessWidget {
  const AuthArtLine({super.key, required this.art, required this.text});

  final String art;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Image.asset(art, width: 22, height: 22),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: Ink3D.text(13, FontWeight.w600, Ink3D.sub, height: 1.4))),
        ],
      ),
    );
  }
}

class AuthNumberChip extends StatelessWidget {
  const AuthNumberChip({super.key, required this.tone, required this.art, required this.text});

  final ListingTone tone;
  final String art;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
        decoration: BoxDecoration(color: AuthInk.page, borderRadius: BorderRadius.circular(22)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(art, width: 30, height: 30),
            const SizedBox(width: 8),
            Flexible(child: Text(text, style: Ink3D.text(15, FontWeight.w700, tone.text, letterSpacing: 0.8))),
          ],
        ),
      ),
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 0, 8),
        child: Text(text, style: Ink3D.text(13, FontWeight.w600, Ink3D.sub)),
      );
}

/// Pill input (`.inp`): grey pill, white with a tone ring on focus, red ring when [bad].
class AuthPillInput extends StatefulWidget {
  const AuthPillInput({
    super.key,
    required this.tone,
    required this.child,
    required this.focusNode,
    this.prefix,
    this.leadingArt,
    this.bad = false,
  });

  final ListingTone tone;
  final Widget child;
  final FocusNode focusNode;
  final Widget? prefix;
  final String? leadingArt;
  final bool bad;

  static TextStyle textStyle = Ink3D.text(17, FontWeight.w600, AuthInk.input, letterSpacing: 0.6);
  static TextStyle nameStyle = Ink3D.text(17, FontWeight.w600, AuthInk.input, letterSpacing: 0);
  static TextStyle hintStyle = Ink3D.text(17, FontWeight.w500, Form3D.hint, letterSpacing: 0);

  static InputDecoration decoration(String hint) => InputDecoration(
        isCollapsed: true,
        filled: false,
        hintText: hint,
        hintStyle: hintStyle,
        counterText: '',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
      );

  @override
  State<AuthPillInput> createState() => _AuthPillInputState();
}

class _AuthPillInputState extends State<AuthPillInput> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant AuthPillInput old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focus = widget.focusNode.hasFocus;
    final ring = widget.bad ? AuthInk.ringBad : (focus ? widget.tone.g1 : null);
    final art = widget.leadingArt;
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(8, 6, 18, 6),
      decoration: BoxDecoration(
        color: ring != null ? Colors.white : AuthInk.page,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: ring ?? Colors.transparent, width: 2),
        boxShadow: ring != null ? AuthInk.focusShadow(widget.bad ? AuthInk.ringBad : widget.tone.haloBase) : null,
      ),
      child: Row(
        children: [
          if (widget.prefix != null) ...[widget.prefix!, const SizedBox(width: 10)],
          if (art != null) ...[
            ExcludeSemantics(child: Art3D(asset: art, size: 42, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
            const SizedBox(width: 10),
          ],
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class AuthCountryCode extends StatelessWidget {
  const AuthCountryCode({super.key, required this.tone});

  final ListingTone tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: AuthInk.chipShadow),
        child: Text('+91', style: Ink3D.text(14, FontWeight.w700, tone.text, letterSpacing: 0)),
      );
}

class AuthAgreeRow extends StatelessWidget {
  const AuthAgreeRow({super.key, required this.tone, required this.value, required this.onChanged, required this.onTerms, required this.onPrivacy});

  final ListingTone tone;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final base = Ink3D.text(13, FontWeight.w400, Ink3D.grey, height: 1.55);
    final link = Ink3D.text(13, FontWeight.w600, tone.text, height: 1.55).copyWith(decoration: TextDecoration.underline, decorationColor: tone.text);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          checked: value,
          label: 'I agree to the Terms of Service and Privacy Policy',
          onTap: () => onChanged(!value),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!value),
            child: Padding(
              padding: const EdgeInsets.only(top: 1, right: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: value ? tone.gradient : null,
                  border: value ? null : Border.all(color: AuthInk.box, width: 2),
                  boxShadow: value ? tone.glow(blur: 6, dy: 3) : null,
                ),
                child: value ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Text.rich(
              TextSpan(style: base, children: [
                const TextSpan(text: 'I agree to the '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(onTap: onTerms, child: Text('Terms of Service', textScaler: TextScaler.noScaling, style: link)),
                ),
                const TextSpan(text: ' and '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(onTap: onPrivacy, child: Text('Privacy Policy', textScaler: TextScaler.noScaling, style: link)),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthTextLink extends StatelessWidget {
  const AuthTextLink({super.key, required this.tone, required this.label, required this.onTap});

  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: Semantics(
          button: true,
          enabled: on,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 34, minWidth: 120),
              child: Center(
                child: Text(label, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w600, on ? tone.text : AuthInk.linkOff)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthVerifiedRow extends StatelessWidget {
  const AuthVerifiedRow({super.key, required this.text, required this.art});

  final String text;
  final String art;

  @override
  Widget build(BuildContext context) {
    final ok = ListingTone.forest;
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(color: AuthInk.page, borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          ExcludeSemantics(child: Art3D(asset: art, size: 42, shadowBlur: 3, shadowOffset: const Offset(2, 4))),
          const SizedBox(width: 10),
          Expanded(child: FitLine3D(text: text, style: Ink3D.text(16, FontWeight.w600, AuthInk.input))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(gradient: ok.gradient, borderRadius: BorderRadius.circular(14), boxShadow: ok.glow(blur: 6, dy: 3)),
            child: Text('Verified', style: Ink3D.text(12, FontWeight.w700, Colors.white)),
          ),
        ],
      ),
    );
  }
}

abstract final class AuthPins {
  static double boxSize(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return ((w - 36 - 48 - 36) / 4).clamp(48.0, 64.0);
  }

  static PinTheme base(double s) => PinTheme(
        width: s,
        height: s,
        textStyle: Ink3D.text(26, FontWeight.w700, Ink3D.title),
        decoration: BoxDecoration(color: AuthInk.page, borderRadius: BorderRadius.circular(18)),
      );

  static PinTheme focused(ListingTone tone, double s) => PinTheme(
        width: s,
        height: s,
        textStyle: Ink3D.text(26, FontWeight.w700, Ink3D.title),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.g1, width: 2),
          boxShadow: AuthInk.focusShadow(tone.haloBase),
        ),
      );

  static PinTheme submitted(ListingTone tone, double s) => PinTheme(
        width: s,
        height: s,
        textStyle: Ink3D.text(26, FontWeight.w700, Colors.white),
        decoration: BoxDecoration(gradient: tone.gradient, borderRadius: BorderRadius.circular(18), boxShadow: tone.glow(blur: 8)),
      );

  static Widget cursor(ListingTone tone) => Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            width: 22,
            height: 3,
            decoration: BoxDecoration(color: tone.g2, borderRadius: BorderRadius.circular(2)),
          ),
        ],
      );
}

class AuthDialogNumber extends StatelessWidget {
  const AuthDialogNumber({super.key, required this.tone, required this.text, this.viaArt, this.viaText});

  final ListingTone tone;
  final String text;
  final String? viaArt;
  final String? viaText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(color: AuthInk.page, borderRadius: BorderRadius.circular(16)),
          child: Text(text, style: Ink3D.text(19, FontWeight.w700, tone.text, letterSpacing: 1.5)),
        ),
        if (viaText != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (viaArt != null) ...[Image.asset(viaArt!, width: 22, height: 22), const SizedBox(width: 6)],
              Text(viaText!, style: Ink3D.text(13, FontWeight.w600, Ink3D.sub)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Role card (`.rc`): gradient card, art over a halo hanging 32 above, badge slot, name, three-line description slot.
class AuthRoleCard extends StatelessWidget {
  const AuthRoleCard({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    required this.description,
    this.selected = false,
    this.badge,
    this.dimmed = false,
    this.onTap,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String description;
  final bool selected;
  final String? badge;
  final bool dimmed;
  final VoidCallback? onTap;

  static const double topRoom = 32;
  static final TextStyle _descStyle = Ink3D.text(12.5, FontWeight.w500, AuthInk.white(0.95), height: 1.35);

  @override
  Widget build(BuildContext context) {
    final scope = AuthRoleDescLines.maybeOf(context);
    if (scope == null) return _build(context, 3);
    return LayoutBuilder(builder: (context, box) {
      final narrow = MediaQuery.sizeOf(context).width < 340;
      final textW = box.maxWidth - (narrow ? 116.0 : 134.0) - 58;
      return _build(context, scope.linesFor(textW, MediaQuery.textScalerOf(context)));
    });
  }

  Widget _build(BuildContext context, int descLines) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artSize = narrow ? 96.0 : 112.0;
    final left = narrow ? 116.0 : 134.0;
    final scaler = MediaQuery.textScalerOf(context);
    final descH = (scaler.scale(12.5) * 1.35 * descLines).ceilToDouble() + 2;
    final b = badge;
    final text = Padding(
      padding: EdgeInsets.fromLTRB(left, 12, 58, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: scaler.scale(10.5) * 1.75,
            child: b == null
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
                      decoration: BoxDecoration(color: AuthInk.white(0.3), borderRadius: BorderRadius.circular(9)),
                      child: Text(b, style: Ink3D.text(10.5, FontWeight.w700, Colors.white, letterSpacing: 0.8)),
                    ),
                  ),
          ),
          SizedBox(
            height: scaler.scale(20) * 1.3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FitLine3D(text: title, stretch: 1.5, style: Ink3D.text(20, FontWeight.w700, Colors.white, height: 1.3)),
            ),
          ),
          const SizedBox(height: 3),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: descH),
            child: Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: _descStyle),
          ),
        ],
      ),
    );
    final card = Opacity(
      opacity: dimmed ? 0.82 : 1,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 116),
        decoration: BoxDecoration(gradient: tone.gradient, borderRadius: AuthInk.cardRadius, boxShadow: selected ? tone.glow(blur: 16, dy: 8) : tone.glow()),
        child: text,
      ),
    );
    const ringR = BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(58), bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12));
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '$title. $description${b != null ? '. $b' : ''}',
      excludeSemantics: true,
      child: PressScale(
        enabled: onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(top: topRoom),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (selected)
                  Positioned(
                    left: -6,
                    top: -6,
                    right: -6,
                    bottom: -6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: ringR,
                        border: Border.all(color: tone.g2, width: 3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(9), topRight: Radius.circular(55), bottomLeft: Radius.circular(9), bottomRight: Radius.circular(9)),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                  ),
                card,
                Positioned(
                  left: narrow ? 8 : 10,
                  top: -topRoom,
                  child: IgnorePointer(
                    child: Art3D(asset: art, size: artSize, halo: artSize, haloColor: AuthInk.white(0.24)),
                  ),
                ),
                if (selected)
                  Positioned(
                    right: 18,
                    top: 24,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AuthInk.artShadow),
                      child: Icon(Icons.check_rounded, size: 18, color: tone.g2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sibling role cards reserve the line count of the longest description so they stay the same height.
class AuthRoleDescLines extends InheritedWidget {
  const AuthRoleDescLines({super.key, required this.descriptions, required super.child});

  final List<String> descriptions;

  static AuthRoleDescLines? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AuthRoleDescLines>();

  int linesFor(double width, TextScaler scaler) {
    var lines = 1;
    for (final d in descriptions) {
      final tp = TextPainter(
        text: TextSpan(text: d, style: AuthRoleCard._descStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 3,
      )..layout(maxWidth: math.max(1, width));
      lines = math.max(lines, tp.computeLineMetrics().length);
      tp.dispose();
    }
    return lines.clamp(1, 3);
  }

  @override
  bool updateShouldNotify(AuthRoleDescLines old) => !listEquals(old.descriptions, descriptions);
}

class AuthRoleSkeleton extends StatelessWidget {
  const AuthRoleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final left = narrow ? 116.0 : 134.0;
    Widget line(double f) => FractionallySizedBox(
          widthFactor: f,
          child: Container(height: 14, margin: const EdgeInsets.only(top: 10), decoration: BoxDecoration(color: AuthInk.boneLine, borderRadius: BorderRadius.circular(7))),
        );
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: AuthRoleCard.topRoom),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              height: 116,
              padding: EdgeInsets.fromLTRB(left, 14, 50, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AuthInk.bone, AuthInk.boneLight, AuthInk.bone]),
                borderRadius: AuthInk.cardRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.4, child: Container(height: 14, decoration: BoxDecoration(color: AuthInk.boneLine, borderRadius: BorderRadius.circular(7))))),
                  line(0.8),
                  line(0.6),
                ],
              ),
            ),
            Positioned(
              left: 8,
              top: -AuthRoleCard.topRoom,
              child: Container(width: narrow ? 96 : 112, height: narrow ? 96 : 112, decoration: const BoxDecoration(color: AuthInk.bone, shape: BoxShape.circle)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gradient state card (`.stc`) that fills the list area; the button slot keeps its height without an action.
class AuthStateCard extends StatelessWidget {
  const AuthStateCard({super.key, required this.tone, required this.art, required this.title, this.actionLabel, this.onAction});

  final ListingTone tone;
  final String art;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: AuthInk.cardRadius, boxShadow: [BoxShadow(color: tone.haloBase.withValues(alpha: 0.5), offset: const Offset(1.1, 4), blurRadius: 12)]),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Art3D(asset: art, size: 190, halo: 210, haloColor: AuthInk.white(0.2), shadowBlur: 8, shadowOffset: const Offset(6, 10), shadowAlpha: 0.3),
              ),
              const SizedBox(height: 20),
              Text(title, textAlign: TextAlign.center, style: Ink3D.text(22, FontWeight.w700, Colors.white, height: 1.3)),
              const SizedBox(height: 22),
              SizedBox(
                width: 180,
                child: Visibility(
                  visible: label != null,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: WhitePillButton(tone: tone, label: label ?? '', onTap: onAction, onGradient: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum AuthStripKind { pending, bad, later }

class AuthStatusStrip extends StatelessWidget {
  const AuthStatusStrip({super.key, required this.kind, required this.art, required this.title, this.message = ''});

  final AuthStripKind kind;
  final String art;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      AuthStripKind.pending => (AuthInk.pendBg, AuthInk.pendText),
      AuthStripKind.bad => (AuthInk.badBg, AuthInk.badText),
      AuthStripKind.later => (AuthInk.laterBg, AuthInk.laterText),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(24), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: Art3D(asset: art, size: 46, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Ink3D.text(14, FontWeight.w700, fg, height: 1.35)),
                if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(message, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub, height: 1.35))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Page header of the role pages (`.rhead`): art over a halo, title, one-line subtitle slot, optional back button.
class AuthRoleHeader extends StatelessWidget {
  const AuthRoleHeader({super.key, required this.tone, required this.art, required this.title, required this.subtitle, this.onBack});

  final ListingTone tone;
  final String art;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final art = h < 760 ? 64.0 : (h < 820 ? 76.0 : 120.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: ExcludeSemantics(child: Art3D(asset: this.art, size: art, halo: art, haloColor: tone.halo))),
              const SizedBox(height: 8),
              Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(24, FontWeight.w700, Ink3D.title, height: 1.3, letterSpacing: 0.27))),
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w400, Ink3D.sub, height: 1.4)),
            ],
          ),
          if (onBack != null)
            Positioned(
              left: 0,
              top: 0,
              child: Tooltip(
                message: 'Back',
                child: Tap3D(
                  onTap: onBack,
                  label: 'Back',
                  exclude: true,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: Ink3D.softShadow),
                    child: Icon(Icons.chevron_left_rounded, size: 26, color: tone.text),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Intro slide card (`.icw`): gradient card 200 high, art over a halo hanging 64 above the right, title, one content box.
class IntroCard3D extends StatelessWidget {
  const IntroCard3D({super.key, required this.tone, required this.art, required this.title, required this.child, this.artScale = 1});

  final ListingTone tone;
  final String art;
  final String title;
  final Widget child;
  final double artScale;

  static const double topRoom = 64;
  static const double cardHeight = 200;
  static const double height = topRoom + cardHeight;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artSize = narrow ? 104.0 : 122.0;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: topRoom,
            height: cardHeight,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(gradient: tone.gradient, borderRadius: AuthInk.cardRadius, boxShadow: tone.glow()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 26,
                    child: Padding(
                      padding: EdgeInsets.only(right: artSize + 12),
                      child: FitLine3D(text: title, stretch: 1.5, style: Ink3D.text(20, FontWeight.w700, Colors.white, height: 1.3)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(child: Center(child: child)),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 0,
            child: IgnorePointer(
              child: Transform.scale(
                scale: artScale,
                child: Art3D(asset: art, size: artSize, halo: artSize + 6, haloColor: AuthInk.white(0.22), shadowAlpha: 0.28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IntroChip3D extends StatelessWidget {
  const IntroChip3D({super.key, required this.tone, required this.label, this.on = false});

  final ListingTone tone;
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: on ? Colors.white : AuthInk.white(0.24), borderRadius: BorderRadius.circular(12)),
        child: Text(label, maxLines: 1, style: Ink3D.text(11, FontWeight.w700, on ? tone.g2 : Colors.white, height: 16 / 11)),
      );
}

class IntroPill3D extends StatelessWidget {
  const IntroPill3D({super.key, required this.tone, required this.label, this.ghost = false, this.icon});

  final ListingTone tone;
  final String label;
  final bool ghost;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = ghost ? Colors.white : tone.g2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: ghost ? AuthInk.white(0.24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ghost ? null : Ink3D.whiteBtn,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 4)],
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, color))),
        ],
      ),
    );
  }
}

class IntroRow3D extends StatelessWidget {
  const IntroRow3D({super.key, required this.tone, required this.label, required this.done});

  final ListingTone tone;
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? Colors.white : Colors.transparent,
              border: done ? null : Border.all(color: AuthInk.white(0.75), width: 2),
            ),
            child: done ? Icon(Icons.check_rounded, size: 13, color: tone.g2) : null,
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, Colors.white))),
        ],
      ),
    );
  }
}

class IntroRing3D extends StatelessWidget {
  const IntroRing3D({super.key, required this.tone, required this.label, this.value = 0.03});

  final ListingTone tone;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 92,
        child: CustomPaint(
          painter: _IntroRingPainter(value: value, fill: tone.g2),
          child: Center(child: Text(label, maxLines: 1, style: Ink3D.text(24, FontWeight.w700, Colors.white))),
        ),
      );
}

class _IntroRingPainter extends CustomPainter {
  const _IntroRingPainter({required this.value, required this.fill});

  final double value;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = AuthInk.white(0.3));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * value, true, Paint()..color = Colors.white);
    canvas.drawCircle(c, r - 8, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(covariant _IntroRingPainter old) => old.value != value || old.fill != fill;
}

/// Day track of the plan slide (`.itr`): white line with three nodes, labels, the car and its tag.
class IntroTrack3D extends StatelessWidget {
  const IntroTrack3D({super.key, required this.tone, required this.labels, required this.carAt, required this.carArt, required this.tag});

  final ListingTone tone;
  final List<String> labels;
  final double carAt;
  final String carArt;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final n = labels.length;
        double xOf(int i) => n == 1 ? w / 2 : 8 + (w - 16) * i / (n - 1);
        final carX = 8 + (w - 16) * carAt;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 8, right: 8, top: 30, height: 4, child: DecoratedBox(decoration: BoxDecoration(color: AuthInk.white(0.4), borderRadius: BorderRadius.circular(2)))),
            Positioned(left: 8, top: 30, width: (w - 16) * carAt, height: 4, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)))),
            for (var i = 0; i < n; i++) ...[
              Positioned(
                left: xOf(i) - 8,
                top: 24,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AuthInk.white(0.3), spreadRadius: 4)]),
                ),
              ),
              Positioned(
                left: i == 0 ? 0 : (i == n - 1 ? null : xOf(i) - 60),
                right: i == n - 1 ? 0 : null,
                width: i == 0 || i == n - 1 ? null : 120,
                top: 46,
                child: Text(labels[i], maxLines: 1, textAlign: i == 0 ? TextAlign.left : (i == n - 1 ? TextAlign.right : TextAlign.center), style: Ink3D.text(12, FontWeight.w700, Colors.white)),
              ),
            ],
            Positioned(left: carX - 20, top: -4, child: ExcludeSemantics(child: Art3D(asset: carArt, size: 40, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.3))),
            Positioned(
              left: carX + 24,
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text(tag, maxLines: 1, style: Ink3D.text(10.5, FontWeight.w700, tone.g2)),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Journey thread under the intro pages (`.thr`): track line with a gradient fill, six stops, the car on top.
class IntroThreadPainter extends CustomPainter {
  IntroThreadPainter({required this.tone, required this.page, required this.count, required this.current});

  final ListingTone tone;
  final double page;
  final int count;
  final int current;

  static double xOf(Size size, int count, double i) => 8 + (size.width - 16) * (i / (count - 1));

  @override
  void paint(Canvas canvas, Size size) {
    const y = 24.0;
    final line = RRect.fromLTRBR(0, y - 2, size.width, y + 2, const Radius.circular(2));
    canvas.drawRRect(line, Paint()..color = tone.haloBase.withValues(alpha: 0.2));
    final fx = xOf(size, count, page.clamp(0, count - 1).toDouble());
    canvas.drawRRect(
      RRect.fromLTRBR(0, y - 2, fx, y + 2, const Radius.circular(2)),
      Paint()..shader = LinearGradient(colors: [tone.g1, tone.g2]).createShader(Rect.fromLTWH(0, y - 2, math.max(fx, 1), 4)),
    );
    for (var k = 0; k < count; k++) {
      final c = Offset(xOf(size, count, k.toDouble()), y);
      final on = k <= current;
      canvas.drawCircle(c, 11, Paint()..color = tone.haloBase.withValues(alpha: on ? 0.35 : 0.3));
      canvas.drawCircle(c, 8, Paint()..color = on ? tone.g2 : Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant IntroThreadPainter old) =>
      old.page != page || old.current != current || old.count != count || old.tone.g2 != tone.g2 || old.tone.g1 != tone.g1;
}

/// Scrollable list that spreads its children evenly over the free height (`.rlist`); fades the bottom edge only while more content is below.
class AuthEvenList extends StatefulWidget {
  const AuthEvenList({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(18, 0, 18, 10)});

  final List<Widget> children;
  final EdgeInsets padding;

  static const double _fade = 22;

  @override
  State<AuthEvenList> createState() => _AuthEvenListState();
}

class _AuthEvenListState extends State<AuthEvenList> {
  bool _more = false;

  bool _onMetrics(ScrollMetricsNotification n) {
    final more = n.metrics.extentAfter > 12;
    if (more != _more) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _more != more) setState(() => _more = more);
      });
    }
    return false;
  }

  bool _onScroll(ScrollNotification n) {
    final more = n.metrics.extentAfter > 12;
    if (more != _more) setState(() => _more = more);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _more ? const [Colors.white, Colors.white, Colors.transparent] : const [Colors.white, Colors.white, Colors.white],
          stops: [0, r.height <= AuthEvenList._fade ? 0 : 1 - AuthEvenList._fade / r.height, 1],
        ).createShader(r),
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: _onMetrics,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: math.max(0, box.maxHeight - padding.vertical)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
