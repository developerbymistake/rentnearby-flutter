import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/browse_item.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../../trip/trip_strings.dart';
import '../../trip/trip_strings_h4.dart';
import '../../trip/trip_strings_rc.dart';
import '../../trip/utils/trip_format.dart';
import '../../../widgets/notification_off_banner.dart';
import '../../trip/widgets/trip_status.dart';
import '../../trip/utils/trip_enquiry_rules.dart';
import 'stay_enquiries_controller.dart';
import 'stay_enquiry_actions.dart';
import 'stay_enquiry_format.dart';
import 'stay_enquiry_strings.dart';

class StayEnquiriesScreen extends StatefulWidget {
  const StayEnquiriesScreen({super.key});

  @override
  State<StayEnquiriesScreen> createState() => _StayEnquiriesScreenState();
}

class _StayEnquiriesScreenState extends State<StayEnquiriesScreen> with WidgetsBindingObserver {
  final _ctrl = StayEnquiriesController.ensure();
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  final _highlight = RxnString();
  String? _targetId;
  Worker? _focusWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    final args = Get.arguments;
    _targetId = args is Map ? args['enquiryId']?.toString() : null;
    _ctrl.focusId.value = null;
    if (_ctrl.stay.value == null) _ctrl.ensureStay();
    _focusWorker = ever<String?>(_ctrl.focusId, (id) {
      if (id == null || !mounted) return;
      _ctrl.focusId.value = null;
      _flash(id);
    });
    _init();
  }

  @override
  void dispose() {
    _focusWorker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ctrl.refreshList();
  }

  Future<void> _init() async {
    final id = _targetId;
    _ctrl.bucket.value = StayEnquiryBucket.newOnes;
    if (id != null) {
      final bucket = await _ctrl.bucketFor(id);
      if (bucket != null) _ctrl.bucket.value = bucket;
    }
    await _ctrl.load();
    if (id == null || !mounted) return;
    _flash(id);
  }

  void _flash(String id) {
    _highlight.value = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.1, duration: const Duration(milliseconds: 300));
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _highlight.value == id) _highlight.value = null;
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _ctrl.loadMore();
  }

  static final ListingTone _tone = ListingTone.forest;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final name = _ctrl.stay.value?.name;
      return RepliesScaffold(
        tone: _tone,
        title: TripStrings.enquiries,
        subtitle: name == null || name.isEmpty ? TripStrings.tripEnquiry : name,
        art: ListingArt.speechBalloon,
        onBack: () => Get.back(),
        top: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NotificationOffBanner(),
            EntranceOnce(index: 1, offset: 20, child: _chips()),
            Obx(() => Get.find<AuthController>().staysEnabled
                ? const SizedBox.shrink()
                : const RepliesBanner(art: ListingArt.calendar, text: TripStrings.pausedHere)),
          ],
        ),
        body: Obx(_body),
      );
    });
  }

  Widget _chips() {
    return Obx(() {
      final c = _ctrl.counts.value;
      final selected = _ctrl.bucket.value;
      final looks = {
        StayEnquiryBucket.newOnes: (ListingTone.cE, ListingArt.speechBalloon, c.newCount > 0 ? TripStrings.newChip(c.newCount) : TripStrings.newPill),
        StayEnquiryBucket.offered: (ListingTone.cF, ListingArt.moneyBag, TripStrings.offeredChip),
        StayEnquiryBucket.confirmed: (ListingTone.cB, ListingArt.key, TripStrings.confirmedChip),
        StayEnquiryBucket.closed: (ListingTone.cD, ListingArt.clipboard, TripStrings.closedChip),
      };
      Widget chip(String key) {
        final (tone, art, label) = looks[key]!;
        return BucketChip3D(tone: tone, art: art, label: label, off: selected != key, onTap: () => _ctrl.selectBucket(key));
      }

      final keys = StayEnquiryBucket.all;
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
        child: Column(
          children: [
            for (var r = 0; r < keys.length; r += 2) ...[
              if (r > 0) const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(child: chip(keys[r])),
                  const SizedBox(width: 12),
                  Expanded(child: r + 1 < keys.length ? chip(keys[r + 1]) : const SizedBox.shrink()),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _body() {
    final items = _ctrl.items;
    final loading = _ctrl.loading.value;
    final failed = _ctrl.failed.value;
    final bucket = _ctrl.bucket.value;
    final highlight = _highlight.value;
    final bottom = AppInsets.bottomViewPadding(context) + 16;

    if (loading && items.isEmpty) {
      return _column(ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottom),
        children: const [ReplyCardSkeleton(), ReplyCardSkeleton(), ReplyCardSkeleton()],
      ));
    }
    if (items.isEmpty) {
      final empty = failed && _ctrl.executionDisabled.value
          ? RepliesEmpty(tone: _tone, art: ListingArt.clipboard, title: TripStrings.plannerOff, message: TripStrings.plannerOffSubtitle)
          : failed
          ? RepliesEmpty(
              tone: _tone,
              art: ListingArt.worldMap,
              title: TripStrings.couldNotLoad,
              message: TripStrings.checkConnection,
              actionLabel: TripStrings.retry,
              onAction: _ctrl.load,
            )
          : RepliesEmpty(tone: _tone, art: _emptyArt(bucket), title: _emptyTitle(bucket), message: TripStrings.noEnquiriesSub, topPad: 30);
      return RefreshIndicator(
        color: _tone.g2,
        onRefresh: _ctrl.refreshList,
        child: _column(ListView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), children: [empty])),
      );
    }
    final footer = _ctrl.loadingMore.value || _ctrl.loadMoreFailed.value ? 1 : 0;
    return RefreshIndicator(
      color: _tone.g2,
      onRefresh: _ctrl.refreshList,
      child: _column(ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.only(bottom: bottom),
        itemCount: items.length + footer,
        itemBuilder: (_, i) {
          if (i >= items.length) return _footer();
          final e = items[i];
          return KeyedSubtree(
            key: _keys.putIfAbsent(e.id, () => GlobalKey()),
            child: KitCardEntrance(
              key: ValueKey('${bucket}_${e.id}'),
              index: i,
              child: _EnquiryCard(enquiry: e, highlighted: highlight == e.id, ctrl: _ctrl),
            ),
          );
        },
      )),
    );
  }

  Widget _column(Widget child) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: child),
      );

  Widget _footer() {
    if (_ctrl.loadMoreFailed.value) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
        child: Center(
          child: Tap3D(
            onTap: _ctrl.loadMore,
            label: '${StayEnquiryStrings.retryMore} · ${TripStrings.retry}',
            exclude: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                widthFactor: 1,
                child: Text('${StayEnquiryStrings.retryMore} · ${TripStrings.retry}', style: Ink3D.text(13, FontWeight.w700, _tone.text)),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(child: KitDots(color: _tone.g2)),
    );
  }

  String _emptyTitle(String bucket) => switch (bucket) {
        StayEnquiryBucket.offered => TripStrings.noOffers,
        StayEnquiryBucket.confirmed => TripStrings.noConfirmed,
        StayEnquiryBucket.closed => TripStrings.nothingClosed,
        _ => TripStrings.noEnquiries,
      };

  String _emptyArt(String bucket) => switch (bucket) {
        StayEnquiryBucket.offered => ListingArt.moneyBag,
        StayEnquiryBucket.confirmed => ListingArt.key,
        StayEnquiryBucket.closed => ListingArt.clipboard,
        _ => ListingArt.speechBalloon,
      };
}

