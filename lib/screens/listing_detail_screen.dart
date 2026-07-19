import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/listing_controller.dart';
import '../controllers/report_controller.dart';
import '../models/listing_model.dart';
import '../widgets/detail_action_bar.dart';
import '../widgets/report_listing_sheet.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key});
  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _ctrl = Get.find<ListingController>();
  final _auth = Get.find<AuthController>();
  ListingModel? _listing;
  bool _loading = true;
  int _currentPhoto = 0;
  double? _distanceKm;

  bool get _isOwner => _listing != null && _auth.user.value?.id == _listing!.userId;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final id = args is Map ? args['id'] as String : args as String;
    _distanceKm = args is Map ? (args['distanceKm'] as num?)?.toDouble() : null;
    _ctrl.getById(id).then((l) {
      if (mounted) setState(() { _listing = l; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Listing', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text('Are you sure? This will also delete all photos.', style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, foregroundColor: Colors.white,
              minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _ctrl.deleteListing(_listing!.id);
              Get.back();
            },
            child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  static IconData _roomTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'pg': return Icons.people_alt_rounded;
      case 'hostel': return Icons.hotel_rounded;
      case '1rk': return Icons.single_bed_rounded;
      default: return Icons.apartment_rounded;
    }
  }

  Widget _buildTitle(ListingModel l) {
    const fs = 22.0;
    return Row(children: [
      Icon(_roomTypeIcon(l.roomTypeName), size: fs, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(l.roomTypeName ?? 'Room',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: fs, fontWeight: FontWeight.w700, color: AppColors.textDark)),
    ]);
  }

  String _locationStr(ListingModel l) {
    final parts = [l.cityName, l.districtName]
        .where((s) => s != null && s.isNotEmpty)
        .cast<String>()
        .toList();
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: _loading ? _buildLoader() : _buildContent(),
      bottomNavigationBar: _loading || _listing == null ? null : _buildActionBar(),
    );
  }

  Widget _buildLoader() => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
    child: Stack(
    children: [
      Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 380 + MediaQuery.of(context).padding.top, color: Colors.white),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Container(height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))),
                    const SizedBox(width: 12),
                    Container(width: 90, height: 36, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
                  ]),
                  const SizedBox(height: 16),
                  Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                  const SizedBox(height: 24),
                  Container(height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                ]),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        child: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
        ),
      ),
    ],
    ),
  );

  Widget _buildContent() {
    if (_listing == null) return const Center(child: Text('Room not found'));
    final l = _listing!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 380,
          pinned: true,
          backgroundColor: AppColors.primary,
          leading: GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          actions: _isOwner ? [
            GestureDetector(
              onTap: _confirmDelete,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                child: const Icon(Icons.delete_rounded, color: Colors.white, size: 20),
              ),
            ),
          ] : null,
          flexibleSpace: FlexibleSpaceBar(
            background: l.photos.isEmpty
                ? Container(
                    decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                    child: const Center(child: Icon(Icons.home_rounded, size: 80, color: Colors.white38)),
                  )
                : Stack(
                    children: [
                      PageView.builder(
                        itemCount: l.photos.length,
                        onPageChanged: (i) => setState(() => _currentPhoto = i),
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: l.photos[i],
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(color: AppColors.surface),
                          errorWidget: (ctx, url, err) => Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.broken_image_rounded, size: 48, color: AppColors.textHint),
                          ),
                        ),
                      ),
                      if (l.photos.length > 1)
                        Positioned(
                          bottom: 16, left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(l.photos.length, (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _currentPhoto == i ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _currentPhoto == i ? Colors.white : Colors.white54,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            )),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title + price
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: _buildTitle(l),
                ),
                const SizedBox(width: 12),
                if (l.priceMonthly != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                    child: Text(l.priceDisplay,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
              ]),
              const SizedBox(height: 16),

              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(children: [
                  // Furnished + distance row
                  Row(children: [
                    if (l.furnishedStatus != 'None')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Iconsax.home_hashtag, size: 13, color: Color(0xFF8B5CF6)),
                          const SizedBox(width: 5),
                          Text('${l.furnishedStatus} Furnished',
                              style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 12,
                                  fontWeight: FontWeight.w500, color: Color(0xFF8B5CF6))),
                        ]),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.textHint.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Iconsax.home_hashtag, size: 13, color: AppColors.textHint),
                          const SizedBox(width: 5),
                          const Text('Unfurnished',
                              style: TextStyle(
                                  fontFamily: 'Poppins', fontSize: 12,
                                  fontWeight: FontWeight.w500, color: AppColors.textHint)),
                        ]),
                      ),
                    const Spacer(),
                    if (_distanceKm != null) ...[
                      const Icon(Iconsax.location, size: 13, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text('${_distanceKm!.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                    ],
                  ]),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: AppColors.divider),
                  ),
                  // Owner row
                  if (l.ownerName != null && l.ownerName!.isNotEmpty) ...[
                    _infoRow(Icons.person_rounded, 'Owner', l.ownerName!),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                  ],
                  // Location row (city + district combined)
                  if (_locationStr(l).isNotEmpty)
                    _infoRow(Iconsax.location, 'Location', _locationStr(l)),
                  // Address row
                  if (l.address != null && l.address!.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                    _infoRow(Iconsax.location5, 'Address', l.address!),
                  ],
                ]),
              ),

              // Description
              if (l.description != null && l.description!.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('About this room',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 8),
                Text(l.description!,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium, height: 1.6)),
              ],

              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('Posted ${_timeAgo(l.createdAt)}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint)),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }

  Widget _buildActionBar() {
    final l = _listing!;
    final reportCtrl = Get.find<ReportController>();
    return Obx(() => DetailActionBar(
          latitude: l.latitude,
          longitude: l.longitude,
          ownerPhone: l.ownerPhone,
          isOwner: _isOwner,
          onReport: (l.hasReported || reportCtrl.reportedListingIds.contains(l.id))
              ? null
              : () => ReportListingSheet.show(context, listingId: l.id, listingType: 'Room'),
          onChat: _isOwner ? null : () => _openChat(l),
        ));
  }

  Future<void> _openChat(ListingModel l) async {
    final conv = await Get.find<ChatController>().createOrGetConversation('Room', l.id);
    if (conv == null) return; // controller already showed the specific error toast
    Get.toNamed(AppRoutes.chatConversation, arguments: {
      'conversationId': conv.id,
      'listingType': conv.listingType,
      'listingId': conv.listingId,
      'roomTypeId': conv.roomTypeId,
      'plotTypeId': conv.plotTypeId,
      'otherPartyId': conv.otherPartyId,
      'otherPartyName': conv.otherPartyName,
      'listingTitle': conv.listingTitle,
      'isOwner': conv.isOwner,
      'status': conv.status,
      'isBlockedByMe': conv.isBlockedByMe,
    });
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor, Color? iconColor}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor ?? AppColors.primaryLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? AppColors.textDark,
                  )),
            ]),
          ),
        ],
      );
}
