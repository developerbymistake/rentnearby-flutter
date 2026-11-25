import '../../../design/design.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../strings/taxi_home_strings.dart';
import '../widgets/taxi_widgets.dart';
import 'taxi_attention_copy.dart';

enum TaxiHomeState { live, offline, review, changesReview, rejected, takenDown }

enum TaxiRingStrip { ringing, offline, muted }

abstract final class TaxiHomeCompose {
  static TaxiHomeState shown(TaxiHomeState s, {required bool switchOn}) =>
      s == TaxiHomeState.live || s == TaxiHomeState.offline ? (switchOn ? TaxiHomeState.live : TaxiHomeState.offline) : s;

  static TaxiRingStrip? ringStrip(TaxiHomeState shown, {required bool denied}) => switch (shown) {
        TaxiHomeState.live => denied ? TaxiRingStrip.muted : TaxiRingStrip.ringing,
        TaxiHomeState.offline => TaxiRingStrip.offline,
        _ => null,
      };

  static TaxiHomeState stateOf(OwnerHomeListing l) {
    if (l.underReview) return l.everApproved ? TaxiHomeState.changesReview : TaxiHomeState.review;
    if (l.rejected || l.takenDown) return l.takenDown || l.everApproved ? TaxiHomeState.takenDown : TaxiHomeState.rejected;
    if (!l.switchOn) return TaxiHomeState.offline;
    return TaxiHomeState.live;
  }

  static bool showsSwitch(TaxiHomeState s) => s == TaxiHomeState.live || s == TaxiHomeState.offline || s == TaxiHomeState.changesReview;

  static bool showsNumbers(TaxiHomeState s) => s != TaxiHomeState.review && s != TaxiHomeState.rejected;

  static String subtitle(TaxiHomeState s, {String? onTripUntil}) => switch (s) {
        TaxiHomeState.live => onTripUntil != null ? TaxiHomeStrings.subOnTrip(onTripUntil) : TaxiHomeStrings.subOnline,
        TaxiHomeState.offline => TaxiHomeStrings.subOffline,
        TaxiHomeState.review => TaxiHomeStrings.subReview,
        TaxiHomeState.changesReview => TaxiHomeStrings.subChangesReview,
        TaxiHomeState.rejected => TaxiHomeStrings.subRejected,
        TaxiHomeState.takenDown => TaxiHomeStrings.subNotLive,
      };

  static String? pill(TaxiHomeState s) => switch (s) {
        TaxiHomeState.review => TaxiHomeStrings.pillReview,
        TaxiHomeState.rejected => TaxiHomeStrings.pillRejected,
        TaxiHomeState.takenDown => TaxiHomeStrings.pillTakenDown,
        _ => null,
      };

  static String line(TaxiHomeState s, OwnerHomeListing l) => switch (s) {
        TaxiHomeState.live => l.isFeatured ? TaxiHomeStrings.lineFeatured : TaxiHomeStrings.lineLive,
        TaxiHomeState.offline => TaxiHomeStrings.lineOffline,
        TaxiHomeState.review => TaxiHomeStrings.lineReview,
        TaxiHomeState.changesReview => TaxiHomeStrings.lineChangesReview,
        TaxiHomeState.rejected => TaxiHomeStrings.rejectedLine(l.rejectedReason),
        TaxiHomeState.takenDown => TaxiHomeStrings.takenDownLine(l.rejectedReason),
      };

  static ListingTone tone(TaxiHomeState s) => switch (s) {
        TaxiHomeState.live => ListingTone.cE,
        TaxiHomeState.offline || TaxiHomeState.changesReview => TaxiLook.grey,
        TaxiHomeState.review => ListingTone.sunrise,
        TaxiHomeState.rejected || TaxiHomeState.takenDown => ListingTone.coral,
      };

  static String art(TaxiHomeState s) =>
      s == TaxiHomeState.rejected || s == TaxiHomeState.takenDown ? ListingArt.warning : ListingArt.taxi;

  // One banner at a time: the planner switch (everyone) wins over the area switch.
  static String? banner(TaxiHomeState s, OwnerHomeListing l) {
    if (s != TaxiHomeState.live && s != TaxiHomeState.offline) return null;
    if (l.plannerOff) return TaxiHomeStrings.plannerPaused;
    if (l.areaPaused || l.tabOff) return TaxiHomeStrings.areaPaused;
    return null;
  }

  static List<OwnerAttention> attention(OwnerHomeDto d, {required bool denied}) {
    final state = stateOf(d.listing);
    if (state == TaxiHomeState.takenDown || state == TaxiHomeState.rejected) return const [];
    final rows = [...d.attention]..removeWhere((a) => a.code == TaxiAttentionCodes.notificationsOff);
    if (state == TaxiHomeState.review) {
      rows.removeWhere((a) => a.code != TaxiAttentionCodes.noPushToken);
    }
    if (denied) rows.add(const OwnerAttention(code: TaxiAttentionCodes.notificationsOff, priority: TaxiAttentionCodes.notificationsPriority));
    final ordered = [for (var i = 0; i < rows.length; i++) (i, rows[i])]
      ..sort((a, b) {
        final c = a.$2.priority.compareTo(b.$2.priority);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return [for (final e in ordered) e.$2];
  }

  static int attentionCount(OwnerHomeDto d, List<OwnerAttention> rows, {required bool denied}) {
    final serverRows = d.attention.where((a) => a.code != TaxiAttentionCodes.notificationsOff).length;
    final base = d.attentionCount > serverRows ? d.attentionCount : serverRows;
    final total = base + (denied ? 1 : 0);
    return rows.length > total ? rows.length : total;
  }

  static List<TaxiRowData> rowViews(List<OwnerAttention> rows, TaxiAttentionActions h, DateTime now, {bool compact = true}) =>
      [for (final a in rows) ?TaxiAttentionCopy.of(a, h, now: now, compact: compact)];
}
