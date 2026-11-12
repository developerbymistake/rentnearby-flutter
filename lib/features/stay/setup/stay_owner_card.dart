import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../design/design.dart';
import '../../../models/browse_item.dart';
import '../../../models/card_fact.dart';
import '../../trip/trip_strings.dart';
import '../enquiries/stay_enquiry_strings.dart';
import '../models/stay_owner_model.dart';

class StayOwnerCard extends StatelessWidget {
  final StayOwnerModel stay;
  final ValueChanged<bool>? onAcceptingChanged;
  final ValueChanged<StayRoomModel>? onEditPrice;
  final VoidCallback? onPreview;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onReportsTap;
  final VoidCallback? onOpenSetup;
  final VoidCallback? onEnquiries;
  final RxInt? enquiryNewCount;

  const StayOwnerCard({
    super.key,
    required this.stay,
    this.onAcceptingChanged,
    this.onEditPrice,
    this.onPreview,
    this.onShare,
    this.onDelete,
    this.onReportsTap,
    this.onOpenSetup,
    this.onEnquiries,
    this.enquiryNewCount,
  });

  @override
  Widget build(BuildContext context) {
    final photo = stay.photos.isNotEmpty ? stay.photos.first.url : null;
    final (String label, Color color) = _status();
    return OwnerListingCard(
      title: stay.name ?? 'My Stay',
      subtitle: _timeAgo(stay.createdAt),
      thumbnailUrl: photo,
      iconAsset: TravelIcon.stay,
      tone: KitTone.stay,
      status: label,
      statusColor: color,
      facts: [if (stay.minPricePerNight != null) CardFact('From ${BrowseItem.inr(stay.minPricePerNight!)}/night')],
      margin: EdgeInsets.zero,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('LOCALITY',
            style: TypeTokens.style(11, FontWeight.w700, color: DesignColors.textMuted, letterSpacing: 0.6)),
        const SizedBox(height: 3),
        Row(children: [
          const TravelIcon(TravelIcon.place, size: 14),
          const SizedBox(width: 4),
          Expanded(child: Text(stay.locality, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.caption)),
        ]),
      ]),
      toggle: stay.isApproved ? _toggle() : null,
      rows: [
        if (stay.rooms.isNotEmpty) _rooms(),
        if (onEnquiries != null && !stay.isDraft) ...[_divider, _enquiriesRow()],
        if (onDelete != null || onPreview != null || onShare != null) ...[_divider, _actions()],
      ],
      strips: [
        if (stay.pendingReportCount > 0) _reportStrip(),
        if (stay.isRejected) _rejectStrip(),
        if (stay.isDraft)
          _strip(
            color: KitTone.stay.accentDark,
            icon: Icons.edit_calendar_rounded,
            text: 'Setup not finished',
            action: 'Continue setup',
            onTap: onOpenSetup,
          ),
        if (stay.isPendingReview)
          _strip(color: DesignColors.warnDeep, icon: Icons.hourglass_top_rounded, text: 'Under review · We will notify you'),
      ],
    );
  }

  static const Widget _divider = Divider(height: 1, color: DesignColors.dividerSoft);

  (String, Color) _status() => switch (stay.status) {
        StayStatus.approved when stay.acceptingGuests => ('LIVE', DesignColors.goodDeep),
        StayStatus.approved => ('PAUSED', DesignColors.textMuted),
        StayStatus.pendingReview => ('UNDER REVIEW', DesignColors.warnDeep),
        StayStatus.rejected => ('REJECTED', KitTone.danger.accentDark),
        _ => ('DRAFT', DesignColors.textMuted),
      };

  Widget _toggle() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: KitTone.stay.tint, borderRadius: CardRadius.chip),
        child: Row(children: [
          Expanded(
            child: Text('Accepting guests', style: TypeTokens.style(12, FontWeight.w600, color: KitTone.stay.accentDark)),
          ),
          SetupSwitch(value: stay.acceptingGuests, onChanged: onAcceptingChanged),
        ]),
      );

  Widget _rooms() => Column(children: [
        for (var i = 0; i < stay.rooms.length; i++) ...[
          if (i > 0) _divider,
          _roomRow(stay.rooms[i]),
        ],
      ]);

  Widget _reportStrip() {
    final count = stay.pendingReportCount;
    return _strip(
      color: KitTone.danger.accentDark,
      icon: Icons.warning_amber_rounded,
      text: '$count report${count == 1 ? '' : 's'} on this stay',
      onTap: onReportsTap,
      chevron: true,
    );
  }

  Widget _rejectStrip() {
    final reason = stay.rejectedReason;
    return _strip(
      color: KitTone.danger.accentDark,
      icon: Icons.close_rounded,
      text: reason != null && reason.isNotEmpty ? 'Rejected: $reason' : 'Rejected',
      action: 'Fix and resubmit',
      onTap: onOpenSetup,
    );
  }

  Widget _strip({
    required Color color,
    required IconData icon,
    required String text,
    String? action,
    VoidCallback? onTap,
    bool chevron = false,
  }) {
    final style = TypeTokens.style(12, FontWeight.w600, color: color);
    return PressScale(
      enabled: onTap != null,
      child: Material(
        color: DesignColors.tint(color, Alpha.tint),
        borderRadius: KitMetrics.tileSmall,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: style)),
                if (chevron) Icon(Icons.chevron_right_rounded, size: 18, color: color),
              ]),
              if (action != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(action,
                        style: TypeTokens.style(12, FontWeight.w700, color: color)
                            .copyWith(decoration: TextDecoration.underline, decorationColor: color)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _roomRow(StayRoomModel r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text('${r.label} · ${BrowseItem.inr(r.pricePerNight)} / night',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.style(12, FontWeight.w400, color: DesignColors.textSecondary)),
          ),
          if (onEditPrice != null && !stay.isPendingReview)
            GestureDetector(
              onTap: () => onEditPrice!(r),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text('Edit price',
                    style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.primary)),
              ),
            ),
        ]),
      );

  Widget _enquiriesRow() {
    return InkWell(
      onTap: onEnquiries,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Image.asset(SetupAssets.chat, width: 28, height: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(TripStrings.enquiries,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.style(13, FontWeight.w600, color: DesignColors.textStrong)),
                Text(StayEnquiryStrings.rowSubtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.caption),
              ]),
            ),
            if (enquiryNewCount != null)
              Obx(() {
                final n = enquiryNewCount!.value;
                if (n <= 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: KitTone.danger.accentDark, borderRadius: CardRadius.chip),
                  child: Text(TripStrings.newCount(n),
                      maxLines: 1, style: TypeTokens.style(11, FontWeight.w700, color: DesignColors.onPrimary)),
                );
              }),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: DesignColors.textDisabled),
          ]),
        ),
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
        _actionCell(icon: Icons.delete_outline_rounded, label: 'Delete', color: KitTone.danger.accentDark, onTap: onDelete),
    ];
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (int i = 0; i < cells.length; i++) ...[
          if (i > 0) Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 2), color: DesignColors.divider),
          Expanded(child: cells[i]),
        ],
      ]),
    );
  }

  Widget _actionCell({required IconData icon, required String label, required Color color, required VoidCallback? onTap}) {
    return PressScale(
      child: InkWell(
        onTap: onTap,
        splashColor: DesignColors.splash,
        highlightColor: Colors.transparent,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: KitMetrics.touch),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(label, style: TypeTokens.style(11, FontWeight.w600, color: color)),
          ]),
        ),
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
