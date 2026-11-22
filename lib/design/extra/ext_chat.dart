import 'package:flutter/material.dart';

import '../../widgets/profile_avatar.dart';
import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'pill_buttons_3d.dart';
import '../tokens/design_scale.dart';

abstract final class ChatLook3D {
  static const Color bannerFill = Color(0xFFFFF1DE);
  static const Color bannerText = Color(0xFF6A4A1A);
  static const Color red = Color(0xFFE0525C);
  static const Color redBorder = Color(0x59E0525C);
  static const Color outline = Color(0xFFE6E8EE);
  static const Color divider = Color(0xFFEEF0F4);
  static const Color strip = Color(0x1F000000);
  static const Color avatarHalo = Color(0x3DFAFAFA);
  static const Color headerButton = Color(0x38FFFFFF);
  static const Color headerHalo = Color(0x2EFFFFFF);
  static const Color avatarFill = Color(0x40FFFFFF);
  static const Color avatarRing = Color(0xB3FFFFFF);
  static const Color skeleton = Color(0xFFE2E9E3);
  static const Color askedPill = Color(0xFF9A5B00);
  static const Color skeletonBone = Color(0xFFD3DCD5);
  static const Color skeletonRing = Color(0xFFEEF2EF);
  static const Color skeletonStrip = Color(0x0A000000);
  static List<BoxShadow> get grey => [BoxShadow(color: Color(0x599E9E9E), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(10))];
  static List<BoxShadow> get card => [BoxShadow(color: Color(0x409E9E9E), offset: DS.shadowOffset(const Offset(1.1, 1.1)), blurRadius: DS.shadowBlur(10))];
  static List<BoxShadow> get panel => [BoxShadow(color: Color(0x26000000), offset: DS.shadowOffset(const Offset(0, -4)), blurRadius: DS.shadowBlur(20))];
  static List<BoxShadow> get badge => [BoxShadow(color: Color(0x38000000), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(8))];
  static List<BoxShadow> get avatar => [BoxShadow(color: Color(0x4D000000), offset: DS.shadowOffset(const Offset(4, 8)), blurRadius: DS.shadowBlur(12))];
  static const LinearGradient avatarGradient = LinearGradient(
    colors: [Color(0xFF81C784), Color(0xFF1B5E20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ListingTone toneFor(String listingType) => switch (listingType) {
    'Taxi' => ListingTone.coral,
    'Stay' => ListingTone.forest,
    _ => ListingTone.forest,
  };

  static String artFor(String listingType) => switch (listingType) {
    'Stay' => ListingArt.stay,
    'Taxi' => ListingArt.taxi,
    _ => ListingArt.compass,
  };

  static String initialOf(String name) => name.isNotEmpty ? name[0].toUpperCase() : '?';

  static List<BoxShadow> glow(ListingTone tone, {double alpha = 0.5, double blur = 10, Offset offset = const Offset(1.1, 4)}) => [
    BoxShadow(
      color: tone.haloBase.withValues(alpha: alpha),
      offset: DS.shadowOffset(offset),
      blurRadius: DS.shadowBlur(blur),
    ),
  ];
}

BorderRadius get _kRow => BorderRadius.only(
  topLeft: Radius.circular(DS.radius(8)),
  topRight: Radius.circular(DS.radius(54)),
  bottomLeft: Radius.circular(DS.radius(8)),
  bottomRight: Radius.circular(DS.radius(8)),
);
BorderRadius get _kChip => BorderRadius.only(
  topLeft: Radius.circular(DS.radius(8)),
  topRight: Radius.circular(DS.radius(24)),
  bottomLeft: Radius.circular(DS.radius(8)),
  bottomRight: Radius.circular(DS.radius(8)),
);

double _scale(BuildContext context) => MediaQuery.textScalerOf(context).scale(1);

typedef ChatMenuTap = void Function(Rect anchor);

Rect chatRectOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}

class ChatRoundButton3D extends StatelessWidget {
  const ChatRoundButton3D({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.tone,
    this.gradient = false,
    this.glass = false,
    this.size = 44,
    this.tapKey,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final ListingTone? tone;
  final bool gradient;
  final bool glass;
  final double size;
  final Key? tapKey;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.forest;
    final ink = gradient || glass ? Colors.white : t.text;
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Tap3D(
        onTap: onTap,
        label: tooltip,
        exclude: true,
        tapKey: tapKey,
        child: Container(
          width: DS.s(size),
          height: DS.s(size),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: glass ? ChatLook3D.headerButton : (gradient ? null : Colors.white),
            gradient: gradient ? t.gradient : null,
            boxShadow: glass ? null : (gradient ? ChatLook3D.glow(t, offset: const Offset(3, 6)) : DS.shadows(Ink3D.softShadow)),
          ),
          child: Icon(icon, size: DS.s(size * 0.55), color: ink),
        ),
      ),
    );
  }
}

class ChatThreadCard extends StatelessWidget {
  const ChatThreadCard({
    super.key,
    required this.tone,
    required this.initial,
    required this.sticker,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.preview,
    this.unread = '',
    this.dimmed = false,
    this.onTap,
    this.photoUrl,
  }) : skeleton = false;

