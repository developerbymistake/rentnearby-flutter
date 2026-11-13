import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_details.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/chat_controller.dart';
import '../../../controllers/report_controller.dart';
import '../../../controllers/tab_config_controller.dart';
import '../../../models/browse_item.dart';
import '../../../services/listing_share_service.dart';
import '../../../widgets/detail_action_bar.dart';
import '../../../widgets/report_listing_sheet.dart';
import '../models/stay_detail_model.dart';
import '../models/stay_owner_model.dart';
import '../../taxi/guest/stay_taxis_section.dart';
import '../../taxi/guest/taxi_detail_screen.dart' show DetailSharingOverlay;
import '../setup/stay_option_sets.dart';
import 'stay_guest_controller.dart';

final _kTone = ListingTone.forest;
final _kPage = ListingPalette.forest.page;
const _kSections = 7;

const _kFacilityLook = <String, (int, String)>{
  'HotWater': (4, ListingArt.hotSprings),
  'Heater': (0, ListingArt.hotSprings),
  'WiFi': (1, ListingArt.antenna),
  'Parking': (2, DetailArt.automobile),
  'HomeFood': (5, ListingArt.potOfFood),
  'MountainView': (3, ListingArt.mountain),
};

class StayDetailScreen extends StatefulWidget {
  const StayDetailScreen({super.key});
  @override
  State<StayDetailScreen> createState() => _StayDetailScreenState();
}

class _StayDetailScreenState extends State<StayDetailScreen> {
  Widget _sec(int i, Widget child) => StaggerItem(index: i, child: child);

  double _heroHeight(BuildContext context) => 252 + MediaQuery.paddingOf(context).top;