class _EnquiryCard extends StatelessWidget {
  _EnquiryCard({required this.enquiry, required this.highlighted, required this.ctrl});

  final TripEnquiryModel enquiry;
  final bool highlighted;
  final StayEnquiriesController ctrl;
  final GlobalKey _menuKey = GlobalKey();

  static String _dates(TripEnquiryModel e) {
    final a = e.checkIn;
    final b = e.checkOut;
    return a != null && b != null ? TripFormat.dayMonthRange(a, b) : e.datesLabel;
  }

  static String _summary(TripEnquiryModel e) {
    final line = StayEnquiryFormat.summary(e);
    final label = e.datesLabel;
    return label.isEmpty ? line : line.replaceFirst(label, _dates(e));
  }

  static String _inr(int? v) => v == null || v <= 0 ? '' : BrowseItem.inr(v);

  static bool _checkInOpen(TripEnquiryModel e) {
    final cin = e.checkIn;
    if (cin == null) return false;
    final now = DateTime.now();
    return !DateTime(cin.year, cin.month, cin.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  ({String? cap, String number, String? unit}) _price(TripEnquiryModel e) {
    final nights = TripStrings.nights(e.nights);
    final counter = e.pendingCounter?.pricePerNight;
    if (counter != null && e.display.isOpen) return (cap: TripStringsRc.proposes, number: _inr(counter), unit: TripStringsRc.perRoomNight);
    final offer = e.openOffer;
    if (e.display == TripDisplayStatus.offered && offer != null) return (cap: TripStringsRc.offer, number: _inr(offer.total), unit: nights);
    final agreed = e.agreedTotal;
    if (agreed != null && agreed > 0) return (cap: TripStrings.total, number: _inr(agreed), unit: nights);
    return (cap: TripStringsRc.nights, number: '${e.nights}', unit: _dates(e));
  }

  List<ReplyRow> _rows(TripEnquiryModel e) {
    final adv = e.advance;
    if (e.display == TripDisplayStatus.confirmedByBoth || e.display == TripDisplayStatus.holdExpired) {
      final change = e.pendingChange;
      if (change != null) {
        final a = change.checkIn;
        final b = change.checkOut;
        return [
          ReplyRow(TripStrings.changeRequest, a != null && b != null ? TripFormat.dayMonthRange(a, b) : TripStrings.notAcceptedYet),
          ReplyRow(TripStrings.total, _inr(change.total)),
          if (adv.hasRequest) ReplyRow(TripStrings.advance, TripStatusVisuals.advanceLabel(adv)),
        ];
      }
      if (adv.hasRequest) {
        final hold = adv.holdUntil;
        return [
          ReplyRow(TripStringsRc.advanceAsked, _inr(adv.amount)),
          if (hold != null)
            hold.isAfter(DateTime.now())
                ? ReplyRow(TripStrings.holdTill(TripFormat.time12Of(hold.toLocal())), '')
                : ReplyRow(TripStrings.holdEnded, TripFormat.time12Of(hold.toLocal())),
          ReplyRow(TripStrings.dates, _dates(e)),
        ];
      }
      return [
        ReplyRow(TripStrings.dates, _dates(e)),
        if (e.context.roomsLabel case final r?) ReplyRow(TripStrings.rooms, r),
        if (e.context.peopleLabel case final p?) ReplyRow(TripStrings.people, p),
      ];
    }
    final days = e.context.days.where((d) => d.spots.isNotEmpty).take(3).toList();
    if (days.isNotEmpty) {
      return [
        for (final d in days) ReplyRow(TripStrings.dayN(d.day), d.spots.length > 2 ? '${d.spots.take(2).join(' · ')} ${StayEnquiryStrings.moreChips(d.spots.length - 2)}' : d.spots.join(' · ')),
        if (days.length < 3) ReplyRow(TripStrings.dates, _dates(e)),
        if (days.length < 2 && e.context.peopleLabel != null) ReplyRow(TripStrings.people, e.context.peopleLabel!),
      ];
    }
    return [
      ReplyRow(TripStrings.dates, _dates(e)),
      if (e.context.peopleLabel case final p?) ReplyRow(TripStrings.people, p),
      if (e.context.roomsLabel case final r?) ReplyRow(TripStrings.rooms, r),
    ];
  }

  (String?, String) _note(TripEnquiryModel e) {
    final counterPrice = e.pendingCounter?.pricePerNight;
    if (counterPrice != null) return (TripStringsH4.proposesPerRoom(StayEnquiryFormat.guest(e), BrowseItem.inr(counterPrice)), ListingArt.moneyBag);
    final change = e.pendingChange;
    if (change != null) {
      final a = change.checkIn;
      final b = change.checkOut;
      return ('${TripStrings.changeRequest} · ${a != null && b != null ? TripFormat.dayMonthRange(a, b) : TripStrings.notAcceptedYet}', ListingArt.calendar);
    }
    if (e.pendingRevised != null && e.display == TripDisplayStatus.confirmedByBoth) {
      return ('${TripStrings.revisedOffer} · ${TripStrings.notAcceptedYet}', ListingArt.clipboard);
    }
    if (e.display == TripDisplayStatus.confirmedByBoth && e.advance.hasRequest) {
      final label = TripStatusVisuals.advanceLabel(e.advance);
      if (label.isNotEmpty) return (label, ListingArt.moneyBag);
    }
    if (e.display == TripDisplayStatus.confirmedByBoth && !e.advance.hasRequest) return (TripStringsRc.askAdvanceNote, ListingArt.moneyBag);
    final offer = e.openOffer;
    if (e.display == TripDisplayStatus.offered && offer != null) return (StayEnquiryStrings.offerPrice(BrowseItem.inr(offer.total)), ListingArt.calendar);
    if (e.display.isOpen && e.expiresAt != null) {
      return (TripStrings.closesIn(TripEnquiryRules.closesInLabel(e.expiresAt!, DateTime.now())), ListingArt.calendar);
    }
    return (null, ListingArt.clipboard);
  }

  @override
  Widget build(BuildContext context) {
    final e = enquiry;
    final price = _price(e);
    final (noteText, noteArt) = _note(e);
    return Obx(() {
      final busy = ctrl.busyIds.contains(e.id);
      ReplyAction a(String label, Future<bool> Function() run) => ReplyAction(label: label, onTap: busy ? null : () => run());
      ReplyAction off(String label) => ReplyAction(label: label);
      final chatOk = e.conversationId != null &&
          (e.display == TripDisplayStatus.asked ||
              e.display == TripDisplayStatus.offered ||
              e.display == TripDisplayStatus.confirmedByBoth ||
              (e.display == TripDisplayStatus.holdExpired && _checkInOpen(e)));
      final chat = ReplyAction(label: TripStrings.chat, onTap: chatOk ? () => _openChat(e) : null);
      final adv = e.advance;
      final advOpen = adv.isPending || adv.isProofSent;
      final menu = <MenuItem3D>[];
      ReplyAction? primary;
      ReplyAction second = off(TripStrings.notAvailableAction);

      switch (e.display) {
        case TripDisplayStatus.asked:
        case TripDisplayStatus.offered:
          final counter = e.pendingCounter;
          if (counter != null) {
            primary = a(TripStrings.acceptPrice, () => StayEnquiryActions.sendOffer(context, e, counter: counter));
            second = a(TripStrings.sendDifferentOffer, () => StayEnquiryActions.sendOffer(context, e));
            menu.add(MenuItem3D(label: TripStrings.notAvailableAction, art: ListingArt.clipboard, danger: true, onTap: busy ? null : () => StayEnquiryActions.notAvailable(context, e)));
          } else {
            primary = a(e.display == TripDisplayStatus.asked ? TripStrings.sendOffer : TripStrings.sendNewOffer, () => StayEnquiryActions.sendOffer(context, e));
            second = a(TripStrings.notAvailableAction, () => StayEnquiryActions.notAvailable(context, e));
          }
        case TripDisplayStatus.confirmedByBoth:
          final change = e.pendingChange;
          final canRevise = e.pendingRevised == null && change == null && _checkInOpen(e);
          if (change != null) {
            primary = a(TripStrings.acceptChange, () => StayEnquiryActions.acceptChange(context, e, change.id));
            second = a(TripStrings.revisedOffer, () => StayEnquiryActions.revisedOffer(context, e, changeRequest: change));
            if (advOpen) {
              menu.add(MenuItem3D(label: TripStrings.markAdvanceReceived, art: ListingArt.moneyBag, positive: true, onTap: busy ? null : () => StayEnquiryActions.markReceived(context, e)));
              menu.add(MenuItem3D(label: TripStrings.notYet, art: ListingArt.calendar, onTap: busy ? null : () => StayEnquiryActions.notYet(context, e)));
            }
          } else if (advOpen) {
            primary = a(TripStrings.markAdvanceReceived, () => StayEnquiryActions.markReceived(context, e));
            second = a(TripStrings.askAgain, () => StayEnquiryActions.askAdvance(context, e));
            menu.add(MenuItem3D(label: TripStrings.notYet, art: ListingArt.calendar, onTap: busy ? null : () => StayEnquiryActions.notYet(context, e)));
          } else {
            if (!adv.hasRequest) primary = a(TripStrings.askForAdvance, () => StayEnquiryActions.askAdvance(context, e));
            second = canRevise ? a(TripStrings.revisedOffer, () => StayEnquiryActions.revisedOffer(context, e)) : off(TripStrings.revisedOffer);
          }
          if (!StayEnquiryBucket.hasEnded(e)) {
            menu.add(MenuItem3D(label: TripStrings.cancelBooking, art: ListingArt.calendar, danger: true, onTap: busy ? null : () => StayEnquiryActions.cancel(context, e)));
          }
        case TripDisplayStatus.holdExpired:
          final open = _checkInOpen(e);
          primary = open ? a(TripStrings.markAdvanceReceived, () => StayEnquiryActions.markReceived(context, e)) : off(TripStrings.markAdvanceReceived);
          final phone = (e.traveller.phone ?? '').isNotEmpty;
          second = ReplyAction(label: TripStrings.callGuest, onTap: open && phone ? () => StayEnquiryActions.callGuest(e) : null);
        default:
          primary = off(TripStrings.sendOffer);
      }
      if ((e.traveller.id ?? '').isNotEmpty) {
        menu.add(MenuItem3D(label: TripStrings.reportTraveller, art: ListingArt.warning, danger: true, onTap: () => StayEnquiryActions.reportTraveller(context, e)));
      }
      final ended = e.display != TripDisplayStatus.confirmedByBoth && !e.display.isOpen && e.display != TripDisplayStatus.holdExpired;
      return Stack(
        children: [
          Positioned.fill(
            top: 44,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(color: highlighted ? ListingTone.forest.tint : Colors.transparent, borderRadius: BorderRadius.circular(28)),
            ),
          ),
          ReplyCard3D(
            status: StatusTone3D.of(e.display.name),
            art: ListingArt.profile,
            pill: TripStatusVisuals.label(e.display, ownerSide: true),
            urgent: e.isUrgent && e.isUnconfirmed,
            title: StayEnquiryFormat.guest(e),
            statusLine: _summary(e),
            cap: price.cap,
            number: price.number,
            unit: price.unit,
            menuKey: _menuKey,
            onMenu: menu.isEmpty ? null : () => showReplyMenu(_menuKey, menu),
            rows: _rows(e),
            note: noteText ?? (ended ? TripStringsRc.enquiryClosed : null),
            noteArt: noteArt,
            primary: busy && primary != null ? ReplyAction(label: primary.label, busy: true) : primary,
            secondary: [chat, second],
          ),
        ],
      );
    });
  }

  void _openChat(TripEnquiryModel e) {
    Get.toNamed(AppRoutes.chatConversation, arguments: {
      'conversationId': e.conversationId,
      'enquiryId': e.id,
      'listingType': 'Stay',
      'stayTypeId': ctrl.stay.value?.stayTypeId,
      'otherPartyId': e.traveller.id ?? '',
      'otherPartyName': StayEnquiryFormat.guest(e),
      'listingTitle': e.listingName,
      'area': null,
      'isOwner': true,
      'status': 'Active',
      'isBlockedByMe': false,
    });
  }
}
