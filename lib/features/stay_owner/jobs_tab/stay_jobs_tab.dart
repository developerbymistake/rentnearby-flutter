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
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/soft_lock.dart';
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
        final over = page != null && page.overCap && page.canUpgrade;
        final subtitle = page == null
            ? ''
            : over
                ? StayGateStringsWork.overCapHeader(page.activeCount, page.maxActive)
                : StayWorkStrings.activeOf(page.activeCount, page.maxActive);
        return TabHeaderFrame(
          title: StayWorkStrings.myJobs,
          subtitle: subtitle,
          color: look.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _content(page)),
              _postBar(page),
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
    final banner = _banner(page);
    final count = page.items.length;
    return RefreshIndicator(
      color: OwnerLook.stay.accent,
      onRefresh: _ctrl.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.only(bottom: DS.gv(16)),
        itemCount: (banner == null ? 0 : 1) + (count == 0 ? 1 : count),
        itemBuilder: (_, i) {
          if (banner != null) {
            if (i == 0) return banner;
            i--;
          }
          if (count == 0) return const _Empty(title: StayWorkStrings.noJobs, message: StayWorkStrings.noJobsSub);
          final job = page.items[i];
          return StayJobCard(
            key: ValueKey(job.id),
            job: job,
            onView: () => Get.toNamed(AppRoutes.jobDetail, arguments: {'id': job.id}),
            onEdit: job.isActive ? () => _openForm(job.id) : null,
            onClose: job.isActive ? () => _close(job) : null,
          );
        },
      ),
    );
  }

  Widget? _banner(MyJobsPage page) {
    if (!page.canUpgrade || page.stayStatus != 'Approved') return null;
    final String text;
    if (page.overCap) {
      text = StayGateStringsWork.overCap(page.activeCount, page.maxActive);
    } else if (page.atCap) {
      text = StayGateStringsWork.jobsCap(page.maxActive);
    } else {
      return null;
    }
    return Container(
      key: GateKeys.of('g7'),
      margin: DS.gapInsets(l: 14, t: 8, r: 14),
      padding: DS.insets(l: 14, t: 12, r: 12, b: 12),
      decoration: BoxDecoration(color: OwnerLook.amberSoft, borderRadius: DS.circular(12)),
      child: Row(children: [
        ExcludeSemantics(child: Art3D(asset: ListingArt.briefcase, size: 36)),
        Gap.h(12),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(text, style: Ink3D.text(12.5, FontWeight.w600, OwnerLook.amber, height: 1.35, letterSpacing: 0)),
          ),
        ),
        Gap.h(8),
        const SeePlusButton(),
      ]),
    );
  }

  Widget _postBar(MyJobsPage? page) {
    final enabled = page != null && page.canPost;
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s(14), DS.gv(10), DS.s(14), DS.gv(10) + BarMetrics.bodyBottomOf(context)),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.heroTop), boxShadow: DS.shadows(Ink3D.topEdge)),
      child: enabled
          ? GradientPillButton(tone: OwnerLook.stay.tone, label: StayWorkStrings.postAJob, height: 48, fontSize: _postFont, onTap: _post)
          : Semantics(
              button: true,
              enabled: false,
              label: StayWorkStrings.postAJob,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: page == null ? null : _post,
                child: Container(
                  height: DS.s(48),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: OwnerLook.hatch, borderRadius: DS.circular(24)),
                  child: Text(StayWorkStrings.postAJob, style: Ink3D.text(15, FontWeight.w600, Ink3D.sub, letterSpacing: 0)),
                ),
              ),
            ),
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
