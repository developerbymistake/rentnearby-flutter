import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../b/widgets/social_widgets_b.dart';
import '../social_strings.dart';
import '../travel_levels.dart';

// Trophy on its level tint: rounded tile (lists) or round (badges). Travel King gets the gold ring.
class TrophyTile extends StatelessWidget {
  const TrophyTile({super.key, required this.level, this.size = LevelSizes.tile, this.round = false, this.art});

  final TravelLevel level;
  final double size;
  final bool round;
  final double? art;

  static const Key ringKey = ValueKey('trophy_king_ring');

  @override
  Widget build(BuildContext context) {
    final box = DS.s(size);
    final artSize = art ?? (round ? size * LevelSizes.roundArtRatio : size * LevelSizes.tileArtRatio);
    final ring = level.isKing;
    final tile = Container(
      key: ring ? ringKey : null,
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: level.tint,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : DS.circular(CardRadius.tileNotch),
        border: ring ? Border.all(color: LevelColors.kingRing, width: DS.s(LevelSizes.kingRing)) : null,
        boxShadow: ring ? [BoxShadow(color: LevelColors.kingRing.withValues(alpha: Alpha.v55), blurRadius: DS.shadowBlur(LevelSizes.kingGlowBlur), spreadRadius: DS.s(LevelSizes.kingGlowSpread))] : null,
      ),
    );
    final trophy = _TrophyArt(asset: level.asset, size: artSize);
    if (round) return Stack(alignment: Alignment.center, children: [tile, trophy]);
    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          tile,
          Positioned(left: (box - DS.s(artSize)) / 2, top: -DS.s(size * LevelSizes.tileArtLift), child: trophy),
        ],
      ),
    );
  }
}

// Small round trophy + 'N trips' beside a name (trip cards, trip post, join requests).
class TrophyBadge extends StatelessWidget {
  const TrophyBadge({super.key, required this.level, required this.trips, this.showCount = true});

  final int level;
  final int trips;
  final bool showCount;

  static const Key countKey = ValueKey('trophy_badge_count');

  @override
  Widget build(BuildContext context) {
    final l = TravelLevels.at(level);
    return Semantics(
      label: SocialStrings.levelLabel(l.name, trips),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TrophyTile(level: l, size: LevelSizes.badge, round: true),
          if (showCount) ...[
            Gap.h(4),
            Text(SocialStrings.tripsCount(trips), key: countKey, maxLines: 1, style: Ink3D.text(12, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
          ],
        ],
      ),
    );
  }
}

class LevelProgressBar extends StatelessWidget {
  const LevelProgressBar({super.key, required this.value, required this.gradient, this.height = LevelSizes.bar});

  final double value;
  final Gradient gradient;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: DS.circular(height / 2),
        child: Container(
          height: DS.s(height),
          color: LevelColors.track,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: DecoratedBox(decoration: BoxDecoration(gradient: gradient, borderRadius: DS.circular(height / 2))),
          ),
        ),
      );
}

// 'N more trips to <next>' line with the next trophy; the top level says so instead.
class NextLevelLine extends StatelessWidget {
  const NextLevelLine({super.key, required this.trips, required this.level, this.atTrips = false});

  final int trips;
  final int level;
  final bool atTrips;

  static const Key textKey = ValueKey('next_level_text');

  @override
  Widget build(BuildContext context) {
    final next = TravelLevels.next(level);
    final primary = ListingPalette.indigo.text;
    if (next == null) {
      return Text(SocialStrings.highestLevel, key: textKey, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w600, primary, letterSpacing: 0));
    }
    final left = TravelLevels.tripsToNext(trips, level);
    final more = Text.rich(
      TextSpan(children: [
        TextSpan(text: SocialStrings.moreTrips(left), style: Ink3D.text(12.5, FontWeight.w600, primary, letterSpacing: 0)),
        TextSpan(text: SocialStrings.toNext(atTrips ? next.name : null), style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub, letterSpacing: 0)),
      ]),
      key: textKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final tail = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TrophyArt(asset: next.asset, size: LevelSizes.nextArt),
        Gap.h(5),
        Text(atTrips ? SocialStrings.atTrips(next.min) : next.name, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w600, atTrips ? Ink3D.sub : Ink3D.title, letterSpacing: 0)),
      ],
    );
    return Row(children: [Expanded(child: more), Gap.h(8), tail]);
  }
}

// L1: white panel under the profile stats; the whole panel opens the Travel levels page.
class LevelPanelCard extends StatelessWidget {
  const LevelPanelCard({super.key, required this.trips, required this.level, this.onTap});

  final int trips;
  final int level;
  final VoidCallback? onTap;

  static const Key panelKey = ValueKey('profile_level_panel');

