import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/listing_controller.dart';
import '../models/listing_model.dart';

class ListingBottomSheet extends StatefulWidget {
  final String listingId;
  const ListingBottomSheet({super.key, required this.listingId});

  @override
  State<ListingBottomSheet> createState() => _ListingBottomSheetState();
}

class _ListingBottomSheetState extends State<ListingBottomSheet> {
  final _ctrl = Get.find<ListingController>();
  ListingModel? _listing;
  bool _loading = true;
  int _currentPhoto = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.getById(widget.listingId).then((l) {
      if (mounted) setState(() { _listing = l; _loading = false; });
    });
  }

  void _call() async {
    final phone = _listing?.ownerPhone;
    if (phone == null) return;
    final url = Uri.parse('tel:+91$phone');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _loading ? _buildLoader() : _buildContent(),
    );
  }

  Widget _buildLoader() => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );

  Widget _buildContent() {
    if (_listing == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('Room not found', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight))),
      );
    }
    final l = _listing!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
        ),
        // Photo carousel
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 190,
              child: l.photos.isEmpty
                  ? Container(
                      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                      child: const Center(child: Icon(Icons.home_rounded, size: 60, color: Colors.white38)),
                    )
                  : Stack(
                      children: [
                        PageView.builder(
                          itemCount: l.photos.length,
                          onPageChanged: (i) => setState(() => _currentPhoto = i),
                          itemBuilder: (_, i) => CachedNetworkImage(
                            imageUrl: l.photos[i],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, __) => Container(color: AppColors.surface),
                            errorWidget: (_, __, ___) => Container(
                              decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                              child: const Center(child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.white38)),
                            ),
                          ),
                        ),
                        // Photo count badge
                        if (l.photos.length > 1)
                          Positioned(
                            top: 10, right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                              child: Text('${_currentPhoto + 1}/${l.photos.length}',
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        // Dots
                        if (l.photos.length > 1)
                          Positioned(
                            bottom: 10, left: 0, right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(l.photos.length, (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _currentPhoto == i ? 18 : 6,
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
        ),
        const SizedBox(height: 16),
        // Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.title ?? 'Room for Rent',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (l.ownerName != null && l.ownerName!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(children: [
                            const Icon(Icons.person_rounded, size: 13, color: AppColors.primaryLight),
                            const SizedBox(width: 4),
                            Text(l.ownerName!,
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (l.priceMonthly != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        l.priceDisplay,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 6,
                children: [
                  if (l.roomTypeName != null) _tag(Icons.home_rounded, l.roomTypeName!),
                  if (l.districtName != null) _tag(Iconsax.location, l.districtName!),
                  if (l.cityName != null) _tag(Icons.place_outlined, l.cityName!),
                ],
              ),
              if (l.address != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Iconsax.location5, size: 14, color: AppColors.primaryLight),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.address!,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Get.toNamed(AppRoutes.listingDetail, arguments: l.id);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'View Details',
                        style: TextStyle(fontFamily: 'Poppins', color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _call,
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tag(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                )),
          ],
        ),
      );
}
