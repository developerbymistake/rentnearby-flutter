import 'package:bakhli/design/design.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/report_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../models/browse_item.dart';
import '../../../services/listing_share_service.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/detail_action_bar.dart';
import '../../../widgets/report_listing_sheet.dart';
import '../models/stay_detail_model.dart';
import '../models/stay_owner_model.dart';
import '../../taxi/guest/stay_taxis_section.dart';
import '../setup/stay_option_sets.dart';
import 'stay_guest_controller.dart';

const _kAccent = DesignColors.primary;
const _kTone = KitTone.stay;
const _kDivider = Padding(
  padding: EdgeInsets.symmetric(vertical: 10),
  child: Divider(height: 1, color: DesignColors.dividerSoft),
);
const _kSections = 7;

TextStyle _t(double size, FontWeight w, Color c, {double? height, double? spacing}) =>
    TypeTokens.style(size, w, color: c, height: height, letterSpacing: spacing);

class StayDetailScreen extends StatefulWidget {
  const StayDetailScreen({super.key});
  @override
  State<StayDetailScreen> createState() => _StayDetailScreenState();
}

class _StayDetailScreenState extends State<StayDetailScreen> {
  Widget _sec(int i, Widget child) => StaggerItem(index: i, child: child);

  Widget _glass({required Widget child, EdgeInsetsGeometry? margin, VoidCallback? onTap, EdgeInsetsGeometry? padding, bool pill = false}) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: PressScale(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: padding ?? const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: StayBrowseTokens.glass,
              shape: pill ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: pill ? CardRadius.pill : null,
              boxShadow: ShadowTokens.elev2,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  final _auth = Get.find<AuthController>();
  final _isSharing = false.obs;
  StayDetailModel? _stay;
  bool _loading = true;
  int _currentPhoto = 0;
  static const double _heroHeight = 380;
  final _scroll = ScrollController();
  final _barOn = ValueNotifier<bool>(false);

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final on = _scroll.offset > _heroHeight - ScrollFadeTopBar.heightOf(context);
    if (on != _barOn.value) _barOn.value = on;
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _barOn.dispose();
    super.dispose();
  }

