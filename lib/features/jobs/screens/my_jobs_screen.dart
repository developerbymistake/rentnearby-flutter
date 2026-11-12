import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bakhli/design/design.dart';
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
  static const KitTone _tone = JobsUi.tone;
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
      backgroundColor: DesignColors.scaffold,
      body: Obx(() => AppLoadingOverlay(
            isLoading: _ctrl.isSaving.value,
            message: 'Updating...',
            indicatorColor: _tone.accentDark,
            child: Column(children: [
              _header(),
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
          )),
    );
  }

  Widget _content(MyJobsPage? page) {
    return RefreshIndicator(
      color: _tone.accentDark,
      onRefresh: _ctrl.load,
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(0, 12, 0, 16 + AppInsets.bottomViewPadding(context)),
        children: [
          if (page != null) ...[
            if (page.items.isEmpty)
              _empty(page)
            else
              for (var i = 0; i < page.items.length; i++)
                KitCardEntrance(
                  key: ValueKey(page.items[i].id),
                  index: i,
                  child: MyJobCard(
                    job: page.items[i],
                    onTap: () => Get.toNamed(AppRoutes.jobDetail, arguments: {'id': page.items[i].id}),
                    onClose: () => _close(page.items[i]),
                  ),
                ),
          ] else if (_ctrl.loadFailed.value)
            _failed(),
        ],
      ),
    );
  }

  Widget _header() => Obx(() {
        final page = _ctrl.page.value;
        return ModuleHeader(
          tone: _tone,
          title: 'My Jobs',
          subtitle: page == null ? 'Hire for your stay' : '${page.activeCount} of ${page.maxActive} active',
          onBack: () => Get.back(),
        );
      });

  Widget _empty(MyJobsPage page) {
    final hint = page.blockMessage;
    return Column(
      children: [
        const StateCard(
          kit: _tone,
          asset: TravelIcon.note,
          title: 'No jobs yet',
          message: 'Post your first job',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
          child: PrimaryButton(
            label: 'Post a Job',
            tone: _tone,
            onPressed: page.canPost ? _openForm : null,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KitMetrics.gutter),
            child: Text(hint,
                textAlign: TextAlign.center,
                style: TypeTokens.style(12, FontWeight.w500, color: DesignColors.textGrey)),
          ),
          if (page.limitReached && Get.find<PlanController>().paymentEnabled)
            TextLink(label: 'Upgrade', tone: _tone, onTap: () => Get.toNamed(AppRoutes.plansBilling)),
        ],
      ],
    );
  }

  Widget _failed() => StateCard.error(
        kit: _tone,
        title: "Couldn't load jobs",
        actionLabel: 'Retry',
        onAction: _ctrl.load,
      );

  Widget _placeholders() => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12),
        children: [for (var i = 0; i < 3; i++) ListRow.skeleton()],
      );
}
