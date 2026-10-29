import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../models/browse_item.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.premium(TaxiColors.accentDark, alpha: 0.10, blur: 16, offset: const Offset(0, 6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (taxi.pendingReportCount > 0) _reportStrip(),
        _photoSection(),
        _content(),
        if (taxi.isRejected)
          _bottomStrip(
            color: AppColors.error,
            icon: Iconsax.close_circle,
            text: taxi.rejectedReason != null && taxi.rejectedReason!.isNotEmpty
                ? 'Rejected: ${taxi.rejectedReason}'
                : 'Rejected',
            action: 'Fix and resubmit',
            onTap: onOpenSetup,
          ),
        if (taxi.isDraft)
          _bottomStrip(
            color: TaxiColors.accentDark,
            icon: Iconsax.clock,
            text: 'Setup not finished',
            action: 'Continue setup',
            onTap: onOpenSetup,
          ),
        if (taxi.isPendingReview)
          _bottomStrip(
            color: AppColors.warningSurface,
            foreground: AppColors.warningText,
            icon: Iconsax.clock,
            text: 'Under review · We will notify you',
          ),
      ]),
    );
  }

  Widget _reportStrip() {
    final count = taxi.pendingReportCount;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: GestureDetector(
        onTap: onReportsTap,
        child: Container(
          width: double.infinity,
          color: AppColors.reportAlert,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            const Icon(Iconsax.warning_2, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Expanded(
              child: Text('$count report${count == 1 ? '' : 's'} on this taxi',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.white),
          ]),
        ),
      ),
    );
  }

  Widget _bottomStrip({
    required Color color,
    Color foreground = Colors.white,
    required IconData icon,
    required String text,
    String? action,
    VoidCallback? onTap,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          color: color,
          padding: EdgeInsets.fromLTRB(12, 8, 12, action != null ? 0 : 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 15, color: foreground),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: foreground)),
              ),
            ]),
            if (action != null)
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Center(
                    widthFactor: 1,
                    child: Text(action,
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: foreground,
                            decoration: TextDecoration.underline,
                            decorationColor: foreground)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _photoSection() {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: taxi.pendingReportCount > 0 ? Radius.zero : const Radius.circular(16),
      ),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: const BoxDecoration(gradient: TaxiColors.heroGradient),
        child: Stack(children: [
          const Center(child: Icon(Iconsax.car, size: 40, color: TaxiColors.accent)),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: _statusBadge()),
              if (taxi.minFare != null) ...[
                const SizedBox(width: 8),
                Flexible(child: _fareBadge()),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _statusBadge() {
    final (String label, Color bg, Color fg) = switch (taxi.status) {
      TaxiStatus.approved when taxi.isAvailable => ('LIVE', AppColors.successSurface, AppColors.successText),
      TaxiStatus.approved => ('OFFLINE', AppColors.neutralChip, AppColors.textLight),
      TaxiStatus.pendingReview => ('UNDER REVIEW', AppColors.warningSurface, AppColors.warningText),
      TaxiStatus.rejected => ('REJECTED', AppColors.errorSurface, AppColors.errorText),
      _ => ('DRAFT', AppColors.neutralChip, AppColors.textLight),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.4)),
    );
  }

  Widget _fareBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.93),
          borderRadius: BorderRadius.circular(999),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('From ${BrowseItem.inr(taxi.minFare!)}',
              maxLines: 1,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: TaxiColors.accentDark)),
        ),
      );

  Widget _content() {
    final vehicle = TaxiOptionSets.vehicleSummary(taxi);
    final approved = taxi.isApproved;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(taxi.plateDisplay ?? 'My Taxi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          Text(_timeAgo(taxi.createdAt), style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textHint)),
        ]),
        const SizedBox(height: 8),
        _fieldLabel('Vehicle'),
        const SizedBox(height: 3),
        Text(vehicle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: approved ? null : onAvailableLocked,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: TaxiColors.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                child: Text('Available now',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: approved ? TaxiColors.accentDark : AppColors.textLight)),
              ),
              Switch(
                value: approved && taxi.isAvailable,
                onChanged: approved ? onAvailableChanged : null,
                activeThumbColor: AppColors.success,
                activeTrackColor: AppColors.successTrack,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ]),
          ),
        ),
        if (taxi.routes.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (var i = 0; i < taxi.routes.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.divider),
            _routeRow(taxi.routes[i]),
          ],
        ],
        if (onDelete != null || onPreview != null || onShare != null) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),
          _actions(),
        ],
      ]),
    );
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
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            Text(TaxiOptionSets.tripLabel(r.tripType),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(BrowseItem.inr(r.fare),
              maxLines: 1,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold)),
          if (onEditFare != null)
            InkWell(
              onTap: () => onEditFare!(r),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Edit fare',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: taxi.isPendingReview ? AppColors.textHint : TaxiColors.accentDark)),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _actions() {
    final cells = <Widget>[
      if (onPreview != null) _actionCell(icon: Iconsax.eye, label: 'View', color: TaxiColors.accentDark, onTap: onPreview),
      if (onShare != null) _actionCell(icon: Iconsax.export_1, label: 'Share', color: TaxiColors.accentDark, onTap: onShare),
      if (onDelete != null) _actionCell(icon: Iconsax.trash, label: 'Delete', color: AppColors.error, onTap: onDelete),
    ];
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (int i = 0; i < cells.length; i++) ...[
          if (i > 0) Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 2), color: AppColors.divider),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text.toUpperCase(),
      style: const TextStyle(
          fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.textHint));

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
