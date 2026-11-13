import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_jobs.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/plan_controller.dart';
import '../../../widgets/app_loading_overlay.dart';
import '../controllers/my_jobs_controller.dart';
import '../models/my_job_model.dart';
import '../widgets/jobs_ui.dart';
import '../widgets/my_job_card.dart';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});
  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  ListingTone get _look => JobsUi.look;
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
      backgroundColor: JobsLook.pageColor,
      body: Obx(() => AppLoadingOverlay(
            isLoading: _ctrl.isSaving.value,
            message: 'Updating...',
            indicatorColor: _look.g2,
            child: KitStatusBar(
              lightIcons: false,
              child: SafeArea(
                bottom: false,
                child: Column(children: [
                  _header(),
                  const ToastSlot(),
                  Expanded(
                    child: Obx(() {
                      final page = _ctrl.page.value;
                      final loading = !_ctrl.hasLoaded.value && _ctrl.isLoading.value;
                      return KitSwitcher(
                        child: loading
                            ? KeyedSubtree(key: const ValueKey('jobs_skeleton'), child: _placeholders())
                            : KeyedSubtree(key: const ValueKey('jobs_content'), child: _content(page)),
                      );
                    }),
                  ),
                ]),
              ),
            ),
          )),
    );
  }

  Widget _content(MyJobsPage? page) {
    return LayoutBuilder(
      builder: (context, box) {
        final fill = BoxConstraints(minHeight: (box.maxHeight - 40).clamp(0, double.infinity));
        return RefreshIndicator(
          color: _look.g2,
          onRefresh: _ctrl.load,
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(0, 0, 0, 24 + AppInsets.bottomViewPadding(context)),
            children: [
              if (page != null) ...[
                if (page.items.isEmpty)
                  ConstrainedBox(constraints: fill, child: Center(child: _empty(page)))
                else
                  for (var i = 0; i < page.items.length; i++)
                    KitCardEntrance(
                      key: ValueKey(page.items[i].id),
                      index: i,
                      child: MyJobCard(
                        index: i,
                        job: page.items[i],
                        onTap: () => Get.toNamed(AppRoutes.jobDetail, arguments: {'id': page.items[i].id}),
                        onClose: () => _close(page.items[i]),
                      ),
                    ),
              ] else if (_ctrl.loadFailed.value)
                ConstrainedBox(constraints: fill, child: Center(child: _failed())),
            ],
          ),
        );
      },
    );
  }

  Widget _header() => Obx(() {
        final page = _ctrl.page.value;
        return JobsHeader(
          tone: _look,
          art: ListingArt.clipboard,
          title: 'My Jobs',
          subtitle: page == null ? 'Hire for your stay' : '${page.activeCount} of ${page.maxActive} active',
          onBack: () => Get.back(),
        );
      });

  Widget _empty(MyJobsPage page) {
    final hint = page.blockMessage;
    final upgrade = hint != null && page.limitReached && Get.find<PlanController>().paymentEnabled;
    return JobsStateBlock(
      tone: _look,
      art: ListingArt.clipboard,
      title: 'No jobs yet',
      message: 'Post your first job',
      actionLabel: 'Post a Job',
      onAction: _openForm,
      actionEnabled: page.canPost,
      hint: hint,
      linkLabel: upgrade ? 'Upgrade' : null,
      onLink: upgrade ? () => Get.toNamed(AppRoutes.plansBilling) : null,
    );
  }

  Widget _failed() => JobsStateBlock(
        tone: _look,
        art: ListingArt.compass,
        title: "Couldn't load jobs",
        actionLabel: 'Retry',
        onAction: _ctrl.load,
      );

  Widget _placeholders() => ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [for (var i = 0; i < 3; i++) const WideCardSkeleton()],
      );
}