  @override
  Widget build(BuildContext context) {
    final l = TravelLevels.at(level);
    final palette = ListingPalette.indigo;
    final medal = Container(
      width: DS.s(LevelSizes.medal),
      height: DS.s(LevelSizes.medal),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(center: LevelSizes.medalLightCentre, colors: [LevelColors.medalLight, LevelColors.medalDeep]),
        border: Border.all(color: DesignColors.surface, width: DS.s(LevelSizes.medalBorder)),
        boxShadow: [BoxShadow(color: LevelColors.medalRing, spreadRadius: DS.s(LevelSizes.medalRing))],
      ),
      child: _TrophyArt(asset: l.asset, size: LevelSizes.medalArt),
    );
    final card = Container(
      key: panelKey,
      margin: EdgeInsets.only(top: DS.gv(14)),
      padding: DS.all(14),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: DS.br(CardRadius.card),
        boxShadow: [BoxShadow(color: ProfileStatColors.tileShadow.withValues(alpha: Alpha.v22), offset: DS.shadowOffset(LevelSizes.panelShadowOffset))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              medal,
              Gap.h(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(SocialStrings.levelEyebrow(l.index), maxLines: 1, style: Ink3D.text(12, FontWeight.w700, LevelColors.eyebrow, letterSpacing: 0.8)),
                    Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(18, FontWeight.w600, Ink3D.title, height: 1.25, letterSpacing: 0)),
                    Text(SocialStrings.tripsDone(trips), maxLines: 1, style: Ink3D.text(13, FontWeight.w400, Ink3D.sub, letterSpacing: 0)),
                  ],
                ),
              ),
              Container(
                width: DS.s(LevelSizes.arrow),
                height: DS.s(LevelSizes.arrow),
                decoration: BoxDecoration(color: palette.tint, shape: BoxShape.circle),
                child: Icon(Icons.chevron_right_rounded, size: DS.s(LevelSizes.arrowIcon), color: palette.text),
              ),
            ],
          ),
          Gap.v(14),
          LevelProgressBar(value: TravelLevels.progress(trips, l.index), gradient: LinearGradient(colors: [palette.g2, LevelColors.progressGold])),
          Gap.v(9),
          NextLevelLine(trips: trips, level: l.index),
        ],
      ),
    );
    return Tap3D(onTap: onTap, label: SocialStrings.openLevelsLabel(l.name, trips), exclude: true, child: card);
  }
}

// L3: trophy tile with the trip count under it, right of the name row on another traveller's profile.
class TravellerLevelMark extends StatelessWidget {
  const TravellerLevelMark({super.key, required this.trips, required this.level});

  final int trips;
  final int level;

  static const Key markKey = ValueKey('traveller_level_mark');

  @override
  Widget build(BuildContext context) {
    final l = TravelLevels.at(level);
    final white = DesignColors.onPrimary;
    return Semantics(
      key: markKey,
      label: SocialStrings.levelLabel(l.name, trips),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TrophyTile(level: l, size: LevelSizes.medal, round: true, art: LevelSizes.markArt),
          Gap.v(4),
          Text('$trips', maxLines: 1, style: Ink3D.text(18, FontWeight.w700, white, height: 1.2, letterSpacing: 0)),
          Text(SocialStrings.tripsWord(trips), maxLines: 1, style: Ink3D.text(12, FontWeight.w400, white, letterSpacing: 0)),
        ],
      ),
    );
  }
}

// L2 top card: big trophy on the level tint, name, trips, progress and the next level.
class LevelTopCard extends StatelessWidget {
  const LevelTopCard({super.key, required this.trips, required this.level});

  final int trips;
  final int level;

  static const Key cardKey = ValueKey('travel_levels_top');

  @override
  Widget build(BuildContext context) {
    final l = TravelLevels.at(level);
    return Container(
      key: cardKey,
      margin: DS.gapInsets(l: 18, t: 6, r: 18),
      padding: DS.insets(l: 20, t: 20, r: 20, b: 18),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.hero), boxShadow: DS.shadows(Form3D.cardShadow)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TrophyTile(level: l, size: LevelSizes.hero, round: true, art: LevelSizes.heroArt),
              Gap.h(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(SocialStrings.levelEyebrow(l.index), maxLines: 1, style: Ink3D.text(12, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8)),
                    Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, height: 1.25, letterSpacing: 0)),
                    Text(SocialStrings.tripsDone(trips), maxLines: 1, style: Ink3D.text(14, FontWeight.w400, Ink3D.sub, letterSpacing: 0)),
                  ],
                ),
              ),
            ],
          ),
          Gap.v(16),
          LevelProgressBar(value: TravelLevels.progress(trips, l.index), gradient: ListingPalette.indigo.gradient),
          Gap.v(8),
          NextLevelLine(trips: trips, level: l.index, atTrips: true),
        ],
      ),
    );
  }
}

enum LevelRowState { done, current, future }

class LevelRow extends StatelessWidget {
  const LevelRow({super.key, required this.level, required this.state, this.first = false});

  final TravelLevel level;
  final LevelRowState state;
  final bool first;

  static Key keyOf(int index) => ValueKey('travel_level_row_$index');
  static const Key hereKey = ValueKey('travel_level_here');
  static Key tickKey(int index) => ValueKey('travel_level_tick_$index');

