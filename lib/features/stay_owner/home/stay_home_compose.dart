
import '../../../design/design.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../strings/stay_home_strings.dart';
import '../widgets/stay_widgets.dart';
import 'stay_attention_copy.dart';

enum StayHomeState { live, paused, areaPaused, review, rejected, takenDown }

abstract final class StayHomeCompose {
  static StayHomeState stateOf(OwnerHomeListing l) {
    if (l.underReview) return StayHomeState.review;
    if (l.rejected) return l.takenDown || l.everApproved ? StayHomeState.takenDown : StayHomeState.rejected;
    if (l.areaPaused || l.tabOff) return StayHomeState.areaPaused;
    if (!l.switchOn) return StayHomeState.paused;
    return StayHomeState.live;
  }

  static bool showsSwitch(StayHomeState s) => s == StayHomeState.live || s == StayHomeState.paused || s == StayHomeState.areaPaused;

  static String subtitle(StayHomeState s) => switch (s) {
        StayHomeState.live => StayHomeStrings.subLive,
        StayHomeState.paused => StayHomeStrings.subPaused,
        StayHomeState.areaPaused => StayHomeStrings.subAreaPaused,
        StayHomeState.review => StayHomeStrings.subReview,
        StayHomeState.rejected || StayHomeState.takenDown => StayHomeStrings.subNotLive,
      };

  static String pill(StayHomeState s, OwnerHomeListing l) => switch (s) {
        StayHomeState.live || StayHomeState.areaPaused => StayHomeStrings.livePill(l.isFeatured),
        StayHomeState.paused => StayHomeStrings.pillPaused,
        StayHomeState.review => StayHomeStrings.pillReview,
        StayHomeState.rejected => StayHomeStrings.pillRejected,
        StayHomeState.takenDown => StayHomeStrings.pillTakenDown,
      };

  static ListingTone tone(StayHomeState s) => switch (s) {
        StayHomeState.live || StayHomeState.areaPaused => ListingTone.cE,
        StayHomeState.paused => StayLook.grey,
        StayHomeState.review => ListingTone.sunrise,
        StayHomeState.rejected || StayHomeState.takenDown => ListingTone.coral,
      };

  static String art(StayHomeState s) => switch (s) {
        StayHomeState.live || StayHomeState.areaPaused || StayHomeState.paused => ListingArt.camping,
        StayHomeState.review => ListingArt.clipboard,
        StayHomeState.rejected || StayHomeState.takenDown => ListingArt.warning,
      };

  static String? line(StayHomeState s, OwnerHomeListing l) {
    switch (s) {
      case StayHomeState.areaPaused:
        return StayHomeStrings.lineAreaPaused;
      case StayHomeState.paused:
        return StayHomeStrings.linePaused;
      case StayHomeState.review:
        return StayHomeStrings.lineReview;
      case StayHomeState.rejected:
        return StayHomeStrings.rejectedLine(l.rejectedReason);
      case StayHomeState.takenDown:
        return StayHomeStrings.takenDownLine(l.rejectedReason);
      case StayHomeState.live:
        final sl = l.statusLine;
        if (sl != null) {
          final n = sl.args['count'];
          final count = n is num ? n.toInt() : null;
          switch (sl.code) {
            case 'NewNeedReply':
              if (count != null && count > 0) return StayHomeStrings.needReply(count);
            case 'CheckInsThisWeek':
              if (count != null && count > 0) return StayHomeStrings.checkIns(count);
            case 'Paused':
              return StayHomeStrings.linePaused;
            case 'Featured':
              final city = sl.args['city'];
              final c = city is String && city.isNotEmpty ? city : l.cityName;
              if (c != null && c.isNotEmpty) return StayHomeStrings.firstInTripPlans(c);
            case 'PlansStarted':
              return StayHomeStrings.plansStartedToday;
          }
        }
        return StayHomeStrings.lineLive;
    }
  }

  static StayNotifVariant variant(StayHomeState s) => switch (s) {
        StayHomeState.review => StayNotifVariant.review,
        StayHomeState.rejected => StayNotifVariant.rejected,
        _ => StayNotifVariant.live,
      };

  static List<OwnerAttention> attention(OwnerHomeDto d, {required bool denied, required bool hasShareDetails}) {
    final state = stateOf(d.listing);
    if (state == StayHomeState.takenDown) return const [];
    if (state == StayHomeState.rejected) {
      return denied ? const [OwnerAttention(code: StayAttentionCodes.notificationsOff, priority: StayAttentionCodes.notificationsPriority)] : const [];
    }
    final rows = [...d.attention];
    if (state == StayHomeState.review) {
      rows.removeWhere((a) => a.code != StayAttentionCodes.addShareDetails && a.code != StayAttentionCodes.notificationsOff);
      if (!hasShareDetails && !rows.any((a) => a.code == StayAttentionCodes.addShareDetails)) {
        rows.insert(0, const OwnerAttention(code: StayAttentionCodes.addShareDetails, priority: 10));
      }
    }
    rows.removeWhere((a) => a.code == StayAttentionCodes.notificationsOff);
    if (denied) rows.add(const OwnerAttention(code: StayAttentionCodes.notificationsOff, priority: StayAttentionCodes.notificationsPriority));
    final ordered = [for (var i = 0; i < rows.length; i++) (i, rows[i])]
      ..sort((a, b) {
        final byPriority = state == StayHomeState.review && a.$2.code != b.$2.code && (a.$2.code == StayAttentionCodes.notificationsOff || b.$2.code == StayAttentionCodes.notificationsOff)
            ? (a.$2.code == StayAttentionCodes.notificationsOff ? 1 : -1)
            : a.$2.priority.compareTo(b.$2.priority);
        return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
      });
    return [for (final e in ordered) e.$2];
  }

  static List<StayRowData> rowViews(List<OwnerAttention> rows, StayAttentionActions h, StayNotifVariant v) =>
      [for (final a in rows) ?StayAttentionCopy.of(a, h, notif: v)];
}
