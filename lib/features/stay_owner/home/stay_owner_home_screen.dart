import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_constants.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../models/browse_item.dart';
import '../../../services/listing_share_service.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/tab_header.dart';
import '../../owner_core/home/numbers_row.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../stay/setup/stay_setup_controller.dart';
import '../stay_owner_deps.dart';
import '../stay_owner_tabs.dart';
import '../strings/stay_home_strings.dart';
import '../widgets/stay_widgets.dart';
import 'stay_attention_copy.dart';
import 'stay_home_compose.dart';
import 'stay_owner_home_controller.dart';

class StayHomeActions {
  const StayHomeActions._();

  static Future<void> openInstagram() async {
    final app = Uri.parse('instagram://user?username=${AppConstants.instagramUsername}');
    if (!await launchUrl(app, mode: LaunchMode.externalApplication)) {
      await launchUrl(Uri.parse('https://www.instagram.com/${AppConstants.instagramUsername}'), mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> contactSupport() async {
    final uri = Uri(scheme: 'mailto', path: StayHomeStrings.supportMail, query: 'subject=${StayHomeStrings.supportSubject}');
    if (!await launchUrl(uri)) AppToast.error(StayHomeStrings.supportFailed);
  }

  static void openSetupHub() => Get.toNamed(AppRoutes.staySetup, arguments: {'fromMyStays': true});

  static Future<void> share(BuildContext context) async {
    final ctrl = StaySetupController.ensure();
    var s = ctrl.stay.value;
    if (s == null || s.slug == null) {
      await ctrl.load();
      s = ctrl.stay.value;
    }
    if (s == null || s.slug == null || !s.isApproved || !context.mounted) {
      AppToast.info(StayHomeStrings.notLiveYet);
      return;
    }
    await shareListing(
      context: context,
      type: 's',
      slug: s.slug ?? '',
      photoUrl: s.photos.isNotEmpty ? s.photos.first.url : null,
      priceOrArea: 'From ${BrowseItem.inr(s.minPricePerNight ?? 0)}/night',
      typeLabel: s.stayTypeName ?? 'Stay',
      locality: s.locality,
    );
  }

  static StayAttentionActions attention(BuildContext context, String? listingId, String? listingName) => StayAttentionActions(
        reply: () => _auth()?.openTab(AppTabs.centre, intent: const {'bucket': 'New'}),
        openEnquiry: (id) => StayOwnerDeps.openEnquiry(id),
        fixPayment: () => Get.toNamed(AppRoutes.plansBilling),
        openNotificationSettings: () => ph.openAppSettings(),
        choose: () => Get.toNamed(AppRoutes.stayPlanVisible),
        viewReports: () {
          if (listingId == null) return;
          Get.toNamed(AppRoutes.listingReports, arguments: {'listingId': listingId, 'listingType': 'Stay', 'title': listingName ?? 'Stay'});
        },
        viewEditRejected: () => _auth()?.openTab(AppTabs.hub),
        setPrice: StayOwnerDeps.openSpecialPrice,
        addShare: () => Get.toNamed(AppRoutes.stayShareDetails),
        share: () => share(context),
      );

  static AuthController? _auth() => Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
}

class StayOwnerHomeScreen extends StatefulWidget {
  const StayOwnerHomeScreen({super.key, this.controller});

  final StayOwnerHomeController? controller;

  @override
  State<StayOwnerHomeScreen> createState() => _StayOwnerHomeScreenState();
}

class _StayOwnerHomeScreenState extends State<StayOwnerHomeScreen> {
  late final StayOwnerHomeController _c;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    final given = widget.controller ?? StayOwnerHomeController.maybe;
    if (given != null) {
      _c = given;
    } else {
      _c = Get.put(StayOwnerHomeController());
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController && Get.isRegistered<StayOwnerHomeController>()) Get.delete<StayOwnerHomeController>(force: true);
    super.dispose();
  }

  String get _name {
    if (!Get.isRegistered<AuthController>()) return StayHomeStrings.hiFallback;
    final n = Get.find<AuthController>().profileName.value.trim();
    return n.isEmpty ? StayHomeStrings.hiFallback : n.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.forest.page,
      body: Obx(() {
        final load = _c.load.value;
        final dto = load.valueOrNull;
        final subtitle = dto == null ? '' : StayHomeCompose.subtitle(StayHomeCompose.stateOf(dto.listing));
        return TabHeaderFrame(
          title: StayHomeStrings.hi(_name),
          subtitle: subtitle,
          color: ListingPalette.forest.page,
          child: RefreshIndicator(
            color: ListingPalette.forest.g2,
            onRefresh: _c.reload,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.only(bottom: BarMetrics.bodyBottomOf(context)),
              child: _body(load),
            ),
          ),
        );
      }),
    );
  }