  @override
  Widget build(BuildContext context) {
    final palette = ListingPalette.indigo;
    final current = state == LevelRowState.current;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(level.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, current ? FontWeight.w600 : FontWeight.w500, current ? palette.text : Ink3D.title, letterSpacing: 0)),
        Text(level.range, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
      ],
    );
    final Widget? end = switch (state) {
      LevelRowState.done => Container(
          key: tickKey(level.index),
          width: DS.s(LevelSizes.badge),
          height: DS.s(LevelSizes.badge),
          decoration: BoxDecoration(gradient: BuddyLook.teal.gradient, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, size: DS.s(LevelSizes.tickIcon), color: DesignColors.onPrimary),
        ),
      LevelRowState.current => Container(
          key: hereKey,
          padding: DS.sym(h: 10, v: 4),
          decoration: BoxDecoration(gradient: palette.gradient, borderRadius: DS.br(CardRadius.card), boxShadow: ListingTone.indigo.glow(blur: 0, dy: 2)),
          child: Text(SocialStrings.youAreHere, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
        ),
      LevelRowState.future => null,
    };
    return Semantics(
      key: keyOf(level.index),
      label: SocialStrings.levelRowLabel(level.name, level.range, current: current),
      selected: current,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(LevelSizes.rowMinHeight)),
        padding: DS.insets(l: 18, t: 12, r: 16, b: 12),
        decoration: BoxDecoration(
          color: current ? palette.tint : null,
          border: Border(
            top: first ? BorderSide.none : BorderSide(color: Ink3D.line, width: DS.s(LevelSizes.rowLine)),
            left: current ? BorderSide(color: palette.g2, width: DS.s(LevelSizes.rowAccent)) : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            TrophyTile(level: level),
            Gap.h(14),
            Expanded(child: state == LevelRowState.future ? Opacity(opacity: Alpha.half, child: text) : text),
            if (end != null) ...[Gap.h(8), end],
          ],
        ),
      ),
    );
  }
}

// L5: shown once after the level went up.
class LevelUpSheet extends StatelessWidget {
  const LevelUpSheet({super.key, required this.level, required this.trips});

  final int level;
  final int trips;

  static const Key buttonKey = ValueKey('level_up_keep_exploring');
  static const Key titleKey = ValueKey('level_up_title');

  static Future<void> show(BuildContext context, {required int level, required int trips}) =>
      Sheet3D.show<void>(context, builder: (_) => LevelUpSheet(level: level, trips: trips));

  @override
  Widget build(BuildContext context) {
    final l = TravelLevels.at(level);
    final base = ListingTone.indigo;
    final tone = ListingTone(g1: base.g1, g2: base.g2, shadow: base.shadow, haloBase: l.ink, text: base.text);
    final next = TravelLevels.next(l.index);
    return Sheet3D(
      tone: tone,
      art: l.asset,
      showClose: false,
      footer: GradientPillButton(key: buttonKey, tone: base, label: SocialStrings.keepExploring, onTap: () => Navigator.of(context).maybePop()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(SocialStrings.levelEyebrow(l.index), textAlign: TextAlign.center, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8)),
          Gap.v(4),
          Semantics(
            header: true,
            child: Text(SocialStrings.newLevel(l.name), key: titleKey, textAlign: TextAlign.center, maxLines: 2, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, height: 1.25, letterSpacing: 0)),
          ),
          Gap.v(6),
          Text(SocialStrings.levelUpLine(trips), textAlign: TextAlign.center, maxLines: 2, style: Ink3D.text(14, FontWeight.w400, Ink3D.copy, height: 1.45)),
          Gap.v(18),
          LevelProgressBar(value: TravelLevels.progress(trips, l.index), gradient: base.gradient, height: LevelSizes.sheetBar),
          Gap.v(6),
          Text(next == null ? SocialStrings.highestLevel : SocialStrings.moreTripsTo(TravelLevels.tripsToNext(trips, l.index), next.name),
              textAlign: TextAlign.center, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
        ],
      ),
    );
  }
}

// 'ALL LEVELS' list card for the Travel levels page.
class LevelListCard extends StatelessWidget {
  const LevelListCard({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SmallLabel(text: SocialStrings.allLevels, caps: true, padding: DS.gapInsets(l: 22, t: 22, r: 22, b: 10)),
          Container(
            margin: DS.gapInsets(l: 18, r: 18),
            decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.tile), boxShadow: DS.shadows(Form3D.cardShadow)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final l in TravelLevels.all)
                  LevelRow(
                    level: l,
                    first: l.index == 0,
                    state: l.index < level ? LevelRowState.done : (l.index == level ? LevelRowState.current : LevelRowState.future),
                  ),
              ],
            ),
          ),
        ],
      );
}

class _TrophyArt extends StatelessWidget {
  const _TrophyArt({required this.asset, required this.size});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Art3D(asset: asset, size: size, shadowBlur: LevelSizes.artShadowBlur, shadowOffset: LevelSizes.artShadowOffset, shadowAlpha: Alpha.v24),
      );
}