  const ChatThreadCard.skeleton({super.key})
    : tone = null,
      initial = '',
      sticker = '',
      tag = '',
      title = '',
      subtitle = '',
      time = '',
      preview = '',
      unread = '',
      dimmed = false,
      onTap = null,
      photoUrl = null,
      skeleton = true;

  final ListingTone? tone;
  final String initial;
  final String sticker;
  final String tag;
  final String title;
  final String subtitle;
  final String time;
  final String preview;
  final String unread;
  final bool dimmed;
  final VoidCallback? onTap;
  final String? photoUrl;
  final bool skeleton;

  static const double topRoom = 44;

  Widget _bone(double w, double h) => Container(
    width: DS.s(w),
    height: DS.s(h),
    decoration: BoxDecoration(color: ChatLook3D.skeletonBone, borderRadius: DS.circular(h / 2)),
  );

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final av = DS.s(narrow ? 72.0 : 88.0);
    final left = DS.s(narrow ? 102.0 : 124.0);
    final right = DS.s(narrow ? 70.0 : 72.0);
    final tagRight = DS.s(narrow ? 52.0 : 56.0);
    final t = tone ?? ListingTone.forest;
    final hasBadge = unread.isNotEmpty;
    final head = ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(94) * _scale(context).clamp(1.0, 1.6)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(left, DS.s(14), 0, DS.s(12)),
        child: skeleton
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_bone(42, 12), Gap.v(10), _bone(118, 16), Gap.v(10), _bone(150, 11)],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: tagRight),
                    child: Text(
                      tag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(10, FontWeight.w700, Colors.white.withValues(alpha: 0.92), letterSpacing: 0.4),
                    ),
                  ),
                  Gap.v(4),
                  Padding(
                    padding: EdgeInsets.only(right: right),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(title, maxLines: 1, softWrap: false, style: Ink3D.text(narrow ? 16 : 18, FontWeight.w700, Colors.white)),
                    ),
                  ),
                  Gap.v(4),
                  Padding(
                    padding: EdgeInsets.only(right: DS.s(14)),
                    child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white.withValues(alpha: 0.95))),
                  ),
                ],
              ),
      ),
    );
    final strip = Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: DS.s(42) * _scale(context).clamp(1.0, 1.6)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(20), vertical: DS.s(10)),
      alignment: Alignment.centerLeft,
      color: skeleton ? ChatLook3D.skeletonStrip : ChatLook3D.strip,
      child: skeleton
          ? _bone(210, 11)
          : Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, hasBadge ? FontWeight.w700 : FontWeight.w400, Colors.white)),
    );
    final side = Positioned(
      right: DS.s(16),
      top: DS.s(14),
      child: SizedBox(
        width: DS.s(46),
        child: Column(
          children: [
            skeleton ? _bone(28, 11) : Text(time, maxLines: 1, style: Ink3D.text(12, FontWeight.w600, Colors.white, height: 1.2)),
            Gap.v(6),
            if (hasBadge)
              Container(
                constraints: BoxConstraints(minWidth: DS.s(28), minHeight: DS.s(28)),
                padding: EdgeInsets.symmetric(horizontal: DS.s(7)),
                decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(14), boxShadow: ChatLook3D.badge),
                child: Center(widthFactor: 1, heightFactor: 1, child: Text(unread, maxLines: 1, style: Ink3D.text(13, FontWeight.w700, t.g2, letterSpacing: 0))),
              )
            else
              Gap.v(28),
          ],
        ),
      ),
    );
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _kRow,
        color: skeleton ? ChatLook3D.skeleton : null,
        gradient: skeleton ? null : t.gradient,
        boxShadow: skeleton || dimmed ? null : ChatLook3D.glow(t, alpha: 0.55),
      ),
      child: ClipRRect(
        borderRadius: _kRow,
        child: Stack(
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, strip]),
            side,
          ],
        ),
      ),
    );
    final halo = av + DS.s(16);
    final body = Padding(
      padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(topRoom), DS.s(14), 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            left: DS.s(6),
            top: DS.s(-30),
            child: ExcludeSemantics(
              child: Container(
                width: halo,
                height: halo,
                decoration: BoxDecoration(shape: BoxShape.circle, color: skeleton ? Colors.white.withValues(alpha: 0.5) : ChatLook3D.avatarHalo),
              ),
            ),
          ),
          Positioned(
            left: DS.s(14),
            top: DS.s(-22),
            child: ExcludeSemantics(
              child: Container(
                width: av,
                height: av,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: skeleton ? ChatLook3D.skeletonBone : null,
                  gradient: skeleton ? null : ChatLook3D.avatarGradient,
                  border: Border.all(color: skeleton ? ChatLook3D.skeletonRing : Colors.white, width: DS.s(4)),
                  boxShadow: skeleton ? null : ChatLook3D.avatar,
                ),
                child: skeleton
                    ? null
                    : ProfileAvatar(
                        photoUrl: photoUrl,
                        size: av - 2 * DS.s(4),
                        fallback: Text(initial, textScaler: TextScaler.noScaling, style: Ink3D.text(narrow ? 31 : 38, FontWeight.w700, Colors.white, letterSpacing: 0)),
                      ),
              ),
            ),
          ),
          if (!skeleton)
            Positioned(
              left: av * 0.6 + DS.s(13),
              top: av * 0.43,
              child: ExcludeSemantics(
                child: Art3D(asset: sticker, size: narrow ? 44 : 52, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.3),
              ),
            ),
        ],
      ),
    );
    if (skeleton) return body;
    return Semantics(
      button: onTap != null,
      label: [tag, title, subtitle, time, if (hasBadge) '$unread unread', preview].join(', '),
      excludeSemantics: true,
      child: Tap3D(
        onTap: onTap,
        child: Opacity(opacity: dimmed ? 0.6 : 1, child: body),
      ),
    );
  }
}

