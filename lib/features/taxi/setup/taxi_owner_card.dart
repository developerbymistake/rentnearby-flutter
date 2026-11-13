import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_taxi_owner.dart';
import '../../../models/browse_item.dart';
import '../../trip/trip_strings.dart';
import '../models/taxi_owner_model.dart';
import '../taxi_option_sets.dart';

class TaxiOwnerCard extends StatelessWidget {
  final TaxiOwnerModel taxi;
  final ValueChanged<bool>? onAvailableChanged;
  final VoidCallback? onAvailableLocked;
  final ValueChanged<TaxiRouteModel>? onEditFare;
  final VoidCallback? onPreview;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onReportsTap;
  final VoidCallback? onOpenSetup;
  final VoidCallback? onTripLeads;
  final int newLeads;
  final VoidCallback? onLocalRate;

  const TaxiOwnerCard({
    super.key,
    required this.taxi,
    this.onAvailableChanged,
    this.onAvailableLocked,
    this.onEditFare,
    this.onPreview,
    this.onShare,
    this.onDelete,
    this.onReportsTap,
    this.onOpenSetup,
    this.onTripLeads,
    this.newLeads = 0,
    this.onLocalRate,
  });

  @override
  Widget build(BuildContext context) {
    final status = switch (taxi.status) {
      TaxiStatus.approved when taxi.isAvailable => TaxiOwnerStatus.live,
      TaxiStatus.approved => TaxiOwnerStatus.offline,
      TaxiStatus.pendingReview => TaxiOwnerStatus.review,
      TaxiStatus.rejected => TaxiOwnerStatus.rejected,
      _ => TaxiOwnerStatus.draft,
    };
    final approved = taxi.isApproved;
    final count = taxi.pendingReportCount;
    final leadsParts = TripStrings.tripLeadsRow.split(' · ');
    final leadsSub = leadsParts.length > 1 ? leadsParts[1][0].toUpperCase() + leadsParts[1].substring(1) : '';
    final base = taxi.locality.trim().toLowerCase();

    final (String? stripArt, String? strip, String? stripAction) = taxi.isRejected
        ? (
            ListingArt.pushpin,
            taxi.rejectedReason != null && taxi.rejectedReason!.isNotEmpty ? 'Rejected: ${taxi.rejectedReason}' : 'Rejected',
            'Fix and resubmit',
          )
        : taxi.isDraft
            ? (ListingArt.clipboard, 'Setup not finished', 'Continue setup')
            : taxi.isPendingReview
                ? (ListingArt.calendar, 'Under review · We will notify you', null)
                : (null, null, null);

    return TaxiOwnerCard3D(
      tone: ListingTone.coral,
      status: status,
      title: taxi.plateDisplay ?? 'My Taxi',
      ago: _timeAgo(taxi.createdAt),
      vehicleLabel: 'VEHICLE',
      vehicle: TaxiOptionSets.vehicleSummary(taxi),
      fromLabel: 'FROM',
      from: taxi.minFare != null ? BrowseItem.inr(taxi.minFare!) : '—',
      available: approved && taxi.isAvailable,
      onAvailable: approved ? onAvailableChanged : null,
      onAvailableLocked: approved ? null : onAvailableLocked,
      report: count > 0 ? '$count report${count == 1 ? '' : 's'} on this taxi' : null,
      onReport: onReportsTap,
      routes: [
        for (final r in taxi.routes)
          TaxiOwnerRoute(
            title: r.fromName.trim().toLowerCase() != base ? '${r.fromName} → ${r.toName}' : r.toName,
            trip: TaxiOptionSets.tripLabel(r.tripType),
            fare: BrowseItem.inr(r.fare),
            onEdit: onEditFare == null ? null : () => onEditFare!(r),
          ),
      ],
      links: [
        if (!taxi.isDraft && onTripLeads != null)
          TaxiOwnerLink(
            art: ListingArt.compass,
            title: leadsParts.first,
            subtitle: leadsSub,
            pill: newLeads > 0 ? TripStrings.newCount(newLeads) : 'Open',
            red: newLeads > 0,
            onTap: onTripLeads,
          ),
        if (!taxi.isDraft && onLocalRate != null)
          TaxiOwnerLink(
            art: ListingArt.taxi,
            title: TripStrings.localSightseeing,
            subtitle: taxi.localDayRate == null ? '' : TaxiOptionSets.localRateLabel(taxi.localDayRate!),
            pill: taxi.localDayRate == null ? TripStrings.addLocalRate : TripStrings.edit,
            onTap: onLocalRate,
          ),
      ],
      stripArt: stripArt,
      strip: strip,
      stripAction: stripAction,
      onStrip: stripAction == null ? null : onOpenSetup,
      actions: onDelete != null || onPreview != null || onShare != null
          ? [
              TaxiOwnerAction(icon: Icons.visibility_rounded, label: 'View', onTap: onPreview),
              TaxiOwnerAction(icon: Icons.north_east_rounded, label: 'Share', onTap: onShare),
              TaxiOwnerAction(icon: Icons.close_rounded, label: 'Delete', onTap: onDelete),
            ]
          : const [],
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }
}