  bool get _isOwner => _stay != null && _auth.user.value?.id == _stay!.userId;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    _id = args is Map ? args['id'] as String : args as String;
    _scroll.addListener(_onScroll);
    _fetch();
  }

  late final String _id;

  void _fetch() {
    if (!_loading) setState(() => _loading = true);
    StayGuestController.to.getById(_id).then((s) {
      if (mounted) {
        setState(() { _stay = s; _loading = false; });
      }
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
      backgroundColor: DesignColors.scaffold,
      body: Obx(() => AppLoadingOverlay(
            isLoading: _isSharing.value,
            message: 'Sharing...',
            indicatorColor: _kAccent,
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
            SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TemplatePlaceholder(height: 380 + MediaQuery.of(context).padding.top, radius: 0),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: TemplatePlaceholder(height: 28, radius: 8)),
                        SizedBox(width: 12),
                        TemplatePlaceholder(width: 90, height: 36, radius: 8),
                      ]),
                      SizedBox(height: 16),
                      TemplatePlaceholder(height: 120, radius: 12),
                      SizedBox(height: 24),
                      TemplatePlaceholder(height: 14, radius: 4),
                      SizedBox(height: 8),
                      TemplatePlaceholder(height: 14, width: 200, radius: 4),
                    ]),
                  ),
                ],
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: _glass(
                onTap: () => Get.back(),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignColors.textStrong, size: 16),
              ),
            ),
          ],
        ),
      );

  Widget _buildContent() {
    if (_stay == null) {
      return SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: DesignColors.textStrong),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: StateCard.error(
                    kit: _kTone,
                    title: 'Stay not found',
                    actionLabel: 'Try again',
                    onAction: _fetch,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final s = _stay!;
    return ValueListenableBuilder<bool>(
      valueListenable: _barOn,
      builder: (context, barOn, content) => KitStatusBar(lightIcons: !barOn, child: content!),
      child: Stack(
        children: [
          StaggerHost(
            count: _kSections,
            child: _scrollView(s),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _barOn,
              builder: (context, on, bar) => IgnorePointer(
                ignoring: !on,
                child: AnimatedOpacity(
                  opacity: on ? 1 : 0,
                  duration: KitMotion.reduce(context) ? Duration.zero : templateTransitionReverseDuration,
                  child: bar,
                ),
              ),
              child: ScrollFadeTopBar(
                title: s.title,
                scrollController: _scroll,
                onBack: () => Get.back(),
                trailing: [
                  if (!_isOwner && s.slug != null)
                    PressScale(
                      child: InkWell(
                        borderRadius: CardRadius.pill,
                        onTap: () => _share(s),
                        child: const SizedBox(
                          width: KitMetrics.touch,
                          height: KitMetrics.touch,
                          child: Icon(Icons.ios_share_rounded, color: _kAccent, size: 20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrollView(StayDetailModel s) {
    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: _heroHeight,
          pinned: false,
          backgroundColor: _kAccent,
          leading: _glass(
            onTap: () => Get.back(),
            margin: const EdgeInsets.all(8),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: DesignColors.textStrong, size: 16),
          ),
          actions: [
            if (!_isOwner && s.slug != null)
              _glass(
                onTap: () => _share(s),
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                pill: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.ios_share_rounded, color: _kAccent, size: 16),
                    const SizedBox(width: 6),
                    Text('Share', style: _t(13, FontWeight.w600, _kAccent)),
                  ],
                ),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                s.photos.isEmpty
                    ? const PlaceholderTile(tone: _kTone, iconSize: 80)
                    : Stack(
                        children: [
                          PageView.builder(
                            itemCount: s.photos.length,
                            onPageChanged: (i) => setState(() => _currentPhoto = i),
                            itemBuilder: (_, i) => CachedNetworkImage(
                              imageUrl: s.photos[i],
                              fit: BoxFit.cover,
                              placeholder: (ctx, url) => const TemplatePlaceholder(height: double.infinity, radius: 0),
                              errorWidget: (ctx, url, err) =>
                                  const PlaceholderTile(tone: _kTone, asset: TravelIcon.photo, iconSize: 48),
                            ),
                          ),
                          if (s.photos.length > 1)
                            Positioned(
                              bottom: 36,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
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
                                              color: _currentPhoto == i
                                                  ? DesignColors.onPrimary
                                                  : StayBrowseTokens.dotInactive,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                          )),
                                ),
                              ),
                            ),
                        ],
                      ),
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 120,
                  child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: DesignGradients.scrimTop))),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -1,
                  child: IgnorePointer(
                    child: Container(
                      height: 24,
                      decoration: const BoxDecoration(
                        color: DesignColors.scaffold,
                        borderRadius: CardRadius.sheet,
                      ),
                    ),
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
              _sec(0, _titleRow(s)),
              const SizedBox(height: 16),
              _sec(1, SectionTile(
                tone: _kTone,
                child: Column(children: [
                  if (s.rooms.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Rooms', style: _t(16, FontWeight.w700, DesignColors.textStrong)),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < s.rooms.length; i++) ...[
                      if (i > 0) _kDivider,
                      _roomRow(s.rooms[i]),
                    ],
                    _kDivider,
                  ],
                  if (s.stayTypeName != null && s.stayTypeName!.isNotEmpty) ...[
                    _infoRow(TravelIcon.stay, TravelPalette.skyStart, TravelPalette.skyEnd, 'Stay type', s.stayTypeName!),
                    _kDivider,
                  ],
                  if (s.vehicleAccess != null && s.vehicleAccess!.isNotEmpty) ...[
                    _infoRow(TravelIcon.taxi, TravelPalette.sunriseStart, TravelPalette.sunriseEnd, 'Vehicle access', StayOptionSets.labelOf(StayOptionSets.vehicleAccess, s.vehicleAccess)),
                    _kDivider,
                  ],
                  _infoRow(TravelIcon.place, TravelPalette.roseStart, TravelPalette.roseEnd, 'Location', s.locality.isEmpty ? '-' : s.locality),
                ]),
              )),
              if (s.taxiTarget case final to?)
                Obx(() => TabConfigController.to.isTaxiActive
                    ? _sec(2, Column(
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
                      ))
                    : const SizedBox.shrink()),
              if (s.facilities.isNotEmpty)
                _sec(3, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 24),
                  _sectionTitle('Facilities'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: s.facilities.map(_facilityChip).toList(),
                  ),
                ])),
              if (s.rules != null)
                _sec(4, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 24),
                  _sectionTitle('House rules'),
                  const SizedBox(height: 8),
                  _rulesCard(s.rules!),
                ])),
              if (s.description != null && s.description!.isNotEmpty)
                _sec(5, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 24),
                  _sectionTitle('About this stay'),
                  const SizedBox(height: 8),
                  Text(s.description!, style: _t(14, FontWeight.w400, TypeTokens.secondary, height: 1.6)),
                ])),
              const SizedBox(height: 16),
              _sec(6, Row(children: [
                const TravelIcon(TravelIcon.calendar, size: 16),
                const SizedBox(width: 4),
                Text('Posted ${_timeAgo(s.createdAt)}', style: _t(12, FontWeight.w400, TypeTokens.secondary)),
              ])),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: _t(16, FontWeight.w700, DesignColors.textStrong, spacing: 0.18));

  Widget _titleRow(StayDetailModel s) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const TravelIcon(TravelIcon.stay, size: 14),
              const SizedBox(width: 4),
              Text('FOR STAY', style: _t(10, FontWeight.w500, _kTone.accentDark, spacing: 0.2)),
            ]),
            const SizedBox(height: 4),
            Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _t(22, FontWeight.w600, DesignColors.textStrong, spacing: 0.27)),
          ]),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('FROM', style: _t(10, FontWeight.w500, TypeTokens.secondary, spacing: 0.2)),
          Text(_price, style: _t(22, FontWeight.w500, _kAccent)),
          if (s.minPricePerNight != null) Text('/night', style: _t(12, FontWeight.w400, TypeTokens.secondary)),
        ]),
      ],
    );
  }

  Widget _roomRow(StayRoomModel r) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _t(14, FontWeight.w500, DesignColors.textStrong)),
            const SizedBox(height: 2),
            Text(
              [
                '${StayOptionSets.guestsLabel(r.maxGuests)} guest${r.maxGuests == 1 ? '' : 's'}',
                StayOptionSets.labelOf(StayOptionSets.meals, r.meals),
              ]
                  .where((e) => e.isNotEmpty)
                  .join(' · '),
              style: _t(12, FontWeight.w400, TypeTokens.secondary),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(BrowseItem.inr(r.pricePerNight),
              style: _t(16, FontWeight.w600, PickKit.gold)),
          Text('/night', style: _t(12, FontWeight.w400, TypeTokens.secondary)),
        ]),
      ],
    );
  }

  Widget _facilityChip(String f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: _kTone.tint, borderRadius: CardRadius.pill),
      child: Text(StayOptionSets.labelOf(StayOptionSets.facilities, f), style: _t(12, FontWeight.w500, _kAccent)),
    );
  }

  Widget _rulesCard(StayRulesModel r) {
    return SectionTile(
      tone: _kTone,
      child: Column(children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _ruleTile(const Icon(Icons.login_rounded, size: 20, color: _kAccent), 'Check-in', StayOptionSets.time12(r.checkInTime))),
            const SizedBox(width: 8),
            Expanded(child: _ruleTile(const Icon(Icons.logout_rounded, size: 20, color: _kAccent), 'Check-out', StayOptionSets.time12(r.checkOutTime))),
          ]),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _ruleTile(const Icon(Icons.pets_rounded, size: 18, color: _kAccent), 'Pets', _yesNo(r.petsAllowed))),
            const SizedBox(width: 8),
            Expanded(
              child: _ruleTile(const TravelIcon(TravelIcon.note, size: 20), 'Cancellation',
                  StayOptionSets.labelOf(StayOptionSets.cancellation, r.cancellationPolicy)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _ruleTile(Widget icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DesignColors.scaffold,
        borderRadius: KitMetrics.tileSmall,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        icon,
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: _t(11, FontWeight.w400, TypeTokens.secondary)),
            Text(value.isEmpty ? '-' : value, style: _t(13, FontWeight.w600, DesignColors.textStrong)),
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
          onReport: reported ? null : () => ReportListingSheet.show(context, listingId: s.id, listingType: 'Stay', palette: templateModulePalette),
          onChat: _isOwner ? null : () => _openChat(s),
          palette: templateModulePalette,
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
      'stayTypeId': conv.stayTypeId,
      'otherPartyId': conv.otherPartyId,
      'otherPartyName': conv.otherPartyName,
      'listingTitle': conv.listingTitle,
      'isOwner': conv.isOwner,
      'status': conv.status,
      'isBlockedByMe': conv.isBlockedByMe,
    });
  }

  Widget _infoRow(String icon, Color start, Color end, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [start, end], begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
            ),
            child: TravelIcon(icon, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: _t(11, FontWeight.w500, TypeTokens.secondary)),
              const SizedBox(height: 2),
              Text(value, style: _t(14, FontWeight.w500, DesignColors.textStrong)),
            ]),
          ),
        ],
      );
}
