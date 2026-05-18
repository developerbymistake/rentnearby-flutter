import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../controllers/auth_controller.dart';
import '../controllers/plot_controller.dart';
import '../models/plot_model.dart';
import '../utils/app_toast.dart';

const _kGreen = Color(0xFF10B981);
const _kGreenDark = Color(0xFF059669);

class MyPlotsScreen extends StatefulWidget {
  const MyPlotsScreen({super.key});
  @override
  State<MyPlotsScreen> createState() => _MyPlotsScreenState();
}

class _MyPlotsScreenState extends State<MyPlotsScreen> {
  final _ctrl = Get.find<PlotController>();
  final _auth = Get.find<AuthController>();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl.loadMyPlots(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      _ctrl.loadNextPage();
    }
  }

  Future<void> _refresh() => _ctrl.loadMyPlots(reset: true);

  void _onAddPlot() {
    final name = _auth.user.value?.name?.trim() ?? '';
    if (name.isEmpty) {
      _showNameDialog();
      return;
    }
    Get.toNamed(AppRoutes.addPlot);
  }

  void _showNameDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(builder: (ctx, setDialogState) {
        bool saving = false;
        Future<void> save() async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) { AppToast.error('Please enter your name.'); return; }
          setDialogState(() => saving = true);
          final ok = await _auth.updateProfile(name, null);
          setDialogState(() => saving = false);
          if (ok && ctx.mounted) {
            Navigator.pop(ctx);
            Get.toNamed(AppRoutes.addPlot);
          }
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Enter Your Name',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.textDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your name is shown to interested buyers. Please add it before listing.',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textMedium)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Full name',
                  hintStyle: const TextStyle(fontFamily: 'Poppins', color: AppColors.textHint),
                  prefixIcon: const Icon(Icons.person_rounded, color: _kGreen, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kGreen, width: 1.5)),
                ),
                onSubmitted: (_) => save(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () { nameCtrl.dispose(); Navigator.pop(ctx); },
              child: const Text('Later', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            ),
          ],
        );
      }),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Plot', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: const Text('Are you sure? This will also delete all photos.',
            style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textLight))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () { Navigator.pop(context); _ctrl.deletePlot(id); },
            child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Obx(() {
              final loading = _ctrl.isLoading.value;
              final plots = _ctrl.myPlots;
              final hasMore = _ctrl.hasMorePlots.value;

              if (loading && plots.isEmpty) return _buildShimmer();
              if (plots.isEmpty) return _buildEmpty();

              return RefreshIndicator(
                color: _kGreen,
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: plots.length + (hasMore || loading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == plots.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen)),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PlotCard(
                        plot: plots[i],
                        onToggleActive: () => _ctrl.toggleActive(plots[i].id, plots[i].isActive),
                        onDelete: () => _confirmDelete(plots[i].id),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kGreen, _kGreenDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Row(
              children: [
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('My Plots',
                      style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Manage your land listings',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
                ]),
                const Spacer(),
                GestureDetector(
                  onTap: _onAddPlot,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: _kGreen),
                        SizedBox(width: 4),
                        Text('Add Plot',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: _kGreen)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Iconsax.map, size: 40, color: _kGreen),
          ),
          const SizedBox(height: 20),
          const Text('No plots yet',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('Add your first plot listing',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
        ]),
      );

  Widget _buildShimmer() => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}

class _PlotCard extends StatelessWidget {
  final PlotModel plot;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _PlotCard({required this.plot, required this.onToggleActive, required this.onDelete});

  Color _typeColor(String type) => switch (type) {
    'Commercial'   => const Color(0xFFF59E0B),
    'Agricultural' => const Color(0xFF10B981),
    _              => const Color(0xFF3B82F6),
  };

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(plot.plotType);
    final location = [plot.cityName, plot.districtName].whereType<String>().join(', ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Thumbnail strip (or gradient placeholder)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 100,
              width: double.infinity,
              child: plot.photos.isNotEmpty
                  ? Image.network(plot.photos.first, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
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
                          Text(plot.areaDisplay,
                              style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          Text(plot.sqftLabel,
                              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: typeColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(plot.plotType,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: typeColor)),
                    ),
                  ],
                ),

                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 13, color: AppColors.textLight),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(location,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],

                if (plot.address != null && plot.address!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(plot.address!,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                Row(
                  children: [
                    // Active toggle
                    Row(
                      children: [
                        Switch(
                          value: plot.isActive,
                          onChanged: (_) => onToggleActive(),
                          activeColor: _kGreen,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 4),
                        Text(plot.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: plot.isActive ? _kGreen : AppColors.textLight)),
                      ],
                    ),
                    const Spacer(),
                    // Delete button
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error),
                            const SizedBox(width: 4),
                            Text('Delete',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(child: Icon(Icons.terrain_rounded, size: 40, color: Colors.white54)),
      );
}