  final _auth = Get.find<AuthController>();
  final _isSharing = false.obs;
  StayDetailModel? _stay;
  bool _loading = true;
  int _currentPhoto = 0;
  final _scroll = ScrollController();
  final _barOn = ValueNotifier<bool>(false);

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final on = _scroll.offset > _heroHeight(context) - DetailTopBar.heightOf(context);
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
    return Stack(children: [
      Scaffold(
      backgroundColor: _kPage,
      body: Stack(children: [
        Column(children: [
          ValueListenableBuilder<bool>(
            valueListenable: _barOn,
            builder: (context, on, _) => ToastSlot(
              margin: EdgeInsets.fromLTRB(
                  18, !_loading && _stay != null && on ? DetailTopBar.heightOf(context) + 14 : MediaQuery.paddingOf(context).top + 64, 18, 0),
            ),
          ),
          Expanded(child: _loading ? _buildLoader() : _buildContent()),
        ]),
        if (!_loading && _stay != null) _topBar(_stay!) else _backAt(context, solid: _stay == null && !_loading),
      ]),
      bottomNavigationBar: _loading || _stay == null ? null : _buildActionBar(),
      ),
      Obx(() => _isSharing.value ? Positioned.fill(child: DetailSharingOverlay(tone: _kTone)) : const SizedBox.shrink()),
    ]);
  }

  Widget _backAt(BuildContext context, {bool solid = false}) => Positioned(
        top: MediaQuery.paddingOf(context).top + 10,
        left: 14,
        child: DetailGlassButton(onTap: () => Get.back(), solid: solid),
      );

  Widget _buildLoader() => KitStatusBar(
        lightIcons: false,
        child: Stack(children: [
          DetailSkeleton(heroHeight: _heroHeight(context)),
        ]),
      );

  Widget _buildContent() {
    if (_stay == null) {
      return KitStatusBar(
        lightIcons: false,
        child: Stack(children: [
          Positioned.fill(
            child: DetailStateView(
              tone: _kTone,
              art: ListingArt.hotel,
              title: 'Stay not found',
              actionLabel: 'Try again',
              onAction: _fetch,
            ),
          ),
        ]),
      );
    }
    final s = _stay!;
    return ValueListenableBuilder<bool>(
      valueListenable: _barOn,
      builder: (context, barOn, content) => KitStatusBar(lightIcons: !barOn, child: content!),
      child: StaggerHost(
        count: _kSections,
        child: _scrollView(s),
      ),
    );
  }

  Widget _topBar(StayDetailModel s) => Positioned(
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
          child: DetailTopBar(
            tone: _kTone,
            title: s.title,
            onBack: () => Get.back(),
            onShare: !_isOwner && s.slug != null ? () => _share(s) : null,
          ),
        ),
      );

  Widget _hero(StayDetailModel s) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: _heroHeight(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: s.photos.isEmpty
                ? DetailHeroArt(tone: _kTone, art: ListingArt.hotel)
                : PageView.builder(
                    itemCount: s.photos.length,
                    onPageChanged: (i) => setState(() => _currentPhoto = i),
                    itemBuilder: (_, i) => CachedNetworkImage(
                      imageUrl: s.photos[i],
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => const TemplatePlaceholder(height: double.infinity, radius: 0),
                      errorWidget: (ctx, url, err) => DetailHeroArt(tone: _kTone, art: ListingArt.hotel),
                    ),
                  ),
          ),
          if (s.photos.isNotEmpty) const Positioned(top: 0, left: 0, right: 0, child: DetailTopScrim()),
          if (s.photos.length > 1)
            Positioned(
              bottom: 42,
              left: 0,
              right: 0,
              child: IgnorePointer(child: DetailPhotoDots(count: s.photos.length, index: _currentPhoto)),
            ),
          Positioned(top: top + 10, left: 14, child: DetailGlassButton(onTap: () => Get.back())),
          if (!_isOwner && s.slug != null)
            Positioned(top: top + 10, right: 14, child: DetailSharePill(tone: _kTone, onTap: () => _share(s))),
          Positioned(left: 0, right: 0, bottom: -1, child: DetailEdge(page: _kPage)),
        ],
      ),
    );
  }

  Widget _scrollView(StayDetailModel s) {
    final rules = s.rules;
    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _hero(s),
            _sec(0, DetailTitleCard(
              tone: _kTone,
              eyebrow: 'FOR STAY',
              title: s.title,
              caption: 'FROM',
              value: _price,
              unit: s.minPricePerNight != null ? '/night' : null,
            )),
            _sec(1, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (s.rooms.isNotEmpty) ...[
                const TitleRow3D(title: 'Rooms'),
                for (var i = 0; i < s.rooms.length; i++) _roomCard(s.rooms[i], i),
              ],
              DetailInfoCard(tone: _kTone, rows: [
                if (s.stayTypeName != null && s.stayTypeName!.isNotEmpty) DetailInfo(ListingArt.hotel, 'Stay type', s.stayTypeName!),
                if (s.vehicleAccess != null && s.vehicleAccess!.isNotEmpty)
                  DetailInfo(DetailArt.automobile, 'Vehicle access', StayOptionSets.labelOf(StayOptionSets.vehicleAccess, s.vehicleAccess)),
                DetailInfo(ListingArt.roundPushpin, 'Location', s.locality.isEmpty ? '-' : s.locality),
              ]),
            ])),
            if (s.taxiTarget case final to?)
              Obx(() => TabConfigController.to.isTaxiActive
                  ? _sec(2, Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const TitleRow3D(title: 'Getting there'),
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
              _sec(3, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const TitleRow3D(title: 'Facilities'),
                DetailChipGrid(items: [for (var i = 0; i < s.facilities.length; i++) _facility(s.facilities[i], i)]),
              ])),
            if (rules != null)
              _sec(4, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const TitleRow3D(title: 'House rules'),
                DetailChipGrid(rules: true, items: [
                  DetailChipItem(tone: ListingTone.cE, art: ListingArt.key, label: 'Check-in', value: StayOptionSets.time12(rules.checkInTime)),
                  DetailChipItem(tone: ListingTone.cB, art: ListingArt.luggage, label: 'Check-out', value: StayOptionSets.time12(rules.checkOutTime)),
                  DetailChipItem(tone: ListingTone.cA, art: ListingArt.paw, label: 'Pets', value: _yesNo(rules.petsAllowed)),
                  DetailChipItem(
                    tone: ListingTone.cF,
                    art: ListingArt.clipboard,
                    label: 'Cancellation',
                    value: StayOptionSets.labelOf(StayOptionSets.cancellation, rules.cancellationPolicy),
                  ),
                ]),
              ])),
            if (s.description != null && s.description!.isNotEmpty)
              _sec(5, Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const TitleRow3D(title: 'About this stay'),
                DetailAboutCard(text: s.description!),
              ])),
            _sec(6, DetailPosted(text: 'Posted ${_timeAgo(s.createdAt)}')),
            const SizedBox(height: 28),
          ]),
        ),
      ],
    );
  }

  DetailChipItem _facility(String f, int i) {
    final look = _kFacilityLook[f];
    return DetailChipItem(
      tone: f == 'HotWater' ? ListingTone.teal : ListingTone.at(look?.$1 ?? i),
      art: look?.$2 ?? ListingArt.star,
      label: StayOptionSets.labelOf(StayOptionSets.facilities, f),
    );
  }

  Widget _roomCard(StayRoomModel r, int i) => DetailSlimCard(
        tone: ListingTone.list(_kTone, i),
        art: ListingArt.bed,
        title: r.label,
        subtitle: [
          '${StayOptionSets.guestsLabel(r.maxGuests)} guest${r.maxGuests == 1 ? '' : 's'}',
          StayOptionSets.labelOf(StayOptionSets.meals, r.meals),
        ].where((e) => e.isNotEmpty).join(' · '),
        price: BrowseItem.inr(r.pricePerNight),
        unit: '/night',
      );

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
}