class ChatStateCard3D extends StatelessWidget {
  const ChatStateCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.message,
    this.margin,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String? message;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final size = narrow ? 120.0 : 146.0;
    return Padding(
      padding: (margin ?? EdgeInsets.fromLTRB(DS.s(18), DS.s(110), DS.s(18), 0)),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(DS.s(24), DS.s(size) - DS.s(50), DS.s(24), DS.s(30)),
            decoration: BoxDecoration(color: Colors.white, borderRadius: _kRow, boxShadow: ChatLook3D.glow(tone, alpha: 0.28, blur: 14)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(21, FontWeight.w700, Ink3D.title, height: 1.3)),
                ),
                if (message != null)
                  Padding(
                    padding: EdgeInsets.only(top: DS.s(6)),
                    child: Text(message!, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w400, Ink3D.copy, height: 1.45)),
                  ),
              ],
            ),
          ),
          Positioned(
            top: DS.s(-size / 2),
            child: ExcludeSemantics(
              child: Art3D(asset: art, size: size, halo: size + 10, haloColor: tone.haloBase.withValues(alpha: 0.16)),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatHeader3D extends StatelessWidget {
  const ChatHeader3D({
    super.key,
    required this.tone,
    required this.initial,
    required this.name,
    required this.subtitle,
    required this.sticker,
    required this.art,
    required this.onBack,
    required this.onMore,
    this.moreKey,
    this.photoUrl,
  });

  final ListingTone tone;
  final String initial;
  final String? photoUrl;
  final String name;
  final String subtitle;
  final String sticker;
  final String art;
  final VoidCallback? onBack;
  final ChatMenuTap? onMore;
  final Key? moreKey;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artSize = narrow ? 66.0 : 82.0;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: DS.s(158) + top),
      padding: EdgeInsets.fromLTRB(DS.s(16), top + DS.s(12), DS.s(16), DS.s(20)),
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(DS.radius(32))),
        boxShadow: [BoxShadow(color: tone.haloBase.withValues(alpha: 0.35), offset: DS.shadowOffset(const Offset(0, 8)), blurRadius: DS.shadowBlur(20))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: DS.s(-4),
            bottom: DS.s(-14),
            child: ExcludeSemantics(
              child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: ChatLook3D.headerHalo, shadowOffset: const Offset(5, 8), shadowAlpha: 0.3),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ChatRoundButton3D(icon: Icons.chevron_left_rounded, onTap: onBack, tooltip: 'Back', glass: true, size: 42),
                  const Spacer(),
                  Builder(
                    builder: (c) => ChatRoundButton3D(
                      icon: Icons.more_vert_rounded,
                      onTap: onMore == null ? null : () => onMore!(chatRectOf(c)),
                      tooltip: 'More',
                      glass: true,
                      size: 42,
                      tapKey: moreKey,
                    ),
                  ),
                ],
              ),
              Gap.v(12),
              Padding(
                padding: EdgeInsets.only(right: DS.s(artSize) + DS.s(2)),
                child: Row(
                  children: [
                    Container(
                      width: DS.s(54),
                      height: DS.s(54),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ChatLook3D.avatarFill,
                        border: Border.all(color: ChatLook3D.avatarRing, width: DS.s(3)),
                      ),
                      child: ProfileAvatar(
                        photoUrl: photoUrl,
                        size: DS.s(54) - 2 * DS.s(3),
                        fallback: Text(initial, textScaler: TextScaler.noScaling, style: Ink3D.text(23, FontWeight.w700, Colors.white, letterSpacing: 0)),
                      ),
                    ),
                    Gap.h(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            header: true,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                name,
                                maxLines: 1,
                                softWrap: false,
                                style: Ink3D.text(21, FontWeight.w700, Colors.white, letterSpacing: 0.4),
                              ),
                            ),
                          ),
                          Gap.v(2),
                          Row(
                            children: [
                              ExcludeSemantics(child: Image.asset(sticker, width: DS.s(18), height: DS.s(18), fit: BoxFit.contain)),
                              Gap.h(5),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Ink3D.text(12, FontWeight.w400, Colors.white.withValues(alpha: 0.95), letterSpacing: 0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatStripCard3D extends StatelessWidget {
  const ChatStripCard3D({
    super.key,
    required this.barColor,
    required this.title,
    required this.detail,
    required this.pill,
    required this.onTap,
    this.extra,
    this.onMenu,
    this.menuKey,
    this.margin,
  });

  final Color barColor;
  final String title;
  final String detail;
  final Widget pill;
  final Widget? extra;
  final VoidCallback onTap;
  final ChatMenuTap? onMenu;
  final Key? menuKey;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: _kChip, boxShadow: ChatLook3D.card),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: DS.s(5), color: barColor),
            Expanded(
              child: Tap3D(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: DS.s(72)),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(DS.s(8), DS.s(10), 0, DS.s(10)),
                    child: Row(
                      children: [
                        const ExcludeSemantics(
                          child: Art3D(asset: ListingArt.luggage, size: 42, shadowBlur: 3, shadowOffset: Offset(2, 4), shadowAlpha: 0.25),
                        ),
                        Gap.h(8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                              if (detail.isNotEmpty)
                                Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.sub)),
                              Padding(padding: EdgeInsets.only(top: DS.s(3)), child: pill),
                              ?extra,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: DS.s(30),
              child: onMenu == null
                  ? null
                  : Tooltip(
                      message: 'More',
                      excludeFromSemantics: true,
                      child: Builder(
                        builder: (c) => Tap3D(
                          onTap: () => onMenu!(chatRectOf(c)),
                          label: 'More',
                          exclude: true,
                          tapKey: menuKey,
                          child: Center(child: Icon(Icons.more_vert_rounded, size: DS.s(22), color: Ink3D.grey)),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
    return Padding(padding: (margin ?? EdgeInsets.fromLTRB(DS.s(18), DS.s(16), DS.s(18), 0)), child: body);
  }
}

class ChatSafetyNote3D extends StatelessWidget {
  const ChatSafetyNote3D({super.key, required this.text, this.margin});

  final String text;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: (margin ?? EdgeInsets.fromLTRB(DS.s(18), DS.gv(14), DS.s(18), 0)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(14), vertical: DS.s(10)),
      decoration: BoxDecoration(color: ChatLook3D.bannerFill, borderRadius: _kChip, boxShadow: ChatLook3D.card),
      child: Row(
        children: [
          ExcludeSemantics(child: Image.asset(ListingArt.clipboard, width: DS.s(38), height: DS.s(38), fit: BoxFit.contain)),
          Gap.h(10),
          Expanded(child: Text(text, style: Ink3D.text(12.5, FontWeight.w400, ChatLook3D.bannerText, letterSpacing: 0, height: 1.4))),
        ],
      ),
    );
  }
}

class ChatNoticePanel3D extends StatelessWidget {
  const ChatNoticePanel3D({super.key, required this.tone, required this.text, this.actionLabel, this.onAction});

  final ListingTone tone;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const double overhang = 40;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(DS.s(26), DS.s(46), DS.s(26), DS.s(22) + bottom),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(32))),
            boxShadow: ChatLook3D.panel,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w500, Ink3D.sub, height: 1.45)),
              ),
              if (actionLabel != null)
                Padding(
                  padding: EdgeInsets.only(top: DS.gv(12)),
                  child: SizedBox(
                    width: DS.s(170),
                    child: GradientPillButton(tone: tone, label: actionLabel!, onTap: onAction, height: 44, fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: DS.s(-overhang),
          child: ExcludeSemantics(
            child: Art3D(
              asset: ListingArt.pushpin,
              size: 72,
              halo: 76,
              haloColor: tone.haloBase.withValues(alpha: 0.18),
              shadowBlur: 5,
              shadowOffset: const Offset(3, 6),
              shadowAlpha: 0.28,
            ),
          ),
        ),
      ],
    );
  }
}

