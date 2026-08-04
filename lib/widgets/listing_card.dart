import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_tour_state.dart';
import '../models/listing_model.dart';
import 'pulse_once.dart';

class ListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;
  final VoidCallback? onGoLive;
  final bool isGoLiveLoading;
  final VoidCallback? onReportsTap;
  final VoidCallback? onPreview;
  final VoidCallback? onShare;

  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onDelete,
    this.onToggleActive,
    this.onGoLive,
    this.isGoLiveLoading = false,
    this.onReportsTap,
    this.onPreview,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (listing.pendingReportCount > 0) _buildReportAlertStrip(),
            _buildPhotoSection(),
            _buildContentSection(),
            if (listing.isRejected) _buildRejectionStrip(),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionStrip() {
    final reason = listing.rejectionReason;
    final text = reason != null && reason.isNotEmpty ? 'Rejected: $reason' : 'Rejected';
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Container(
        width: double.infinity,
        color: AppColors.error,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportAlertStrip() {
    final count = listing.pendingReportCount;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: GestureDetector(
        onTap: onReportsTap,
        child: Container(
          width: double.infinity,
          color: AppColors.reportAlert,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Iconsax.warning_2, size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$count report${count == 1 ? '' : 's'} on this listing',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: listing.pendingReportCount > 0 ? Radius.zero : const Radius.circular(16),
          ),
          child: listing.photos.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: listing.photos.first,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => _photoPlaceholder(),
                  errorWidget: (_, _, _) => _photoPlaceholder(),
                )
              : _photoPlaceholder(),
        ),
        // Status badge — top left
        Positioned(
          top: 10,
          left: 10,
          child: _statusBadge(),
        ),
        // Price badge — top right
        if (listing.priceMonthly != null)
          Positioned(
            top: 10,
            right: 10,
            child: _priceBadge(),
          ),
      ],
    );
  }

  Widget _statusBadge() {
    final String label;
    final List<Color> colors;
    if (listing.isActive) {
      label = 'LIVE';
      colors = [const Color(0xFF10B981), const Color(0xFF059669)];
    } else {
      label = 'OFFLINE';
      colors = [const Color(0xFF94A3B8), const Color(0xFF64748B)];
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        listing.priceDisplay,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room type + time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  listing.roomTypeName ?? 'Room for Rent',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _timeAgo(listing.createdAt),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Two-column info grid: Locality + Expires in, then full-width Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Locality'),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Iconsax.location, size: 13, color: AppColors.primaryLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [listing.districtName, listing.cityName]
                                .where((e) => e != null && e.isNotEmpty)
                                .join(', '),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (listing.validUntil != null) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Expires in'),
                    const SizedBox(height: 3),
                    _expiryLabel(listing.validUntil!),
                  ],
                ),
              ],
            ],
          ),
          if (listing.address != null && listing.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Address'),
                const SizedBox(height: 3),
                Text(
                  listing.address!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
          if (onDelete != null || onToggleActive != null || onGoLive != null || onPreview != null || onShare != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            _buildActions(),
          ],
        ],
      ),
    );
  }

  // Whichever of these mutually-exclusive Live-state widgets applies becomes the row's
  // first cell; null when none of the conditions match (e.g. onGoLive not supplied).
  Widget? _stateWidget() {
    if (!listing.isActive && !listing.isPendingReview && !listing.isRejected && onGoLive != null) {
      return _makeItLiveButton();
    } else if (listing.isActive && onToggleActive != null) {
      return _liveToggle();
    } else if (listing.isPendingReview) {
      return _pendingReviewBadge();
    } else if (listing.isRejected) {
      return _rejectedBadge();
    }
    return null;
  }

  Widget _buildActions() {
    final stateWidget = _stateWidget();
    final cells = <Widget>[
      if (stateWidget != null) FittedBox(fit: BoxFit.scaleDown, child: stateWidget),
      if (onPreview != null)
        _actionCell(icon: Iconsax.eye, label: 'View', color: AppColors.primary, onTap: onPreview),
      if (onShare != null)
        _actionCell(icon: Icons.share_rounded, label: 'Share', color: AppColors.primary, onTap: onShare),
      if (onDelete != null)
        _actionCell(icon: Iconsax.trash, label: 'Delete', color: AppColors.error, onTap: onDelete),
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < cells.length; i++) ...[
            if (i > 0) Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 2), color: AppColors.divider),
            Expanded(child: cells[i]),
          ],
        ],
      ),
    );
  }

  // One equal-width cell of the actions row: icon above a visible text label, whole
  // cell tappable (not just the icon/text glyphs).
  Widget _actionCell({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _makeItLiveButton() {
    return Obx(() => PulseOnce(
      paused: tourInProgress.value,
      child: GestureDetector(
      onTap: isGoLiveLoading ? null : onGoLive,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: isGoLiveLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rocket_launch_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Make it Live',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
        ),
      ),
    ));
  }

  Widget _pendingReviewBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.clock, size: 14, color: Color(0xFFD97706)),
          SizedBox(width: 6),
          Text(
            'In Review',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rejectedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.close_circle, size: 14, color: AppColors.error),
          SizedBox(width: 6),
          Text(
            'Rejected',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  // Stacked (switch above, label below) to match the other three cells' icon-above-label
  // shape — a horizontal Text+Switch pair needs more width than an equal 1/4 column has,
  // which was overflowing into the neighboring View cell.
  Widget _liveToggle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 0.7,
          child: Switch(
            value: listing.isActive,
            onChanged: (_) => onToggleActive?.call(),
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFFD1FAE5),
            inactiveThumbColor: const Color(0xFFF59E0B),
            inactiveTrackColor: const Color(0xFFFEF3C7),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Live',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: const Center(
        child: Icon(Icons.home_rounded, size: 48, color: Colors.white24),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: AppColors.textHint,
      ),
    );
  }

  Widget _expiryLabel(DateTime validUntil) {
    final days = validUntil.toUtc().difference(DateTime.now().toUtc()).inDays;
    final String label;
    final Color color;

    if (days > 3) {
      label = '$days days left';
      color = AppColors.textHint;
    } else if (days > 0) {
      label = '$days day${days == 1 ? '' : 's'} left';
      color = const Color(0xFFF59E0B);
    } else if (days == 0) {
      label = 'Expires today';
      color = AppColors.error;
    } else {
      label = 'Expired';
      color = AppColors.error;
    }

    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        color: color,
        fontWeight: FontWeight.w500,
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
