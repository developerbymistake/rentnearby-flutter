import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../models/listing_model.dart';

class ListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleActive;
  final VoidCallback? onGoLive;

  const ListingCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onDelete,
    this.onToggleActive,
    this.onGoLive,
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
            _buildPhotoSection(),
            _buildContentSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
    final isLive = listing.isActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLive
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        ),
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
            isLive ? 'LIVE' : 'OFFLINE',
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
          const SizedBox(height: 5),
          // Location + expiry (opposite sides)
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
              if (listing.validUntil != null) ...[
                const SizedBox(width: 8),
                _expiryLabel(listing.validUntil!),
              ],
            ],
          ),
          if (listing.address != null && listing.address!.isNotEmpty) ...[
            const SizedBox(height: 2),
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
          if (onDelete != null || onToggleActive != null || onGoLive != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            _buildActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        if (!listing.isActive && onGoLive != null)
          _makeItLiveButton()
        else if (listing.isActive && onToggleActive != null)
          _liveToggle(),
        const Spacer(),
        if (onDelete != null) _deleteButton(),
      ],
    );
  }

  Widget _deleteButton() {
    return GestureDetector(
      onTap: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.trash, size: 14, color: AppColors.error),
            SizedBox(width: 5),
            Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _makeItLiveButton() {
    return GestureDetector(
      onTap: onGoLive,
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
        child: const Row(
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
    );
  }

  Widget _liveToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Live',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 4),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: listing.isActive,
            onChanged: (_) => onToggleActive?.call(),
            activeColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFFD1FAE5),
            inactiveThumbColor: const Color(0xFFF59E0B),
            inactiveTrackColor: const Color(0xFFFEF3C7),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
