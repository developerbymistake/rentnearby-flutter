import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_shadows.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/report_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../models/browse_item.dart';
import '../../../services/listing_share_service.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/detail_action_bar.dart';
import '../../../widgets/detail_header.dart';
import '../../../widgets/report_listing_sheet.dart';
import '../models/stay_detail_model.dart';
import '../models/stay_owner_model.dart';
import '../../taxi/guest/stay_taxis_section.dart';
import '../setup/stay_option_sets.dart';
import 'stay_guest_controller.dart';

const _kAccent = StayColors.accent;
const _kGradient = StayColors.gradient;
const _kDivider = Padding(
  padding: EdgeInsets.symmetric(vertical: 10),
  child: Divider(height: 1, color: AppColors.divider),
);

class StayDetailScreen extends StatefulWidget {
  const StayDetailScreen({super.key});
  @override
  State<StayDetailScreen> createState() => _StayDetailScreenState();
}

class _StayDetailScreenState extends State<StayDetailScreen> {
  final _auth = Get.find<AuthController>();
  final _isSharing = false.obs;
  StayDetailModel? _stay;
  bool _loading = true;
  int _currentPhoto = 0;

  bool get _isOwner => _stay != null && _auth.user.value?.id == _stay!.userId;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    final id = args is Map ? args['id'] as String : args as String;
    StayGuestController.to.getById(id).then((s) {
      if (mounted) setState(() { _stay = s; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  String get _price => _stay?.minPricePerNight != null ? BrowseItem.inr(_stay!.minPricePerNight!) : 'On request';

  Future<void> _share(StayDetailModel s) async {
    _isSharing.value = true;
    try {
      await shareListing(
        context: context,
        type: 's',
        slug: s.slug!,
        photoUrl: s.photos.isNotEmpty ? s.photos.first : null,
        priceOrArea: 'From $_price/night',
        typeLabel: s.stayTypeName ?? 'Stay',
        locality: s.locality,
      );
    } finally {
      _isSharing.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Obx(() => AppLoadingOverlay(
            isLoading: _isSharing.value,
            message: 'Sharing...',
            indicatorColor: StayColors.accent,
            child: _loading ? _buildLoader() : _buildContent(),
          )),
      bottomNavigationBar: _loading || _stay == null ? null : _buildActionBar(),
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
                          Expanded(
                              child: Container(
                                  height: 28,
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))),
                          const SizedBox(width: 12),
                          Container(
                              width: 90,
                              height: 36,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
                        ]),
                        const SizedBox(height: 16),
                        Container(
                            height: 120,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
                        const SizedBox(height: 24),
                        Container(
                            height: 14, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 8),
                        Container(
                            height: 14,
                            width: 200,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
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
    if (_stay == null) return const Center(child: Text('Stay not found'));
    final s = _stay!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 380,
          pinned: true,
          backgroundColor: _kAccent,
          leading: GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          actions: [
            if (!_isOwner && s.slug != null)
              GestureDetector(
                onTap: () => _share(s),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.export_1, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text('Share',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: s.photos.isEmpty
                ? Container(
                    decoration: const BoxDecoration(gradient: _kGradient),
                    child: const Center(child: Icon(Iconsax.building_4, size: 80, color: Colors.white38)),
                  )
                : Stack(
                    children: [
                      PageView.builder(
                        itemCount: s.photos.length,
                        onPageChanged: (i) => setState(() => _currentPhoto = i),
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: s.photos[i],
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(color: AppColors.shimmerBase),
                          errorWidget: (ctx, url, err) => Container(
                            color: AppColors.shimmerBase,
                            child: const Icon(Icons.broken_image_rounded, size: 48, color: AppColors.textHint),
                          ),
                        ),
                      ),
                      if (s.photos.length > 1)
                        Positioned(
                          bottom: 16,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                                s.photos.length,
                                (i) => AnimatedContainer(
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
              DetailTitleRow(
                accent: _kAccent,
                tag: 'FOR STAY',
                icon: Iconsax.building_4,
                title: s.title,
                caption: 'FROM',
                value: _price,
                unit: s.minPricePerNight != null ? '/night' : '',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.premium(_kAccent, alpha: 0.06, blur: 12, offset: const Offset(0, 4)),
                ),
                child: Column(children: [
                  if (s.rooms.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Rooms',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < s.rooms.length; i++) ...[
                      if (i > 0) _kDivider,
                      _roomRow(s.rooms[i]),
                    ],
                    _kDivider,
                  ],
                  if (s.stayTypeName != null && s.stayTypeName!.isNotEmpty) ...[
                    _infoRow(Iconsax.building_4, 'Stay type', s.stayTypeName!),
                    _kDivider,
                  ],
                  if (s.vehicleAccess != null && s.vehicleAccess!.isNotEmpty) ...[
                    _infoRow(Iconsax.car, 'Vehicle access', StayOptionSets.labelOf(StayOptionSets.vehicleAccess, s.vehicleAccess)),
                    _kDivider,
                  ],
                  _infoRow(Iconsax.location, 'Location', s.locality.isEmpty ? '-' : s.locality),
                ]),
              ),
              if (s.taxiTarget case final to?)
                Obx(() => TabConfigController.to.isTaxiActive
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _sectionTitle('Getting there'),
                          const SizedBox(height: 8),
                          StayTaxisSection(
                            stayCityId: s.cityId,
                            stayCityName: s.placeName,
                            toLat: to.lat,
                            toLng: to.lng,
                          ),
                        ],
                      )
                    : const SizedBox.shrink()),
              if (s.facilities.isNotEmpty) ...[
                const SizedBox(height: 24),
                _sectionTitle('Facilities'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: s.facilities.map(_facilityChip).toList(),
                ),
              ],
              if (s.rules != null) ...[
                const SizedBox(height: 24),
                _sectionTitle('House rules'),
                const SizedBox(height: 8),
                _rulesCard(s.rules!),
              ],
              if (s.description != null && s.description!.isNotEmpty) ...[
                const SizedBox(height: 24),
                _sectionTitle('About this stay'),
                const SizedBox(height: 8),
                Text(s.description!,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium, height: 1.6)),
              ],
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Iconsax.clock, size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('Posted ${_timeAgo(s.createdAt)}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textHint)),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark));

  Widget _roomRow(StayRoomModel r) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(
              [
                '${StayOptionSets.guestsLabel(r.maxGuests)} guest${r.maxGuests == 1 ? '' : 's'}',
                StayOptionSets.labelOf(StayOptionSets.meals, r.meals),
              ]
                  .where((e) => e.isNotEmpty)
                  .join(' · '),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(BrowseItem.inr(r.pricePerNight),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold)),
          const Text('/night',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textLight)),
        ]),
      ],
    );
  }

  Widget _facilityChip(String f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
      ),
      child: Text(StayOptionSets.labelOf(StayOptionSets.facilities, f),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: StayColors.accentDark)),
    );
  }

  Widget _rulesCard(StayRulesModel r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.premium(_kAccent, alpha: 0.06, blur: 12, offset: const Offset(0, 4)),
      ),
      child: Column(children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _ruleTile(Iconsax.login, 'Check-in', StayOptionSets.time12(r.checkInTime))),
            const SizedBox(width: 8),
            Expanded(child: _ruleTile(Iconsax.logout, 'Check-out', StayOptionSets.time12(r.checkOutTime))),
          ]),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _ruleTile(Iconsax.pet, 'Pets', _yesNo(r.petsAllowed))),
            const SizedBox(width: 8),
            Expanded(
              child: _ruleTile(Iconsax.calendar_remove, 'Cancellation',
                  StayOptionSets.labelOf(StayOptionSets.cancellation, r.cancellationPolicy)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _ruleTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppColors.scaffoldBg, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: _kAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
            Text(value.isEmpty ? '-' : value,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ]),
        ),
      ]),
    );
  }

  static String _yesNo(bool v) => v ? 'Yes' : 'No';

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
    final s = _stay!;
    final reportCtrl = Get.find<ReportController>();
    return Obx(() {
      final reported = reportCtrl.reportedListingIds.contains(s.id) || s.hasReported;
      return DetailActionBar(
          latitude: s.latitude,
          longitude: s.longitude,
          ownerPhone: _isOwner ? null : s.ownerPhone,
          isOwner: _isOwner,
          onReport: reported ? null : () => ReportListingSheet.show(context, listingId: s.id, listingType: 'Stay', palette: StayColors.palette),
          onChat: _isOwner ? null : () => _openChat(s),
          palette: StayColors.palette,
        );
    });
  }

  Future<void> _openChat(StayDetailModel s) async {
    final conv = await Get.find<ChatController>().createOrGetConversation('Stay', s.id);
    if (conv == null) return;
    Get.toNamed(AppRoutes.chatConversation, arguments: {
      'conversationId': conv.id,
      'listingType': conv.listingType,
      'listingId': conv.listingId,
      'roomTypeId': conv.roomTypeId,
      'plotTypeId': conv.plotTypeId,
      'stayTypeId': conv.stayTypeId,
      'otherPartyId': conv.otherPartyId,
      'otherPartyName': conv.otherPartyName,
      'listingTitle': conv.listingTitle,
      'isOwner': conv.isOwner,
      'status': conv.status,
      'isBlockedByMe': conv.isBlockedByMe,
    });
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark)),
            ]),
          ),
        ],
      );
}