  Widget _body(OwnerLoad<OwnerHomeDto> load) {
    return switch (load) {
      OwnerLoadLoading<OwnerHomeDto>() => const _HomeSkeleton(),
      OwnerLoadData<OwnerHomeDto>(:final value) => StayHomeBody(dto: value, controller: _c),
      _ => StayErrorCard(
          art: ListingArt.warning,
          title: StayHomeStrings.couldNotLoad,
          message: StayHomeStrings.checkConnection,
          action: StayHomeStrings.tryAgain,
          onAction: _c.reload,
          margin: DS.insets(l: 18, t: 44, r: 18),
        ),
    };
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 18, t: 20, r: 18),
        child: Column(
          children: [
            SkeletonBox(height: DS.s(140), radius: DS.radius(24)),
            Gap.v(20),
            SkeletonBox(height: DS.s(130), radius: DS.radius(24)),
            Gap.v(16),
            SkeletonBox(height: DS.s(70), radius: DS.radius(16)),
          ],
        ),
      );
}

class StayHomeBody extends StatelessWidget {
  const StayHomeBody({super.key, required this.dto, required this.controller});

  final OwnerHomeDto dto;
  final StayOwnerHomeController controller;

  @override
  Widget build(BuildContext context) {
    final l = dto.listing;
    final state = StayHomeCompose.stateOf(l);
    final actions = StayHomeActions.attention(context, l.id, l.name);
    final hub = Get.isRegistered<StaySetupController>() ? Get.find<StaySetupController>().stay.value : null;
    final attention = StayHomeCompose.attention(dto, denied: controller.notificationsDenied.value, hasShareDetails: hub?.hasShareDetails ?? false);
    final variant = StayHomeCompose.variant(state);
    final views = StayHomeCompose.rowViews(attention, actions, variant);
    final live = state == StayHomeState.live || state == StayHomeState.paused || state == StayHomeState.areaPaused;
    final showNumbers = live || state == StayHomeState.takenDown;
    final n = dto.numbers;
    final tiles = [
      NumberTile(value: StayHomeStrings.number(showNumbers ? n.newEnquiries : null), label: StayHomeStrings.newEnquiries),
      NumberTile(value: StayHomeStrings.number(showNumbers ? n.offersWaiting : null), label: StayHomeStrings.offersWaiting),
      NumberTile(value: StayHomeStrings.number(showNumbers ? n.confirmed : null), label: StayHomeStrings.confirmed),
    ];

    final children = <Widget>[];
    if (state == StayHomeState.areaPaused) {
      children.add(const StayStrip(
        art: ListingArt.calendar,
        text: StayHomeStrings.areaPausedBanner,
        fill: StayLook.amberSoft,
        ink: StayLook.amberText,
      ));
    }
    children.add(_hero(context, state, l));
    if (state == StayHomeState.takenDown) {
      children.add(const StayStrip(art: ListingArt.shield, text: StayHomeStrings.takenDownStrip, fill: StayLook.tealSoft, ink: StayLook.greenText));
    }
    if (state == StayHomeState.rejected) {
      for (final v in views) {
        children.add(StayRowsCard(rows: [v]));
      }
      children.add(StayRowsCard(rows: [
        StayRowData(
          art: ListingArt.speechBalloon,
          tint: StayLook.artTintRed,
          title: StayHomeStrings.needHelp,
          sub: StayHomeStrings.needHelpSub,
          onTap: StayHomeActions.contactSupport,
          trailing: Text(StayHomeStrings.chevron, style: Ink3D.text(22, FontWeight.w400, Ink3D.hint, letterSpacing: 0)),
          semantics: StayHomeStrings.needHelp,
        ),
      ]));
    } else if (views.isNotEmpty) {
      children.add(_attentionHeader(context, state, views.length));
      children.add(StayRowsCard(rows: views.take(2).toList()));
    }
    children.add(Padding(padding: DS.insets(l: 18, t: 16, r: 18), child: NumbersRow(tiles: tiles)));
    if (live || state == StayHomeState.takenDown) children.add(StayOwnerDeps.upcomingCard());
    final planOk = (state == StayHomeState.live || state == StayHomeState.paused) && !l.plannerOff;
    if (planOk) children.add(StayOwnerDeps.planCard());
    if (state == StayHomeState.live || state == StayHomeState.areaPaused) {
      children.add(const StaySectionTitle(title: StayHomeStrings.quickActions));
      children.add(_quick(context));
    }
    children.add(const StayInstagramCard(
      eyebrow: StayHomeStrings.instagram,
      title: StayHomeStrings.followUs,
      cta: StayHomeStrings.follow,
      onTap: StayHomeActions.openInstagram,
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _hero(BuildContext context, StayHomeState state, OwnerHomeListing l) {
    final tone = StayHomeCompose.tone(state);
    Widget? extra;
    if (StayHomeCompose.showsSwitch(state)) {
      extra = Obx(() => Row(
            children: [
              Flexible(child: Text(StayHomeStrings.acceptingGuests, style: Ink3D.text(13, FontWeight.w700, Colors.white, letterSpacing: 0))),
              Gap.h(10),
              Semantics(
                toggled: controller.switchOn,
                label: StayHomeStrings.acceptingGuests,
                excludeSemantics: true,
                child: Switch3D(
                  tone: tone,
                  value: controller.switchOn,
                  onGradient: true,
                  onChanged: controller.switchBusy.value ? null : controller.setAccepting,
                ),
              ),
            ],
          ));
    } else if (state == StayHomeState.rejected || state == StayHomeState.takenDown) {
      extra = StayWhitePill(label: StayHomeStrings.fixAndResubmit, color: StayLook.redText, onTap: StayHomeActions.openSetupHub);
    }
    return Semantics(
      container: true,
      label: '${l.name}, ${StayHomeCompose.pill(state, l)}',
      child: StayHeroCard(
        tone: tone,
        art: StayHomeCompose.art(state),
        title: l.name,
        pill: StayHomeCompose.pill(state, l),
        line: StayHomeCompose.line(state, l),
        extra: extra,
      ),
    );
  }

  Widget _attentionHeader(BuildContext context, StayHomeState state, int total) => Padding(
        padding: DS.insets(l: 18, t: 22, r: 8),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  state == StayHomeState.review ? StayHomeStrings.whileYouWait : StayHomeStrings.needsAttention,
                  style: Ink3D.text(19, FontWeight.w600, Ink3D.body, letterSpacing: 0),
                ),
              ),
            ),
            if (total > 2)
              TextButton(
                onPressed: () => Get.toNamed(AppRoutes.stayAttention),
                child: Text(StayHomeStrings.seeAll(total), style: Ink3D.text(13, FontWeight.w600, DesignColors.primary, letterSpacing: 0)),
              ),
          ],
        ),
      );

  Widget _quick(BuildContext context) {
    final jobs = StayOwnerTabs.jobsSlotActive;
    return StayRail(tiles: [
      StayRailTile(tone: ListingTone.cE, art: ListingArt.moneyBag, title: StayHomeStrings.editPrices, sub: StayHomeStrings.editPricesSub, onTap: () => StayOwnerDeps.openEditPrices()),
      StayRailTile(tone: ListingTone.teal, art: ListingArt.mobilePhone, title: StayHomeStrings.shareMyStay, sub: StayHomeStrings.shareMyStaySub, onTap: () => StayHomeActions.share(context)),
      if (jobs)
        StayRailTile(tone: StayLook.tealDeep, art: ListingArt.briefcase, title: StayHomeStrings.postJob, sub: StayHomeStrings.postJobSub, add: true, onTap: () => Get.toNamed(AppRoutes.postJob)),
      StayRailTile(tone: ListingTone.cE, art: ListingArt.key, title: StayHomeStrings.contactDetails, sub: StayHomeStrings.contactDetailsSub, onTap: () => Get.toNamed(AppRoutes.stayShareDetails)),
    ]);
  }
}
