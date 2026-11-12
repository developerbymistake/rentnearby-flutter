import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../../../models/browse_item.dart';
import '../../../models/card_fact.dart';
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

  static final Color _danger = KitTone.danger.accentDark;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (taxi.status) {
      TaxiStatus.approved when taxi.isAvailable => ('LIVE', DesignColors.goodDeep),
      TaxiStatus.approved => ('OFFLINE', DesignColors.textMuted),
      TaxiStatus.pendingReview => ('UNDER REVIEW', DesignColors.warnDeep),
      TaxiStatus.rejected => ('REJECTED', _danger),
      _ => ('DRAFT', DesignColors.textMuted),
    };
    final approved = taxi.isApproved;
    return OwnerListingCard(
      tone: KitTone.taxi,
      iconAsset: TravelIcon.taxi,
      margin: EdgeInsets.zero,
      title: taxi.plateDisplay ?? 'My Taxi',
      subtitle: _timeAgo(taxi.createdAt),
      status: label,
      statusColor: color,
      facts: [if (taxi.minFare != null) CardFact('From ${BrowseItem.inr(taxi.minFare!)}')],
      header: taxi.pendingReportCount > 0 ? _reportStrip() : null,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('VEHICLE',
            style: TypeTokens.style(11, FontWeight.w700, color: DesignColors.textMuted, letterSpacing: 0.6)),
        const SizedBox(height: 3),
        Text(TaxiOptionSets.vehicleSummary(taxi),
            maxLines: 2, overflow: TextOverflow.ellipsis, style: TypeTokens.caption),
      ]),
      toggle: GestureDetector(
        onTap: approved ? null : onAvailableLocked,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: KitTone.taxi.tint, borderRadius: KitMetrics.tileSmall),
          child: Row(children: [
            Expanded(
              child: Text('Available now',
                  style: TypeTokens.style(12, FontWeight.w600,
                      color: approved ? DesignColors.textStrong : DesignColors.textSecondary)),
            ),
            SetupSwitch(value: approved && taxi.isAvailable, onChanged: approved ? onAvailableChanged : null),
          ]),
        ),
      ),
      rows: [
        if (taxi.routes.isNotEmpty)
          Column(children: [
            for (var i = 0; i < taxi.routes.length; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: DesignColors.dividerSoft),
              _routeRow(taxi.routes[i]),
            ],
          ]),
        if (!taxi.isDraft && (onTripLeads != null || onLocalRate != null))
          Column(children: [
            const Divider(height: 1, color: DesignColors.dividerSoft),
            if (onTripLeads != null)
              _linkRow(
                asset: TravelIcon.route,
                title: TripStrings.tripLeadsRow,
                trailing: newLeads > 0 ? KitTagChip(TripStrings.newCount(newLeads), color: _danger, solid: true) : null,
                onTap: onTripLeads,
              ),
            if (onLocalRate != null)
              _linkRow(
                asset: TravelIcon.taxi,
                title: TripStrings.localSightseeing,
                value: taxi.localDayRate == null ? null : TaxiOptionSets.localRateLabel(taxi.localDayRate!),
                action: taxi.localDayRate == null ? TripStrings.addLocalRate : TripStrings.edit,
                onTap: onLocalRate,
              ),
          ]),
        if (onDelete != null || onPreview != null || onShare != null) _actions(),
      ],
      strips: [
        if (taxi.isRejected)
          _strip(
            color: _danger,
            icon: Icons.cancel_outlined,
            text: taxi.rejectedReason != null && taxi.rejectedReason!.isNotEmpty
                ? 'Rejected: ${taxi.rejectedReason}'
                : 'Rejected',
            action: 'Fix and resubmit',
            onTap: onOpenSetup,
          ),
        if (taxi.isDraft)
          _strip(
            color: DesignColors.primary,
            icon: Icons.schedule_rounded,
            text: 'Setup not finished',
            action: 'Continue setup',
            onTap: onOpenSetup,
          ),
        if (taxi.isPendingReview)
          _strip(color: DesignColors.warnDeep, icon: Icons.schedule_rounded, text: 'Under review · We will notify you'),
      ],
    );
  }

  Widget _reportStrip() {
    final count = taxi.pendingReportCount;
    return GestureDetector(
      onTap: onReportsTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KitMetrics.touch),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: KitStatusStrip(
            label: '$count report${count == 1 ? '' : 's'} on this taxi',
            color: _danger,
            icon: Icons.warning_amber_rounded,
          ),
        ),
      ),
    );
  }

  Widget _strip({
    required Color color,
    required IconData icon,
    required String text,
    String? action,
    VoidCallback? onTap,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KitStatusStrip(label: text, color: color, icon: icon),
      if (action != null)
        Align(
          alignment: Alignment.centerRight,
          child: PillAction(label: action, tone: KitTone.solid(color), onTap: onTap, maxWidth: 220),
        ),
    ]);
  }

  Widget _routeRow(TaxiRouteModel r) {
    final base = taxi.locality.trim().toLowerCase();
    final fromDiffers = r.fromName.trim().toLowerCase() != base;
    final title = fromDiffers ? '${r.fromName} → ${r.toName}' : r.toName;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(13, FontWeight.w700, color: DesignColors.textStrong)),
            Text(TaxiOptionSets.tripLabel(r.tripType),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(BrowseItem.inr(r.fare),
              maxLines: 1, style: TypeTokens.style(13, FontWeight.w800, color: KitTone.taxi.accentDark)),
          if (onEditFare != null)
            PillAction(
              label: 'Edit fare',
              tone: KitTone.taxi,
              maxWidth: 120,
              onTap: () => onEditFare!(r),
            ),
        ]),
      ]),
    );
  }

  Widget _linkRow({
    required String asset,
    required String title,
    String? value,
    String? action,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: KitMetrics.tileSmall,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: KitTone.taxi.gradient),
            child: Image.asset(asset),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(13, FontWeight.w600, color: DesignColors.textStrong)),
              if (value != null) Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption),
            ]),
          ),
          const SizedBox(width: 8),
          if (trailing != null) trailing,
          if (action != null)
            Flexible(
              child: Text(action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(12, FontWeight.w700, color: KitTone.taxi.accentDark)),
            ),
          if (trailing != null || action == null)
            const Icon(Icons.chevron_right_rounded, size: 18, color: DesignColors.textDisabled),
        ]),
      ),
    );
  }

  Widget _actions() {
    final cells = <Widget>[
      if (onPreview != null)
        _actionCell(icon: Icons.visibility_outlined, label: 'View', color: DesignColors.primary, onTap: onPreview),
      if (onShare != null)
        _actionCell(icon: Icons.ios_share_rounded, label: 'Share', color: DesignColors.primary, onTap: onShare),
      if (onDelete != null)
        _actionCell(icon: Icons.delete_outline_rounded, label: 'Delete', color: _danger, onTap: onDelete),
    ];
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (int i = 0; i < cells.length; i++) ...[
          if (i > 0)
            Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 2), color: DesignColors.dividerSoft),
          Expanded(child: cells[i]),
        ],
      ]),
    );
  }

  Widget _actionCell({required IconData icon, required String label, required Color color, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: KitMetrics.touch),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 3),
          Text(label, style: TypeTokens.style(11, FontWeight.w600, color: color)),
        ]),
      ),
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
