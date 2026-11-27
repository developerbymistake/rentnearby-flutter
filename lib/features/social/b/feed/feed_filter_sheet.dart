import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../buddy/shared/widgets/segment_tabs.dart';
import '../../c/social_strings_c.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../../shared/social_nav.dart';
import '../social_strings_b.dart';
import '../widgets/social_widgets_b.dart';

class FeedFilter {
  const FeedFilter({this.q = '', this.who = any, this.near = false, this.travel = any});

  static const String any = 'any';
  static const String women = 'women';
  static const String men = 'men';
  // Same order as the wizard control (Anyone | Men | Women, spec 23.8).
  static const List<String> whoValues = [any, men, women];
  static const List<String> travelValues = [any, ...TravelModes.codes];
  static const FeedFilter none = FeedFilter();

  final String q;
  final String who;
  final bool near;
  final String travel;

  int get count => (q.trim().isEmpty ? 0 : 1) + (who == any ? 0 : 1) + (near ? 1 : 0) + (travel == any ? 0 : 1);

  FeedFilter copyWith({String? q, String? who, bool? near, String? travel}) =>
      FeedFilter(q: q ?? this.q, who: who ?? this.who, near: near ?? this.near, travel: travel ?? this.travel);

  @override
  bool operator ==(Object other) => other is FeedFilter && other.q == q && other.who == who && other.near == near && other.travel == travel;

  @override
  int get hashCode => Object.hash(q, who, near, travel);
}

class FeedFilterSheet extends StatefulWidget {
  const FeedFilterSheet({super.key, required this.initial, required this.nearMe});

  final FeedFilter initial;
  final bool nearMe;

  static const Key showKey = ValueKey('feed_filter_show');
  static const Key nearSwitchKey = ValueKey('feed_filter_near');
  static const Key nearPlusKey = ValueKey('feed_filter_near_plus');
  static const Key whoKey = ValueKey('feed_filter_who');
  static const Key travelKey = ValueKey('feed_filter_travel');

  static Future<FeedFilter?> show(BuildContext context, {required FeedFilter initial, required bool nearMe}) =>
      Sheet3D.show<FeedFilter>(context, builder: (_) => FeedFilterSheet(initial: initial, nearMe: nearMe));

  static const List<String> whoLabels = SocialStringsB.joinLabels;
  static const List<String> travelLabels = [SocialStringsB.travelAny, ...SocialStringsB.travelLabels];

  @override
  State<FeedFilterSheet> createState() => _FeedFilterSheetState();
}

class _FeedFilterSheetState extends State<FeedFilterSheet> {
  late FeedFilter _f = widget.initial;
  late final TextEditingController _q = TextEditingController(text: widget.initial.q);

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _setQ(String v) {
    setState(() => _f = _f.copyWith(q: v));
    if (_q.text != v) _q.text = v;
  }

