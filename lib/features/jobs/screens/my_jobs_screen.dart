import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/my_jobs_controller.dart';
import '../jobs_colors.dart';
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
            indicatorColor: JobColors.accent,
            child: Column(children: [
              _header(),
              Expanded(
                child: Obx(() {
                  final page = _ctrl.page.value;
                  if (!_ctrl.hasLoaded.value && _ctrl.isLoading.value) return _shimmer();
                  return RefreshIndicator(
                    color: JobColors.accent,
                    onRefresh: _ctrl.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(0, 14, 0, 16 + AppInsets.bottomViewPadding(context)),
                      children: [
                        if (page != null) ...[
                          if (page.items.isEmpty)
                            _empty(page)
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

  Widget _header() {
    final page = _ctrl.page.value;
    return Container(
      decoration: const BoxDecoration(gradient: JobColors.gradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 20, 20),
          child: Row(children: [
            IconButton(
              onPressed: () => Get.back(),
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('My Jobs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(page == null ? 'Hire for your stay' : '${page.activeCount} of ${page.maxActive} active',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _empty(MyJobsPage page) {
    final hint = page.blockMessage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(children: [
        Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(color: JobColors.surface, shape: BoxShape.circle),
          child: const Icon(Iconsax.briefcase, size: 40, color: JobColors.accent),
        ),
        const SizedBox(height: 20),
        const Text('No jobs yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        const Text('Post your first job',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textLight)),
        const SizedBox(height: 20),
        GradientButton(
          onPressed: page.canPost ? _openForm : null,
          label: 'Post a Job',
          gradient: JobColors.gradient,
          shadowColor: JobColors.accent,
        ),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
        ],
      ]),
    );
  }

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
              gradient: JobColors.gradient,
              shadowColor: JobColors.accent,
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