enum ChatBarKind { primary, negative, plain }

class ChatBarButton3D extends StatelessWidget {
  const ChatBarButton3D({super.key, required this.tone, required this.label, required this.onTap, this.kind = ChatBarKind.plain, this.busy = false, this.icon});

  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;
  final ChatBarKind kind;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final filled = kind == ChatBarKind.primary;
    final live = onTap != null && !busy;
    final ink = filled ? Colors.white : (kind == ChatBarKind.negative ? ChatLook3D.red : tone.text);
    final box = Container(
      constraints: BoxConstraints(minHeight: DS.s(44) * _scale(context).clamp(1.0, 1.3)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(12), vertical: DS.s(4)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? null : Colors.white,
        gradient: filled ? tone.gradient : null,
        borderRadius: DS.circular(24),
        border: filled ? null : Border.all(color: kind == ChatBarKind.negative ? ChatLook3D.redBorder : ChatLook3D.outline, width: 1.5),
        boxShadow: onTap == null && !busy ? null : (filled ? ChatLook3D.glow(tone) : ChatLook3D.grey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            SizedBox(width: DS.s(16), height: DS.s(16), child: CircularProgressIndicator(strokeWidth: DS.s(2.4), color: ink)),
            Gap.h(8),
          ] else if (icon != null) ...[
            Icon(icon, size: DS.s(18), color: ink),
            Gap.h(6),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(14, FontWeight.w700, ink)),
            ),
          ),
        ],
      ),
    );
    return Tap3D(
      onTap: live ? onTap : null,
      label: label,
      exclude: true,
      child: Opacity(opacity: onTap == null && !busy ? 0.45 : 1, child: box),
    );
  }
}

