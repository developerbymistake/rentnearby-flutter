import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../buddy/shared/buddy_json.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../../buddy/shared/widgets/buddy_snack.dart';
import '../../../buddy/triplimit/trip_limit_models.dart';
import '../../../buddy/triplimit/trip_limit_sheet.dart';
import '../../../buddy/triplimit/trip_limit_strings.dart';
import '../../../trip/controllers/my_trips_controller.dart';
import '../../shared/social_error_types.dart';
import '../../shared/social_live.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_strings.dart';
import '../../shared/widgets/plus_widgets.dart';
import '../social_nav_b.dart';
import '../social_strings_b.dart';
import 'post_about_step.dart';
import 'post_trip_controller.dart';
import 'post_when_step.dart';
import 'post_where_step.dart';
import 'post_wizard_parts.dart';

class PostTripScreen extends StatefulWidget {
  const PostTripScreen({super.key, this.tripId, this.edit = false, this.controller});

  final String? tripId;
  final bool edit;
  final PostTripController? controller;

  static const Key headerKey = ValueKey('post_wizard_header');

  @override
  State<PostTripScreen> createState() => _PostTripScreenState();
}

class _PostTripScreenState extends State<PostTripScreen> {
  late final String _tag = 'post-trip-${identityHashCode(this)}';
  late final PostTripController c = Get.put(widget.controller ?? PostTripController(tripId: widget.tripId, edit: widget.edit), tag: _tag);
  final _scroll = ScrollController();
  Worker? _stepWorker;

  @override
  void initState() {
    super.initState();
    _stepWorker = ever<int>(c.step, (_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _stepWorker?.dispose();
    _scroll.dispose();
    Get.delete<PostTripController>(tag: _tag);
    super.dispose();
  }

  Future<void> _next() async {
    final s = c.step.value;
    if (s < PostTripController.stepAbout) {
      if (c.canNext(s)) c.goTo(s + 1);
      return;
    }
    await _post();
  }

  Future<void> _post() async {
    final r = await c.submit();
    if (!mounted) return;
    switch (r) {
      case BuddyOk() when c.editing:
        SocialLive.posts.value++;
        if (Get.isRegistered<MyTripsController>()) MyTripsController.to.load();
        BuddySnack.show(context, SocialStringsB.postUpdated);
        Navigator.of(context).pop();
      case BuddyOk(:final value):
        SocialLive.posts.value++;
        if (Get.isRegistered<MyTripsController>()) MyTripsController.to.load();
        SocialMeController.maybe?.refreshQuiet();
        SocialNavB.postedNote = value.notifyNearby ? SocialStringsB.nearbyTomorrow : null;
        SocialNavB.backToTravelBuddies(posted: true);
      case BuddyRefused(:final type, :final message, :final data):
        if (type == SocialErrorTypes.publishLimit) {
          BuddySnack.show(context, SocialStringsB.publishLimit(BuddyJson.time(data['nextAllowedAt'])?.toLocal()), danger: true);
          return;
        }
        if (type == SocialErrorTypes.tripLimitReached) {
          await TripLimitSheet.show(context, TripSlots.fromRefusal(data), reason: TripLimitReason.plan);
          return;
        }
        if (PlusSheets.handles(type)) {
          await PlusSheets.limitReached(context, errorType: type!, data: data, from: 'post');
          return;
        }
        BuddySnack.show(context, message ?? SocialStrings.failed, danger: true);
      case BuddyOffline():
        BuddySnack.show(context, SocialStrings.offline, danger: true);
      case BuddyFailed():
        BuddySnack.show(context, SocialStrings.failed, danger: true);
    }
  }

  Widget _body() {
    if (c.preparing.value) return const Center(child: CircularProgressIndicator());
    if (c.prepareFailed.value) {
      return Center(child: StateCard.error(title: SocialStringsB.postGone, actionLabel: SocialStrings.retry, onAction: c.retryPrepare));
    }
    final step = switch (c.step.value) {
      PostTripController.stepWhere => PostWhereStep(c: c),
      PostTripController.stepWhen => PostWhenStep(c: c),
      _ => PostAboutStep(c: c),
    };
    return SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.only(bottom: DS.s(24)),
      child: KeyedSubtree(key: ValueKey('post_step_${c.step.value}'), child: step),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final step = c.step.value;
      c.draft.value;
      final ready = !c.preparing.value && !c.prepareFailed.value;
      final last = step == PostTripController.stepAbout;
      final first = c.fromTrip ? PostTripController.stepWhen : PostTripController.stepWhere;
      return PopScope(
        canPop: step <= first || !ready,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) c.back();
        },
        child: Scaffold(
          backgroundColor: Form3D.fill,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
                child: PageHeader3D(
                  key: PostTripScreen.headerKey,
                  tone: ListingTone.indigo,
                  title: c.editing ? SocialStringsB.editPost : SocialStringsB.wizardTitle,
                  onBack: () => Navigator.of(context).maybePop(),
                  trailing: c.saved.value && step > PostTripController.stepWhere ? const WizardSavedTick(label: SocialStringsB.draftSaved) : null,
                  bottom: WizardProgress(tabs: const [SocialStringsB.stepWhere, SocialStringsB.stepWhen, SocialStringsB.stepAbout], step: step),
                ),
              ),
              Expanded(child: _body()),
              if (ready)
                WizardBottomBar(
                  label: last ? (c.editing ? SocialStringsB.savePost : SocialStringsB.postTrip) : SocialStringsB.next,
                  teal: last,
                  loading: c.busy.value,
                  backLabel: SocialStringsB.back,
                  onBack: step > first ? () => c.back() : null,
                  onNext: c.canNext(step) && !c.busy.value ? _next : null,
                ),
            ],
          ),
        ),
      );
    });
  }
}
