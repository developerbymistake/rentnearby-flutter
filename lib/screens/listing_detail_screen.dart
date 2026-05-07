import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../controllers/listing_controller.dart';
import '../models/listing_model.dart';

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

  bool get _isOwner => _listing != null && _auth.user.value?.id == _listing!.userId;

  @override
  void initState() {
    super.initState();
    final id = Get.arguments as String;
    _ctrl.getById(id).then((l) => setState(() { _listing = l; _loading = false; }));
  }

  void _call() async {
    final phone = _listing?.ownerPhone;
    if (phone == null) return;
    final url = Uri.parse('tel:+91$phone');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
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

  void _checkDistance() async {
    final l = _listing;
    if (l == null) return;
    final geoUrl = Uri.parse('geo:${l.latitude},${l.longitude}?q=${l.latitude},${l.longitude}');
    if (await canLaunchUrl(geoUrl)) {
      launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      return;
    }
    final mapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${l.latitude},${l.longitude}&travelmode=driving',
    );
    launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: _loading ? _buildLoader() : _buildContent(),
      bottomNavigationBar: _loading || _listing == null ? null : _buildWhatsAppBar(),
    );
  }

  Widget _buildLoader() => const Center(child: CircularProgressIndicator(color: AppColors.primary));

  Widget _buildContent() {
    if (_listing == null) return const Center(child: Text('Room not found'));
    final l = _listing!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppColors.primary,
          leading: GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          actions: _isOwner ? [
            GestureDetector(
              onTap: _confirmDelete,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
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
                          placeholder: (_, __) => Container(color: AppColors.surface),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.surface,
                            child: const Icon(Icons.broken_image_rounded, size: 48, color: AppColors.textHint),
                          ),
                        ),
                      ),
                      // Photo dots
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
                  child: Text(l.title ?? 'Room for Rent',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (l.priceMonthly != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                      child: Text(l.priceDisplay,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  if (l.pricePerDay != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('₹${l.pricePerDay}/day',
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                    ),
                ]),
              ]),
              if (l.ownerName != null && l.ownerName!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.person_rounded, size: 14, color: AppColors.primaryLight),
                  const SizedBox(width: 6),
                  Text(l.ownerName!,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textLight)),
                ]),
              ],
              const SizedBox(height: 16),
              // Tags
              Wrap(spacing: 8, runSpacing: 8, children: [
                _tag(Icons.home_rounded, l.roomTypeName ?? 'Room'),
                if (l.districtName != null) _tag(Iconsax.location, l.districtName!),
                if (l.cityName != null) _tag(Icons.place_outlined, l.cityName!),
                _tag(l.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    l.isActive ? 'Available' : 'Not Available',
                    color: l.isActive ? AppColors.success : AppColors.error),
              ]),
              if (l.address != null) ...[
                const SizedBox(height: 20),
                _infoRow(Iconsax.location5, 'Address', l.address!),
              ],
              if (l.description != null && l.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('About this room', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                const SizedBox(height: 8),
                Text(l.description!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textMedium, height: 1.6)),
              ],
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsAppBar() => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _checkDistance,
              icon: const Icon(Icons.near_me_rounded, size: 20),
              label: const Text('Distance',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _call,
              icon: const Icon(Icons.call_rounded, size: 20),
              label: const Text('Call Owner',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ]),
      );

  Widget _tag(IconData icon, String label, {Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color ?? AppColors.primary),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: color ?? AppColors.primary)),
        ]),
      );

  Widget _infoRow(IconData icon, String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
            Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark)),
          ])),
        ],
      );
}