class ChatActionBar3D extends StatelessWidget {
  const ChatActionBar3D({super.key, required this.rows, this.note, this.margin});

  final List<List<Widget>> rows;
  final String? note;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340 || _scale(context) > 1.25;
    final out = <Widget>[];
    for (final r in rows) {
      if (out.isNotEmpty) out.add(Gap.v(10));
      final cells = r.where((w) => w is! ChatBarMenu3D).toList();
      final menus = r.whereType<ChatBarMenu3D>();
      final menu = menus.isEmpty ? null : menus.first;
      if (narrow && cells.length > 1) {
        for (var i = 0; i < cells.length; i++) {
          if (i > 0) out.add(Gap.v(10));
          out.add(
            i == cells.length - 1 && menu != null
                ? Row(
                    children: [
                      Expanded(child: cells[i]),
                      Gap.h(10),
                      menu,
                    ],
                  )
                : cells[i],
          );
        }
        continue;
      }
      out.add(
        Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[if (i > 0) Gap.h(10), Expanded(child: cells[i])],
            if (menu != null) ...[Gap.h(10), menu],
          ],
        ),
      );
    }
    return Container(
      margin: (margin ?? EdgeInsets.only(top: DS.gv(14), bottom: DS.gv(4))),
      padding: DS.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: _kChip, boxShadow: ChatLook3D.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note != null)
            Padding(
              padding: EdgeInsets.fromLTRB(DS.s(4), 0, DS.s(4), DS.s(10)),
              child: Text(note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, Ink3D.title)),
            ),
          ...out,
        ],
      ),
    );
  }
}

