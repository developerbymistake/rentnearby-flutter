import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/chat_controller.dart';
import '../controllers/view_all_controller.dart';
import '../widgets/filter_sort_sheet.dart';
import '../widgets/listing_grid_card.dart';
import '../widgets/location_pill.dart';
import '../widgets/sliding_chip_toggle.dart';
import 'explore_location_search_mixin.dart';

const _kPlotGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF92400E), Color(0xFF78350F)],
);
const _kPlotColor = Color(0xFF92400E);

/// "View All" — pushed from Home's Rooms/Plots "View all" links. Reuses the
/// real gradient-header pushed-screen pattern (my_plots_screen.dart /
/// my_listings_screen.dart) rather than a hand-invented app bar, and the
/// real infinite-scroll pattern (ScrollController + threshold) from the
/// same files. Back is a plain Get.back() — the global GetX navigator
/// already returns to whichever tab was underneath, state intact.
class ViewAllScreen extends StatefulWidget {
  final ViewAllListingType listingType;
  const ViewAllScreen({super.key, required this.listingType});

  @override
  State<ViewAllScreen> createState() => _ViewAllScreenState();
}

class _ViewAllScreenState extends State<ViewAllScreen>
    with ExploreLocationSearchMixin<ViewAllScreen> {
  late final ViewAllController _ctrl;
  late final String _ctrlTag;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Route-scoped, not a permanent singleton — Get.put here (not in a
    // binding) so a fresh instance is created every time this screen is
    // pushed, and torn down with it via Get.delete in dispose().
    _ctrlTag = UniqueKey().toString();
    _ctrl = Get.put(ViewAllController(widget.listingType), tag: _ctrlTag);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    Get.delete<ViewAllController>(tag: _ctrlTag);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _ctrl.loadNextPage();
    }
  }

  void _openFilterSheet() {
    FilterSortSheet.show(context, controller: _ctrl);
  }

  void _viewDetails(ViewAllItem item) {
    if (_ctrl.activeType.value == ViewAllListingType.rooms) {
      Get.toNamed(AppRoutes.listingDetail, arguments: {'id': item.id});
    } else {
      Get.toNamed(AppRoutes.plotDetail, arguments: item.id);
    }
  }

  Future<void> _chat(ViewAllItem item) async {
    final isRooms = _ctrl.activeType.value == ViewAllListingType.rooms;
    final conv = await Get.find<ChatController>().createOrGetConversation(isRooms ? 'Room' : 'Plot', item.id);
    if (conv == null) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        final isRooms = _ctrl.activeType.value == ViewAllListingType.rooms;
        final gradient = isRooms ? AppColors.primaryGradient : _kPlotGradient;
        final activeColor = isRooms ? AppColors.primary : _kPlotColor;

        return Column(
          children: [
            Container(
              decoration: BoxDecoration(gradient: gradient),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 20, 10),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Get.back(),
                            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                          ),
                          Expanded(
                            child: Text(
                              isRooms ? 'Rooms near you' : 'Plots near you',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _openFilterSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune_rounded, size: 16, color: activeColor),
                                  const SizedBox(width: 4),
                                  Text('Filter', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: activeColor)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Row(children: [
                        Expanded(child: LocationPill(accentColor: activeColor)),
                        const SizedBox(width: 8),
                        _buildSearchToggleButton(activeColor),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SlidingChipToggle(
                selectedIndex: isRooms ? 0 : 1,
                onChanged: (i) => _ctrl.setType(i == 0 ? ViewAllListingType.rooms : ViewAllListingType.plots),
                options: [
                  ToggleOption(
                    label: 'Rooms',
                    icon: Icons.home_rounded,
                    activeColor: AppColors.primary,
                    gradient: AppColors.primaryGradient,
                  ),
                  ToggleOption(
                    label: 'Plots',
                    icon: Icons.landscape_rounded,
                    activeColor: _kPlotColor,
                    gradient: _kPlotGradient,
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: activeColor,
                onRefresh: () => _ctrl.loadPage(reset: true),
                child: Obx(() {
                  if (_ctrl.isLoading.value) {
                    return _buildGridShimmer();
                  }
                  final items = _ctrl.items;
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(
                          child: Text(
                            isRooms ? 'No rooms found' : 'No plots found',
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight),
                          ),
                        ),
                      ],
                    );
                  }
                  final hasMore = _ctrl.hasMore.value;
                  return GridView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 190,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: items.length + (hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= items.length) {
                        return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)));
                      }
                      final item = items[i];
                      return ListingGridCard(
                        thumbnailUrl: item.thumbnailUrl,
                        badgeLabel: item.badgeLabel,
                        priceLabel: item.priceLabel,
                        title: item.title,
                        locationLabel: item.locationLabel,
                        onViewDetails: () => _viewDetails(item),
                        onChat: () => _chat(item),
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        );
      }),
    );
  }

  // Mirrors explore_screen.dart's _buildSearchToggleButton() exactly — same
  // ExploreLocationSearchMixin, same cancel behavior — just takes the
  // screen's dynamic Rooms/Plots accentColor instead of a hardcoded one.
  Widget _buildSearchToggleButton(Color accentColor) {
    return Obx(() => GestureDetector(
      onTap: searchResolving ? null : () => onSearchToggleTap(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: searchResolving
            ? Padding(
                padding: const EdgeInsets.all(11),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: accentColor),
              )
            : Icon(
                isSearchActive ? Icons.close_rounded : Icons.search_rounded,
                color: accentColor,
                size: 20,
              ),
      ),
    ));
  }

  Widget _buildGridShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
