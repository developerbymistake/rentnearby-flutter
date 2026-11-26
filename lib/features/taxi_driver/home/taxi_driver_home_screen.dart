import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_routes.dart';
import '../../../config/app_tabs.dart';
import '../../../controllers/auth_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_details.dart';
import '../../../services/system_settings_channel.dart';
import '../../../utils/app_toast.dart';
import '../../../widgets/tab_header.dart';
import '../../owner_core/home/numbers_row.dart';
import '../../owner_core/data/owner_args.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/sheets/owner_states.dart';
import '../../taxi/setup/taxi_setup_controller.dart';
import '../strings/taxi_home_strings.dart';
import '../hub/taxi_hub_controller.dart';
import '../strings/taxi_hub_strings.dart';
import '../taxi_driver_deps.dart';
import '../widgets/taxi_widgets.dart';
import '../strings/taxi_availability_strings.dart';
import 'taxi_attention_copy.dart';
import 'taxi_availability_card.dart';
import 'taxi_driver_home_controller.dart';
import 'taxi_home_compose.dart';

class TaxiHomeActions {
  const TaxiHomeActions._();

  static AuthController? get _auth => Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;

  static Future<void> contactSupport() async {
    final uri = Uri(scheme: 'mailto', path: TaxiHomeStrings.supportMail, query: 'subject=${TaxiHomeStrings.supportSubject}');
    if (!await launchUrl(uri)) AppToast.error(TaxiHomeStrings.supportFailed);
  }

  static void openSetup() => Get.toNamed(AppRoutes.taxiSetup, arguments: {'fromMyTaxi': true});

  static void openNotificationSettings() => SystemSettingsChannel.instance.openNotificationSettings();

  static void startSetup() {
    _auth?.setOwnerShellEmpty(false);
    Get.offAllNamed(AppRoutes.taxiSetup);
  }

  static TaxiAttentionActions attention(String? listingId) => TaxiAttentionActions(
        confirm: (offerId) {
          if (offerId == null) return;
          Get.toNamed(AppRoutes.taxiRequestDetail, arguments: {'offerId': offerId});
        },
        checkReady: () => Get.toNamed(AppRoutes.taxiReady),
        openNotificationSettings: () => ph.openAppSettings(),
        runTest: () => Get.toNamed(AppRoutes.taxiReady, arguments: {'test': true}),
        fixPayment: () => Get.toNamed(AppRoutes.plansBilling),
        choose: () => TaxiDriverDeps.openChooseRoute(),
        viewReports: () {
          if (listingId == null) return;
          Get.toNamed(AppRoutes.listingReports, arguments: {'listingId': listingId, 'listingType': 'Taxi', 'title': TaxiHomeStrings.shareMyTaxi});
        },
        addLocalRate: () => TaxiDriverDeps.openHub(section: 'local'),
        checkFares: () => TaxiDriverDeps.openHub(section: 'routes'),
        addRoute: () => TaxiDriverDeps.openHub(section: 'routes'),
      );

  static void openTab(int index) => _auth?.openTab(index);
}

class TaxiDriverHomeScreen extends StatefulWidget {
  const TaxiDriverHomeScreen({super.key, this.controller});

  final TaxiDriverHomeController? controller;

  @override
  State<TaxiDriverHomeScreen> createState() => _TaxiDriverHomeScreenState();
}