class ChatBarMenu3D extends StatelessWidget {
  const ChatBarMenu3D({super.key, required this.onTap});

  final ChatMenuTap? onTap;

  @override
  Widget build(BuildContext context) {
    final s = DS.s(44) * _scale(context).clamp(1.0, 1.3);
    return Tooltip(
      message: 'More',
      excludeFromSemantics: true,
      child: Builder(
        builder: (c) => Tap3D(
          onTap: onTap == null ? null : () => onTap!(chatRectOf(c)),
          label: 'More',
          exclude: true,
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: ChatLook3D.outline, width: 1.5),
              boxShadow: ChatLook3D.grey,
            ),
            child: Icon(Icons.more_vert_rounded, size: DS.s(22), color: Ink3D.grey),
          ),
        ),
      ),
    );
  }
}

class ChatSheetLabel3D extends StatelessWidget {
  const ChatSheetLabel3D(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(DS.s(8), DS.s(12), DS.s(8), DS.s(2)),
    child: Text(text.toUpperCase(), style: Ink3D.text(11, FontWeight.w700, Ink3D.grey, letterSpacing: 0.5)),
  );
}

class ChatSheetDivider3D extends StatelessWidget {
  const ChatSheetDivider3D({super.key});

  @override
  Widget build(BuildContext context) => Container(height: 1, margin: EdgeInsets.symmetric(vertical: DS.gv(6)), color: ChatLook3D.divider);
}

class ChatSheetRow3D extends StatelessWidget {
  const ChatSheetRow3D({super.key, required this.tone, required this.art, required this.label, required this.onTap});

