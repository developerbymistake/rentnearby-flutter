import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/tab_header.dart';
import '../../jobs/controllers/my_jobs_controller.dart';
import '../../jobs/models/my_job_model.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/stay_gate_strings_work.dart';
import '../strings/stay_work_strings.dart';
import 'stay_job_card.dart';

const double _postFont = 15;
const double _actionFont = 14;

class StayJobsTab extends StatefulWidget {
  const StayJobsTab({super.key});

  static const tag = 'stay-jobs-tab';

  @override
  State<StayJobsTab> createState() => _StayJobsTabState();
}

class _StayJobsTabState extends State<StayJobsTab> {
  late final MyJobsController _ctrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.isRegistered<MyJobsController>(tag: StayJobsTab.tag)
        ? Get.find<MyJobsController>(tag: StayJobsTab.tag)
        : Get.put(MyJobsController(refreshOnTab: AppTabs.fourth), tag: StayJobsTab.tag);
  }

  @override
  void dispose() {
    Get.delete<MyJobsController>(tag: StayJobsTab.tag);
    super.dispose();
  }

  Future<void> _post() async {
    final page = _ctrl.page.value;
    if (page != null && !page.canPost) {
      if (page.canUpgrade && page.stayStatus == 'Approved') return PlanGate.showLimit(context, StayGateStringsWork.jobGate(free: page.maxActive));
      final msg = page.blockMessage;
      if (msg != null) AppToast.warning(msg);
      return;
    }
    await _openForm(null);
  }

  Future<void> _openForm(String? id) async {
    if (_busy) return;
    _busy = true;
    try {
      final result = await Get.toNamed(AppRoutes.postJob, arguments: id == null ? null : {'id': id});
      if (result == true && mounted) {
        await _ctrl.load();
        MyJobsController.invalidateList();
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _close(MyJobModel job) async {
    final ok = await OwnerConfirm.ask(
      context,
      title: StayWorkStrings.closeJobTitle,
      body: StayWorkStrings.closeJobBody,
      confirm: StayWorkStrings.closeJob,
      cancel: StayWorkStrings.keep,
      destructive: true,
      tone: OwnerLook.stay.tone,
      art: ListingArt.briefcase,
    );
    if (!ok || !mounted) return;
    await _ctrl.close(job.id);
  }

  @override
  Widget build(BuildContext context) {
    final look = OwnerLook.stay;
    return Material(
      color: look.page,
      child: Obx(() {
        final page = _ctrl.page.value;
        return TabHeaderFrame(
          title: StayWorkStrings.myJobs,
          subtitle: page == null ? '' : StayWorkStrings.activeOf(page.activeCount, page.maxActive),
          color: look.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _postButton(page),
              Expanded(child: _content(page)),
            ],
          ),
        );
      }),
    );
  }

  Widget _content(MyJobsPage? page) {
    if (page == null) {
      if (_ctrl.loadFailed.value) {
        return _Empty(title: StayWorkStrings.couldNotLoadJobs, action: OwnerSharedStrings.tryAgain, onAction: _ctrl.load);
      }
      return const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: OwnerSkeletonList(rows: 2));
    }
    final count = page.items.length;
    return RefreshIndicator(
      color: OwnerLook.stay.accent,
      onRefresh: _ctrl.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.only(bottom: DS.gv(16) + BarMetrics.bodyBottomOf(context)),
        itemCount: count == 0 ? 1 : count,
        itemBuilder: (_, i) {
          if (count == 0) return const _Empty(title: StayWorkStrings.noJobs, message: StayWorkStrings.noJobsSub);
          final job = page.items[i];
          return StayJobCard(
            key: ValueKey(job.id),
            job: job,
            onView: job.isInactive ? null : () => Get.toNamed(AppRoutes.jobDetail, arguments: {'id': job.id}),
            onEdit: job.isActive ? () => _openForm(job.id) : null,
            onClose: job.isActive || job.isInactive ? () => _close(job) : null,
            inactiveReason: job.isInactive ? StayGateStringsWork.jobInactive(page.maxActive) : null,
          );
        },
      ),
    );
  }

  Widget _postButton(MyJobsPage? page) {
    final enabled = page != null && !(page.limitReached && !page.canUpgrade);
    return Padding(
      padding: DS.gapInsets(l: 14, t: 8, r: 14, b: 4),
      child: GradientPillButton(tone: OwnerLook.stay.tone, label: StayWorkStrings.postAJob, height: 48, fontSize: _postFont, enabled: enabled, onTap: enabled ? _post : null),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, this.message, this.action, this.onAction});

  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: DS.gapInsets(l: 26, t: 40, r: 26, b: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(child: Art3D(asset: ListingArt.briefcase, size: 48)),
        Gap.v(10),
        Text(title, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
        if (message != null)
          Padding(
            padding: EdgeInsets.only(top: DS.gv(4)),
            child: Text(message!, textAlign: TextAlign.center, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey, letterSpacing: 0)),
          ),
        if (action != null) ...[
          Gap.v(14),
          GradientPillButton(tone: ListingTone.forest, label: action, expand: false, height: 44, fontSize: _actionFont, onTap: onAction),
        ],
      ]),
    );
  }
}