  Widget _card({required List<Widget> children}) => Container(
        margin: DS.gapInsets(t: 12),
        padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.card), boxShadow: DS.shadows(Form3D.cardShadow)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _head(String caps, String value) => Row(
        children: [
          Text(caps, style: Ink3D.text(12.5, FontWeight.w700, Ink3D.grey, letterSpacing: 1)),
          Gap.h(12),
          Expanded(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end, style: Ink3D.text(12.5, FontWeight.w700, BuddyLook.indigoText, letterSpacing: 0)),
          ),
        ],
      );

  Widget _plusPill() {
    final me = SocialMeController.maybe;
    final canUpgrade = me == null || me.limits.canUpgrade;
    final pill = Container(
      padding: DS.sym(h: 11, v: 5),
      decoration: BoxDecoration(color: BuddyLook.roseStart.withValues(alpha: Alpha.v14), borderRadius: DS.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: DS.s(16), color: BuddyLook.roseEnd),
          Gap.h(5),
          Text(SocialStringsB.plusPill, maxLines: 1, style: Ink3D.text(12.5, FontWeight.w700, BuddyLook.roseEnd, letterSpacing: 0)),
        ],
      ),
    );
    return Tap3D(
      key: FeedFilterSheet.nearPlusKey,
      onTap: canUpgrade ? () => SocialNav.openPlus(from: 'nearMe') : null,
      label: '${SocialStringsB.nearMe}, ${SocialStringsC.seePlus}',
      exclude: true,
      child: pill,
    );
  }

  @override
  Widget build(BuildContext context) {
    final whoIndex = FeedFilter.whoValues.indexOf(_f.who) < 0 ? 0 : FeedFilter.whoValues.indexOf(_f.who);
    final whoLabel = FeedFilterSheet.whoLabels[whoIndex];
    final travelIndex = FeedFilter.travelValues.indexOf(_f.travel) < 0 ? 0 : FeedFilter.travelValues.indexOf(_f.travel);
    final tone = ListingTone.indigo;
    return Sheet3D(
      tone: tone,
      title: SocialStringsB.trips,
      kicker: SocialStringsB.filtersKicker,
      centerTitle: false,
      size: SheetSize.form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(children: [
            _head(SocialStringsB.where, _f.q.trim().isEmpty ? SocialStringsB.anywhere : _f.q.trim()),
            Gap.v(10),
            SheetSearchField(
              tone: tone,
              controller: _q,
              hint: SocialStringsB.cityOrPlace,
              leadingArt: ListingArt.search,
              flat: true,
              inputFormatters: noEmojiInputFormatters,
              onChanged: (v) => setState(() => _f = _f.copyWith(q: v)),
              margin: EdgeInsets.zero,
            ),
            Gap.v(12),
            Text(SocialStringsB.popular, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
            Gap.v(8),
            Wrap(
              spacing: DS.gh(8),
              runSpacing: DS.gv(8),
              children: [
                for (final p in SocialStringsB.popularPlaces)
                  SocialPickChip(label: p, selected: _f.q.trim().toLowerCase() == p.toLowerCase(), onTap: () => _setQ(_f.q.trim().toLowerCase() == p.toLowerCase() ? '' : p)),
              ],
            ),
          ]),
          _card(children: [
            _head(SocialStringsB.whoCanJoinCaps, whoLabel),
            Gap.v(10),
            SegmentTabs(
              key: FeedFilterSheet.whoKey,
              labels: FeedFilterSheet.whoLabels,
              selected: whoIndex,
              tone: tone,
              margin: EdgeInsets.zero,
              onTap: (i) => setState(() => _f = _f.copyWith(who: FeedFilter.whoValues[i])),
            ),
          ]),
          _card(children: [
            _head(SocialStringsB.travelByCaps, FeedFilterSheet.travelLabels[travelIndex]),
            Gap.v(10),
            SegmentTabs(
              key: FeedFilterSheet.travelKey,
              labels: FeedFilterSheet.travelLabels,
              selected: travelIndex,
              tone: tone,
              compact: true,
              margin: EdgeInsets.zero,
              onTap: (i) => setState(() => _f = _f.copyWith(travel: FeedFilter.travelValues[i])),
            ),
          ]),
          _card(children: [
            Row(
              children: [
                ExcludeSemantics(child: Art3D(asset: ListingArt.roundPushpin, size: 34, shadowBlur: 2, shadowOffset: const Offset(1, 3))),
                Gap.h(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(SocialStringsB.nearMe, style: Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                      Text(SocialStringsB.nearMeLine, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
                    ],
                  ),
                ),
                Gap.h(8),
                if (widget.nearMe)
                  Switch(
                    key: FeedFilterSheet.nearSwitchKey,
                    value: _f.near,
                    activeTrackColor: tone.g2,
                    onChanged: (v) => setState(() => _f = _f.copyWith(near: v)),
                  )
                else
                  _plusPill(),
              ],
            ),
          ]),
          Gap.v(18),
          GradientPillButton(
            key: FeedFilterSheet.showKey,
            tone: tone,
            label: SocialStringsB.showTrips,
            onTap: () => Navigator.of(context).pop(widget.nearMe ? _f.copyWith(q: _f.q.trim()) : _f.copyWith(q: _f.q.trim(), near: false)),
          ),
        ],
      ),
    );
  }
}