  final ListingTone tone;
  final String art;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(60)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: DS.s(8), vertical: DS.s(6)),
          child: Row(
            children: [
              SizedBox(
                width: DS.s(46),
                height: DS.s(46),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: tone.haloBase.withValues(alpha: 0.14)),
                    ),
                    Positioned(
                      left: DS.s(-2),
                      top: DS.s(-6),
                      child: Art3D(asset: art, size: 50, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.25),
                    ),
                  ],
                ),
              ),
              Gap.h(14),
              Expanded(child: Text(label, style: Ink3D.text(15, FontWeight.w500, Ink3D.body, height: 1.3))),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatDayPill3D extends StatelessWidget {
  const ChatDayPill3D({super.key, required this.tone, required this.top, required this.day, required this.selected, required this.onTap});

  final ListingTone tone;
  final String top;
  final String day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? Colors.white : Ink3D.title;
    return Tap3D(
      onTap: onTap,
      label: '$top $day',
      selected: selected,
      exclude: true,
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(64) * _scale(context).clamp(1.0, 1.4)),
        padding: EdgeInsets.symmetric(vertical: DS.s(6)),
        decoration: BoxDecoration(
          color: selected ? null : Colors.white,
          gradient: selected ? tone.gradient : null,
          borderRadius: DS.circular(16),
          border: Border.all(color: selected ? Colors.transparent : ChatLook3D.outline, width: 1.5),
          boxShadow: selected ? ChatLook3D.glow(tone) : [BoxShadow(color: Color(0x409E9E9E), offset: DS.shadowOffset(const Offset(2, 4)), blurRadius: DS.shadowBlur(8))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(top, maxLines: 1, style: Ink3D.text(10.5, FontWeight.w500, selected ? Colors.white : tone.text, letterSpacing: 0)),
            ),
            Gap.v(2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(day, maxLines: 1, style: Ink3D.text(16, FontWeight.w700, ink, letterSpacing: 0)),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatSlotPill3D extends StatelessWidget {
  const ChatSlotPill3D({super.key, required this.tone, required this.label, required this.selected, required this.onTap, this.off = false});

  final ListingTone tone;
  final String label;
  final bool selected;
  final bool off;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      constraints: BoxConstraints(minHeight: DS.s(44) * _scale(context).clamp(1.0, 1.4)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(8), vertical: DS.s(4)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? null : Colors.white,
        gradient: selected ? tone.gradient : null,
        borderRadius: DS.circular(22),
        border: Border.all(color: selected ? Colors.transparent : ChatLook3D.outline, width: 1.5),
        boxShadow: selected && !off ? ChatLook3D.glow(tone, alpha: 0.45, blur: 8) : null,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1, style: Ink3D.text(14, FontWeight.w600, selected ? Colors.white : Ink3D.body, letterSpacing: 0)),
      ),
    );
    return Tap3D(
      onTap: off ? null : onTap,
      label: label,
      selected: selected,
      exclude: true,
      child: Opacity(opacity: off ? 0.4 : 1, child: pill),
    );
  }
}

class ChatSkeletonBubble3D extends StatelessWidget {
  const ChatSkeletonBubble3D({super.key, required this.width, required this.mine});

  final double width;
  final bool mine;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: DS.gv(5)),
    child: Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: DS.s(width),
        height: DS.s(40),
        decoration: BoxDecoration(
          borderRadius: DS.circular(16),
          gradient: const LinearGradient(colors: [Color(0xFFCFD8D1), Color(0xFFEEF2EF), Color(0xFFCFD8D1)]),
        ),
      ),
    ),
  );
}

class ChatThreadFade extends StatelessWidget {
  const ChatThreadFade({super.key, required this.child, this.edge = 16, this.bottom = false});

  final Widget child;
  final double edge;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final stop = c.maxHeight.isFinite && c.maxHeight > 0 ? (DS.s(edge) / c.maxHeight).clamp(0.0, 0.5) : 0.0;
        const clear = Color(0x00000000);
        const solid = Color(0xFF000000);
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bottom ? const [solid, solid, clear] : const [clear, solid],
            stops: bottom ? [0, 1 - stop, 1] : [0, stop],
          ).createShader(r),
          child: child,
        );
      },
    );
  }
}
