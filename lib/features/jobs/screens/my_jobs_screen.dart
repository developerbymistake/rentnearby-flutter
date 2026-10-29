import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/gradient_button.dart';
import '../../stay/setup/stay_option_sets.dart';
import '../controllers/my_jobs_controller.dart';
import '../models/my_job_model.dart';
import '../widgets/my_job_card.dart';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});
  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  final _ctrl = Get.put(MyJobsController());

  @override
  void dispose() {
    Get.delete<MyJobsController>();
    super.dispose();
  }

  Future<void> _openForm() async {
    final result = await Get.toNamed(AppRoutes.postJob);
    if (result == true && mounted) {
      await _ctrl.load();
      MyJobsController.invalidateList();
    }
  }

  Future<void> _close(MyJobModel job) async {
    if (!await MyJobCard.confirmClose(context)) return;
    await _ctrl.close(job.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Obx(() => AppLoadingOverlay(
            isLoading: _ctrl.isSaving.value,
            message: 'Updating...',
            child: Column(children: [
              _header(),
              Expanded(
                child: Obx(() {
                  final page = _ctrl.page.value;
                  if (!_ctrl.hasLoaded.value && _ctrl.isLoading.value) return _shimmer();
                  return RefreshIndicator(
                    color: StayColors.accent,
                    onRefresh: _ctrl.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + AppInsets.bottomViewPadding(context)),
                      children: [
                        if (page != null) ...[
                          _postBlock(page),
                          const SizedBox(height: 20),
                          if (page.items.isEmpty)
                            _empty()
                          else
                            for (final job in page.items)
                              MyJobCard(
                                key: ValueKey(job.id),
                                job: job,
                                onTap: () => Get.toNamed(AppRoutes.jobDetail, arguments: {'id': job.id}),
                                onClose: () => _close(job),
                              ),
                        ] else if (_ctrl.loadFailed.value)
                          _failed(),
                      ],
                    ),
                  );
                }),
              ),
            ]),
          )),
    );
  }

  Widget _header() => Container(
        decoration: const BoxDecoration(gradient: StayColors.gradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
            child: Row(children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              ),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('My Jobs',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Hire for your stay',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white70)),
              ]),
            ]),
          ),
        ),
      );

  Widget _postBlock(MyJobsPage page) {
    final hint = page.blockMessage;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${page.activeCount} of ${page.maxActive} active',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
      const SizedBox(height: 10),
      GradientButton(
        onPressed: page.canPost ? () => _openForm() : null,
        label: 'Post a Job',
        gradient: StayColors.gradient,
        shadowColor: StayColors.accent,
      ),
      if (hint != null) ...[
        const SizedBox(height: 6),
        Text(hint, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
      ],
    ]);
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(color: StayColors.surface, shape: BoxShape.circle),
            child: const Icon(Iconsax.briefcase, size: 40, color: StayColors.accent),
          ),
          const SizedBox(height: 20),
          const Text('No jobs yet',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 8),
          const Text('Post your first job',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
        ]),
      );

  Widget _failed() => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textHint),
          const SizedBox(height: 10),
          const Text("Couldn't load jobs",
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: GradientButton(
              label: 'Retry',
              height: 42,
              gradient: StayColors.gradient,
              shadowColor: StayColors.accent,
              onPressed: _ctrl.load,
            ),
          ),
        ]),
      );

  Widget _shimmer() => Padding(
        padding: const EdgeInsets.all(16),
        child: Shimmer.fromColors(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
          child: Column(children: [
            for (var i = 0; i < 3; i++)
              Container(
                height: 130,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              ),
          ]),
        ),
      );
}
