import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/trip_shortlist_controller.dart';
import '../../trip_strings_guide.dart';
import '../../trip_strings_shortlist.dart';
import 'trip_guide_card.dart';

TextStyle _warn(double size) => Ink3D.text(size, FontWeight.w600, DesignColors.warning, height: 1.4, letterSpacing: 0);

class TripGuideShortlistReview extends StatelessWidget {
  const TripGuideShortlistReview({
    super.key,
    required this.asset,
    required this.names,
    required this.stays,
    required this.sending,
    required this.failed,
    required this.onSend,
    required this.onNotNow,
    this.step,
    this.hidePillNote = false,
    this.showSend = true,
    this.onChange,
    this.note,
    this.tone,
  });

  final VoidCallback? onChange;

  final String? step;
  final bool hidePillNote;
  final bool showSend;
  final String? note;
  final ListingTone? tone;

  final String asset;
  final List<String> names;
  final bool stays;
  final bool sending;
  final int failed;
  final VoidCallback onSend;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.indigo;
    final art = stays ? ListingArt.stay : ListingArt.taxi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Gap.v(16),
        if (step == null)
          Wrap(alignment: WrapAlignment.center, spacing: DS.gh(8), runSpacing: DS.gv(8), children: [for (final n in names) _Entry(name: n, art: art, tone: t, short: !stays)])
        else
          _Pills(step: step!, stays: stays, sending: sending, hideNote: hidePillNote, art: art, tone: t),
        Padding(
          padding: EdgeInsets.only(top: DS.gv(8)),
          child: Text(TripStringsGuide.shortlisted(names.length), textAlign: TextAlign.center, style: Ink3D.text(12, FontWeight.w500, Ink3D.hint, letterSpacing: 0)),
        ),
        if (failed > 0)
          Padding(
            padding: EdgeInsets.only(top: DS.gv(6)),
            child: Text(TripStringsShortlist.failedNote(failed, taxi: !stays), style: _warn(12.5)),
          ),
        if (note != null)
          Padding(
            padding: EdgeInsets.only(top: DS.gv(6)),
            child: Text(note!, key: const ValueKey('guide-send-note'), style: _warn(12.5)),
          ),
        if (showSend)
          Padding(
            padding: EdgeInsets.only(top: DS.gv(22)),
            child: TripGuideSheetButton(
              label: failed > 0 ? TripStringsGuide.retrySend : TripStringsGuide.sendAll,
              tone: t,
              loading: sending,
              onTap: sending ? null : onSend,
            ),
          ),
        if (onChange != null)
          Padding(
            padding: EdgeInsets.only(top: DS.gv(12)),
            child: TripGuideSheetButton(label: TripStringsGuide.changePicks, tone: t, primary: false, onTap: sending ? null : onChange),
          ),
        Padding(
          padding: EdgeInsets.only(top: DS.gv(onChange != null || showSend ? 8 : 10)),
          child: Center(child: TripGuideLink(label: TripStringsGuide.notNow, onTap: sending ? null : onNotNow)),
        ),
      ],
    );
  }
}

class _Pills extends StatelessWidget {
  const _Pills({required this.step, required this.stays, required this.sending, required this.art, required this.tone, this.hideNote = false});

  final bool hideNote;

  final String step;
  final bool stays;
  final bool sending;
  final String art;
  final ListingTone tone;

  @override
  Widget build(BuildContext context) {
    final c = TripShortlistController.to;
    return Obx(() {
      final note = c.noteOf(step);
      final items = c.activeOf(step);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: DS.gh(8),
            runSpacing: DS.gv(8),
            children: [
              for (final i in items)
                _Entry(
                  name: i.name,
                  art: art,
                  tone: tone,
                  short: !stays,
                  reason: c.reasonOf(step, i.listingId) == null
                      ? null
                      : TripStringsShortlist.reasonLine(c.reasonOf(step, i.listingId)!, taxi: !stays),
                  onRemove: sending ? null : () => c.remove(step, i.listingId),
                  removable: true,
                ),
            ],
          ),
          if (note != null && !hideNote)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(10)),
              child: Text(note, style: _warn(12.5)),
            ),
        ],
      );
    });
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.name, required this.art, required this.tone, this.reason, this.onRemove, this.removable = false, this.short = false});

  final String name;
  final String art;
  final ListingTone tone;
  final String? reason;
  final VoidCallback? onRemove;
  final bool removable;
  final bool short;

  String get _shown {
    final t = name.trim();
    if (!short) return t;
    final i = t.indexOf(' ');
    return i > 0 ? t.substring(0, i) : t;
  }

  @override
  Widget build(BuildContext context) {
    final remove = Semantics(
      button: true,
      enabled: onRemove != null,
      label: TripStringsShortlist.remove(name),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRemove,
        child: SizedBox(
          width: DS.s(36),
          height: DS.s(36),
          child: Center(
            child: Container(
              width: DS.s(22),
              height: DS.s(22),
              decoration: BoxDecoration(shape: BoxShape.circle, color: onRemove == null ? tone.tint : DesignColors.surface),
              child: Icon(Icons.close_rounded, size: DS.s(15), color: tone.text),
            ),
          ),
        ),
      ),
    );
    final chip = Container(
      padding: DS.insets(l: 6, t: removable ? 0 : 5, r: removable ? 2 : 14, b: removable ? 0 : 5),
      constraints: BoxConstraints(minHeight: DS.s(40)),
      decoration: BoxDecoration(color: tone.tint, borderRadius: DS.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Semantics(
              container: true,
              label: name,
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(art, width: DS.s(28), height: DS.s(28), fit: BoxFit.contain),
                  Gap.h(6),
                  Flexible(child: Text(_shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, tone.text))),
                ],
              ),
            ),
          ),
          if (removable) remove,
        ],
      ),
    );
    if (reason == null) return chip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        chip,
        Padding(
          padding: EdgeInsets.only(top: DS.gv(4), left: DS.s(6)),
          child: Text(reason!, style: _warn(12)),
        ),
      ],
    );
  }
}

class TripGuideSentRows extends StatelessWidget {
  const TripGuideSentRows({super.key, required this.names, required this.art});

  final List<String> names;
  final String art;

  static final _tones = [ListingTone.cB, ListingTone.cA, ListingTone.cC];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < names.length; i++)
            OptionCard(tone: _tones[i % _tones.length], art: art, label: TripStringsGuide.sentRow(names[i]), state: OptionState.on),
        ],
      );
}

class TripGuideSent extends StatelessWidget {
  const TripGuideSent({super.key, required this.asset, required this.count, required this.onContinue, this.taxi = false, this.names = const []});

  final bool taxi;
  final List<String> names;

  final String asset;
  final int count;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => TripGuideFrame(
        title: TripStringsGuide.sentTitle,
        body: TripStringsGuide.sentBody(count, taxi: taxi),
        asset: asset,
        child: TripGuideSentRows(names: names, art: asset),
      );
}
