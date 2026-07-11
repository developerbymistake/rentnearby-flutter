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
import '../controllers/plot_controller.dart';
import '../controllers/report_controller.dart';
import '../models/plot_model.dart';
import '../utils/app_toast.dart';
import '../widgets/detail_action_bar.dart';
import '../widgets/report_listing_sheet.dart';

class PlotDetailScreen extends StatefulWidget {
  const PlotDetailScreen({super.key});
  @override
  State<PlotDetailScreen> createState() => _PlotDetailScreenState();
}

class _PlotDetailScreenState extends State<PlotDetailScreen> {
  final _ctrl = Get.find<PlotController>();
  final _auth = Get.find<AuthController>();
  PlotModel? _plot;
  bool _loading = true;
  int _currentPhoto = 0;

  bool get _isOwner => _plot != null && _auth.user.value?.id == _plot!.userId;

  @override
  void initState() {
    super.initState();
    final id = Get.arguments as String;
    _ctrl.getById(id).then((p) {
      if (mounted) setState(() { _plot = p; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Plot', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
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
              _ctrl.deletePlot(_plot!.id);
              Get.back();
            },
            child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  static IconData _plotTypeIcon(String type) => switch (type) {
    'Residential' => Icons.home_rounded,
    'Commercial'  => Icons.store_rounded,
    'Agricultural'=> Icons.grass_rounded,
    'Farmhouse'   => Icons.cottage_rounded,
    _             => Icons.landscape_rounded,
  };

  Widget _buildTitle(PlotModel p) => Row(children: [
    Icon(_plotTypeIcon(p.plotType), size: 22, color: const Color(0xFF92400E)),
    const SizedBox(width: 8),
    Flexible(
      child: Text(
        p.plotType,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark),
      ),
    ),
  ]);

  String _locationStr(PlotModel p) {
    final parts = [p.cityName, p.districtName]
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
      bottomNavigationBar: _loading || _plot == null ? null : _buildActionBar(),
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
    if (_plot == null) return const Center(child: Text('Plot not found', style: TextStyle(fontFamily: 'Poppins')));
    final p = _plot!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 380,
          pinned: true,
          backgroundColor: const Color(0xFF92400E),
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
            background: p.photos.isEmpty
                ? Container(
                    color: const Color(0xFF92400E),
                    child: const Center(child: Icon(Icons.landscape_rounded, size: 80, color: Colors.white38)),
                  )
                : Stack(
                    children: [
                      PageView.builder(
                        itemCount: p.photos.length,
                        onPageChanged: (i) => setState(() => _currentPhoto = i),
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: p.photos[i],
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(color: AppColors.surface),
                          errorWidget: (ctx, url, err) => Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.broken_image_rounded, size: 48, color: AppColors.textHint),
                          ),
                        ),
                      ),
                      if (p.photos.length > 1)
                        Positioned(
                          bottom: 16, left: 0, right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(p.photos.length, (i) => AnimatedContainer(
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
              // Title + area chip
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _buildTitle(p)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF92400E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(p.areaDisplay,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
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
                  if (p.ownerName != null && p.ownerName!.isNotEmpty) ...[
                    _infoRow(Icons.person_rounded, 'Owner', p.ownerName!),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                  ],
                  if (_locationStr(p).isNotEmpty)
                    _infoRow(Iconsax.location, 'Location', _locationStr(p)),
                  if (p.address != null && p.address!.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                    _infoRow(Iconsax.location5, 'Address', p.address!),
                  ],
                ]),
              ),

              // Description
              if (p.description != null && p.description!.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('About this plot',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 8),
                Text(p.description!,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium, height: 1.6)),
              ],

              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.access_time_rounded, size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('Posted ${_timeAgo(p.createdAt)}',
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
    final p = _plot!;
    final reportCtrl = Get.find<ReportController>();
    return Obx(() => DetailActionBar(
          latitude: p.latitude,
          longitude: p.longitude,
          ownerPhone: p.ownerPhone,
          isOwner: _isOwner,
          onReport: (p.hasReported || reportCtrl.reportedListingIds.contains(p.id))
              ? null
              : () => ReportListingSheet.show(context, listingId: p.id, listingType: 'Plot'),
          onChat: _isOwner ? null : () => _openChat(p),
        ));
  }

  Future<void> _openChat(PlotModel p) async {
    final conv = await Get.find<ChatController>().createOrGetConversation('Plot', p.id);
    if (conv == null) {
      AppToast.error('Could not start chat. Please try again.');
      return;
    }
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