class _TaxiDriverHomeScreenState extends State<TaxiDriverHomeScreen> {
  late final TaxiDriverHomeController _c;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    final given = widget.controller ?? TaxiDriverHomeController.maybe;
    if (given != null) {
      _c = given;
    } else {
      _c = Get.put(TaxiDriverHomeController());
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController && Get.isRegistered<TaxiDriverHomeController>()) Get.delete<TaxiDriverHomeController>(force: true);
    super.dispose();
  }

  String get _name {
    if (!Get.isRegistered<AuthController>()) return TaxiHomeStrings.hiFallback;
    final n = Get.find<AuthController>().profileName.value.trim();
    return n.isEmpty ? TaxiHomeStrings.hiFallback : n.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ListingPalette.coral.page,
      body: Obx(() {
        final load = _c.load.value;
        final dto = load.valueOrNull;
        final subtitle = dto == null ? '' : TaxiHomeCompose.subtitle(TaxiHomeCompose.stateOf(dto.listing), onTripUntil: _tripUntil(dto));
        return TabHeaderFrame(
          title: TaxiHomeStrings.hi(_name),
          subtitle: subtitle,
          color: ListingPalette.coral.page,
          child: RefreshIndicator(
            color: ListingPalette.coral.g2,
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

  String? _tripUntil(OwnerHomeDto dto) {
    final d = dto.listing.onTripUntil;
    return d == null ? null : TaxiHomeFormat.day(d);
  }

  Widget _body(OwnerLoad<OwnerHomeDto> load) {
    return switch (load) {
      OwnerLoadLoading<OwnerHomeDto>() => const _HomeSkeleton(),
      OwnerLoadData<OwnerHomeDto>(:final value, :final stale) => TaxiHomeBody(dto: value, controller: _c, stale: stale),
      OwnerLoadEmpty<OwnerHomeDto>() => TaxiErrorCard(
          art: ListingArt.taxi,
          title: TaxiHubStrings.noTaxiYet,
          message: TaxiHubStrings.noTaxiBody,
          action: TaxiHubStrings.setUpTaxi,
          onAction: TaxiHomeActions.startSetup,
          margin: DS.insets(l: 18, t: 44, r: 18),
        ),
      _ => TaxiErrorCard(
          art: ListingArt.warning,
          title: TaxiHomeStrings.couldNotLoad,
          message: TaxiHomeStrings.checkConnection,
          action: TaxiHomeStrings.tryAgain,
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
            SkeletonBox(height: DS.s(70), radius: DS.radius(16)),
            Gap.v(16),
            SkeletonBox(height: DS.s(90), radius: DS.radius(16)),
          ],
        ),
      );
}

class TaxiHomeBody extends StatelessWidget {
  const TaxiHomeBody({super.key, required this.dto, required this.controller, this.stale = false});

  final OwnerHomeDto dto;
  final TaxiDriverHomeController controller;
  final bool stale;

  @override
  Widget build(BuildContext context) => Obx(() => _content(context));

  Widget _content(BuildContext context) {
    final l = dto.listing;
    final state = TaxiHomeCompose.stateOf(l);
    final actions = TaxiHomeActions.attention(l.id);
    final denied = controller.notificationsDenied.value;
    final rows = TaxiHomeCompose.attention(dto, denied: denied);
    final views = TaxiHomeCompose.rowViews(rows, actions, controller.nowUntracked);
    final total = TaxiHomeCompose.attentionCount(dto, rows, denied: denied);
    final banner = TaxiHomeCompose.banner(state, l);
    final show = TaxiHomeCompose.showsNumbers(state);
    final children = <Widget>[];
    if (stale) children.add(const OwnerStaleLine());

    switch (state) {
      case TaxiHomeState.review:
        children
          ..add(_hero(context, state, l))
          ..add(const TaxiStrip(art: ListingArt.alarmClock, text: TaxiHomeStrings.reviewTip, fill: TaxiLook.accentSoft, ink: TaxiLook.accentText))
          ..add(const TaxiLabel(text: TaxiHomeStrings.whileYouWait))
          ..add(TaxiRowsCard(rows: [
            TaxiRowData(
              art: ListingArt.alarmClock,
              title: TaxiHomeStrings.getReady,
              sub: TaxiHomeStrings.getReadySub,
              onTap: () => Get.toNamed(AppRoutes.taxiReady),
              trailing: TaxiPill(label: TaxiHomeStrings.check, kind: TaxiPillKind.outline, onTap: () => Get.toNamed(AppRoutes.taxiReady)),
            ),
            TaxiRowData(
              art: DetailArt.automobile,
              tint: TaxiLook.artTintRed,
              title: TaxiHomeStrings.vehicleRoutes,
              sub: TaxiHomeStrings.lockedWhileReview,
              onTap: () => TaxiDriverDeps.openHub(),
              trailing: TaxiPill(label: TaxiHomeStrings.view, kind: TaxiPillKind.outline, onTap: () => TaxiDriverDeps.openHub()),
            ),
          ]));
      case TaxiHomeState.rejected:
        children
          ..add(_hero(context, state, l))
          ..add(const TaxiLabel(text: TaxiHomeStrings.needHelp))
          ..add(TaxiRowsCard(rows: [
            TaxiRowData(
              art: ListingArt.speechBalloon,
              tint: TaxiLook.artTintRed,
              title: TaxiHomeStrings.contactSupport,
              sub: TaxiHomeStrings.supportSub,
              onTap: TaxiHomeActions.contactSupport,
              trailing: Text(TaxiHomeStrings.chevron, style: Ink3D.text(22, FontWeight.w400, Ink3D.hint, letterSpacing: 0)),
              semantics: TaxiHomeStrings.contactSupport,
            ),
          ], margin: DS.insets(l: 18, t: 4, r: 18)));
      default:
        children.add(_hero(context, state, l));
        if (state == TaxiHomeState.changesReview) {
          children.add(const TaxiStrip(art: ListingArt.shield, text: TaxiHomeStrings.changesInfo, fill: TaxiLook.accentSoft, ink: TaxiLook.accentText));
        }
        if (state == TaxiHomeState.takenDown) {
          children.add(const TaxiStrip(art: ListingArt.shield, text: TaxiHomeStrings.takenDownStrip, fill: TaxiLook.greenSoft, ink: TaxiLook.greenText));
        }
        if (show) {
          children
            ..add(const TaxiLabel(text: TaxiAvailabilityStrings.labelCaps))
            ..add(TaxiAvailabilityCard(info: dto.availability, today: dto.today));
        }
        if (views.isNotEmpty) {
          children
            ..add(TaxiLabel(
              text: TaxiHomeStrings.needsAttention,
              trailing: total > 2
                  ? TextButton(
                      onPressed: () => Get.toNamed(AppRoutes.taxiAttention),
                      child: Text(TaxiHomeStrings.seeAll(total), style: Ink3D.text(13, FontWeight.w600, TaxiLook.accentText, letterSpacing: 0)),
                    )
                  : null,
            ))
            ..add(Obx(() => TaxiRowsCard(
                  rows: TaxiHomeCompose.rowViews(rows, actions, controller.now.value).take(2).toList(),
                  margin: DS.insets(l: 18, t: 8, r: 18),
                )));
        }
        if (banner != null) {
          children.add(TaxiStrip(art: ListingArt.roundPushpin, text: banner, fill: TaxiLook.amberSoft, ink: TaxiLook.amberText));
        }
        if (show) {
          children.add(TaxiDriverDeps.upcomingCard());
        }
        if (state == TaxiHomeState.live || state == TaxiHomeState.offline) {
          children
            ..add(const TaxiSectionTitle(title: TaxiHomeStrings.quickActions))
            ..add(_quick(context));
        }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _hero(BuildContext context, TaxiHomeState state, OwnerHomeListing l) {
    final tone = TaxiHomeCompose.tone(state);
    final title = l.plate ?? l.name;
    if (state == TaxiHomeState.review || state == TaxiHomeState.rejected) {
      return TaxiHeroCard(
        tone: tone,
        art: TaxiHomeCompose.art(state),
        title: title,
        pill: TaxiHomeCompose.pill(state),
        line: TaxiHomeCompose.line(state, l),
        extra: state == TaxiHomeState.rejected ? TaxiWhitePill(label: TaxiHomeStrings.fixAndResubmit, color: TaxiLook.redText, onTap: TaxiHomeActions.openSetup) : null,
      );
    }
    final showSwitch = TaxiHomeCompose.showsSwitch(state);
    final shown = TaxiHomeCompose.shown(state, switchOn: controller.switchOn);
    final shownTone = TaxiHomeCompose.tone(shown);
    return TaxiStatusCard(
      tone: shownTone,
      art: TaxiHomeCompose.art(state),
      photoUrl: TaxiHomeCompose.art(state) == ListingArt.taxi ? l.displayPhotoUrl : null,
      title: title,
      line: TaxiHomeCompose.line(shown, l),
      body: _body(l, state, TaxiHomeCompose.ringStrip(shown, denied: controller.notificationsDenied.value)),
      trailing: showSwitch
          ? Semantics(
              toggled: controller.switchOn,
              label: TaxiHomeStrings.availableNow,
              excludeSemantics: true,
              child: Switch3D(
                tone: shownTone,
                value: state == TaxiHomeState.changesReview ? false : controller.switchOn,
                onGradient: true,
                onChanged: controller.switchBusy.value || state == TaxiHomeState.changesReview ? null : controller.setAvailable,
              ),
            )
          : null,
    );
  }

  Widget? _body(OwnerHomeListing l, TaxiHomeState state, TaxiRingStrip? strip) {
    final t = TaxiHubController.maybe?.taxi ?? (Get.isRegistered<TaxiSetupController>() ? Get.find<TaxiSetupController>().taxi.value : null);
    final vehicle = l.vehicleName ?? t?.vehicleTypeName;
    final seatCount = l.seats ?? t?.seats;
    final seats = seatCount == null ? null : TaxiHomeStrings.seats(seatCount);
    final routes = t?.routes.length ?? l.routesMeter?.used;
    final children = <Widget>[
      if (vehicle != null || seats != null) ...[
        TaxiCarRow(art: ListingArt.taxi, name: vehicle ?? seats!, sub: vehicle == null ? null : seats),
        Divider(height: 1, thickness: 1, indent: DS.s(16), endIndent: DS.s(16), color: TaxiLook.rowLine),
      ],
      Padding(
        padding: DS.insets(t: 4, b: 4),
        child: Material(type: MaterialType.transparency, child: OwnerFacts(tight: true, facts: _facts(state, routes))),
      ),
      if (strip != null) _strip(strip),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children);
  }

  List<NumberTile> _facts(TaxiHomeState state, int? routes) {
    final n = dto.numbers;
    final hidden = state == TaxiHomeState.changesReview || state == TaxiHomeState.takenDown;
    return [
      NumberTile(value: routes == null ? NumberTile.missing : '$routes', label: TaxiHomeStrings.routeCount(routes ?? 1)),
      NumberTile(
        value: hidden ? TaxiHomeStrings.dash : NumberTile.of(n.newRequests),
        label: TaxiHomeStrings.newRequests,
        onTap: () => TaxiHomeActions.openTab(AppTabs.centre),
      ),
      NumberTile(
        value: hidden ? TaxiHomeStrings.dash : NumberTile.of(n.missedRequests ?? 0),
        label: TaxiHomeStrings.missedRequests,
        onTap: () => TaxiHomeActions.openTab(AppTabs.centre),
      ),
      NumberTile(
        value: n.ratingAvg == null || (n.ratingCount ?? 0) == 0 ? NumberTile.missing : n.ratingAvg!.toStringAsFixed(1),
        label: TaxiHomeStrings.rating,
        onTap: () => Get.toNamed(AppRoutes.taxiRating),
      ),
    ];
  }

  Widget _strip(TaxiRingStrip s) => switch (s) {
        TaxiRingStrip.ringing => const TaxiRingStripView(
            title: TaxiHomeStrings.ringOnTitle,
            body: TaxiHomeStrings.ringOnBody,
            fill: TaxiLook.greenSoft,
            ink: TaxiLook.greenText,
          ),
        TaxiRingStrip.offline => TaxiRingStripView(
            title: TaxiHomeStrings.ringOffTitle,
            body: TaxiHomeStrings.ringOffBody,
            fill: TaxiLook.rowLine,
            ink: Ink3D.grey,
            greyArt: true,
          ),
        TaxiRingStrip.muted => TaxiRingStripView(
            title: TaxiHomeStrings.ringMutedTitle,
            body: TaxiHomeStrings.ringMutedBody,
            fill: TaxiLook.amberSoft,
            ink: TaxiLook.amberText,
            action: TaxiHomeStrings.turnOn,
            onAction: TaxiHomeActions.openNotificationSettings,
          ),
      };

  Widget _quick(BuildContext context) => TaxiRail(tiles: [
        TaxiRailTile(tone: ListingTone.coral, art: ListingArt.moneyBag, title: TaxiHomeStrings.editFares, sub: TaxiHomeStrings.editFaresSub, onTap: () => Get.toNamed(AppRoutes.taxiRoutes, arguments: OwnerArgs.manage)),
        TaxiRailTile(tone: ListingTone.sunrise, art: ListingArt.alarmClock, title: TaxiHomeStrings.readyCheck, sub: TaxiHomeStrings.readyCheckSub, onTap: () => Get.toNamed(AppRoutes.taxiReady)),
        TaxiRailTile(tone: ListingTone.indigo, art: ListingArt.star, title: TaxiHomeStrings.myRating, sub: TaxiHomeStrings.myRatingSub, onTap: () => Get.toNamed(AppRoutes.taxiRating)),
      ]);
}
