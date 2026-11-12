import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/trip_shortlist_controller.dart';
import '../../trip_strings_guide.dart';
import '../../trip_strings_shortlist.dart';
import '../trip_ui.dart';
import 'trip_guide_card.dart';

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
    this.onChange,
  });

  final VoidCallback? onChange;

  final String? step;
  final bool hidePillNote;

  final String asset;
  final List<String> names;
  final bool stays;
  final bool sending;
  final int failed;
  final VoidCallback onSend;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return TripGuideFrame(
      title: TripStringsGuide.reviewTitle,
      body: TripStringsGuide.reviewBody(stays),
      asset: asset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _Slot(filled: i < names.length),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (step == null)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [for (final n in names) _NamePill(n)],
            )
          else
            _Pills(step: step!, stays: stays, sending: sending, hideNote: hidePillNote),
          const SizedBox(height: 8),
          Text(TripStringsGuide.shortlisted(names.length), textAlign: TextAlign.center, style: TypeTokens.caption),
          if (failed > 0) ...[
            const SizedBox(height: 8),
            Text(TripStringsShortlist.failedNote(failed, taxi: !stays),
                textAlign: TextAlign.center, style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.warning)),
          ],
          const SizedBox(height: 16),
          TripButton(
            label: failed > 0 ? TripStringsGuide.retrySend : TripStringsGuide.sendAll,
            loading: sending,
            onPressed: sending ? null : onSend,
          ),
          const SizedBox(height: 10),
          if (onChange != null) ...[
            TripButton(label: TripStringsGuide.changePicks, outlined: true, onPressed: sending ? null : onChange),
            const SizedBox(height: 10),
          ],
          TripButton(label: TripStringsGuide.notNow, outlined: true, onPressed: sending ? null : onNotNow),
        ],
      ),
    );
  }
}

class _Pills extends StatelessWidget {
  const _Pills({required this.step, required this.stays, required this.sending, this.hideNote = false});

  final bool hideNote;

  final String step;
  final bool stays;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final c = TripShortlistController.to;
    return Obx(() {
      final note = c.noteOf(step);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in c.activeOf(step))
                _Entry(
                  name: i.name,
                  reason: c.reasonOf(step, i.listingId) == null
                      ? null
                      : TripStringsShortlist.reasonLine(c.reasonOf(step, i.listingId)!, taxi: !stays),
                  onRemove: sending ? null : () => c.remove(step, i.listingId),
                ),
            ],
          ),
          if (note != null && !hideNote) ...[
            const SizedBox(height: 8),
            Text(note,
                textAlign: TextAlign.center, style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.warning)),
          ],
        ],
      );
    });
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.name, required this.reason, required this.onRemove});

  final String name;
  final String? reason;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: KitTone.trip.tint, borderRadius: KitMetrics.buttonRadius),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(12, FontWeight.w600, color: KitTone.trip.accentDark)),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: TripStringsShortlist.remove(name),
                    child: InkWell(
                      onTap: onRemove,
                      borderRadius: KitMetrics.buttonRadius,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                        child: Icon(Icons.close_rounded, size: 18, color: KitTone.trip.accentDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(reason!,
                    textAlign: TextAlign.center,
                    style: TypeTokens.style(11.5, FontWeight.w600, color: DesignColors.warning)),
              ),
          ],
        ),
      );
}

class _Slot extends StatelessWidget {
  const _Slot({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? KitTone.trip.tint : DesignColors.surface,
            border: Border.all(color: filled ? KitTone.trip.accentDark : DesignColors.borderStrong, width: filled ? 1.5 : 2),
          ),
          child: filled ? Icon(Icons.check_rounded, size: 22, color: KitTone.trip.accentDark) : null,
        ),
      );
}

class _NamePill extends StatelessWidget {
  const _NamePill(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: DecoratedBox(
          decoration: BoxDecoration(color: KitTone.trip.tint, borderRadius: KitMetrics.buttonRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(12, FontWeight.w600, color: KitTone.trip.accentDark)),
          ),
        ),
      );
}

class TripGuideSent extends StatelessWidget {
  const TripGuideSent({super.key, required this.asset, required this.count, required this.onContinue, this.taxi = false});

  final bool taxi;

  final String asset;
  final int count;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => TripGuideFrame(
        title: TripStringsGuide.sentTitle,
        body: TripStringsGuide.sentBody(count, taxi: taxi),
        asset: asset,
        child: TripButton(label: TripStringsGuide.next, onPressed: onContinue),
      );
}
