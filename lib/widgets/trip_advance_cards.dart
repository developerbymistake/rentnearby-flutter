import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../features/trip/controllers/trip_plan_controller.dart';
import '../features/trip/models/trip_enquiry_model.dart';
import '../features/trip/trip_colors.dart';
import '../features/trip/trip_navigation.dart';
import '../features/trip/trip_strings.dart';
import '../features/trip/utils/trip_format.dart';
import '../features/trip/widgets/trip_payment_line.dart';
import '../features/trip/widgets/trip_status.dart';
import '../models/browse_item.dart';
import '../models/message_model.dart';
import '../utils/app_toast.dart';
import '../utils/contact_launcher.dart';
import 'trip_chat_cards.dart';

enum _Btn { primary, positive, whatsApp, plain }

class _AdvanceCard {
  final String status;
  final String? enquiryId;
  final int? amount;
  final DateTime? holdUntil;
  final String? upiId;
  final String? whatsApp;
  final String stayName;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? agreedTotal;
  final String? guestPhone;
  final DateTime? proofSentAt;

  const _AdvanceCard({
    required this.status,
    this.enquiryId,
    this.amount,
    this.holdUntil,
    this.upiId,
    this.whatsApp,
    this.stayName = '',
    this.checkIn,
    this.checkOut,
    this.agreedTotal,
    this.guestPhone,
    this.proofSentAt,
  });

  String get money => amount == null ? '' : BrowseItem.inr(amount!);

  String get holdTime => holdUntil == null ? '' : TripFormat.time12Of(holdUntil!);

  String get range {
    final a = checkIn;
    final b = checkOut;
    if (a == null) return '';
    return TripFormat.dateRange(a, b ?? a);
  }

  bool get canStillMark {
    final ci = checkIn;
    if (ci == null) return true;
    final now = DateTime.now();
    return !DateTime(ci.year, ci.month, ci.day).isBefore(DateTime(now.year, now.month, now.day));
  }
}

class TripAdvanceCards {
  static const String requestType = 'trip_advance_request';
  static const String proofType = 'trip_advance_proof_sent';

  static const String _pending = 'pending';
  static const String _proofSent = 'proofSent';
  static const String _received = 'received';
  static const String _replaced = 'replaced';
  static const String _holdExpired = 'holdExpired';

  static _AdvanceCard _read(Map<String, dynamic> p, TripAdvanceModel? live) {
    final wire = _str(p, 'status') ?? _pending;
    final holdUntil = DateTime.tryParse(_str(p, 'holdUntil') ?? '');
    final amount = _num(p, 'amount')?.toInt();
    var status = wire;
    if (live != null && wire != _replaced && _sameRequest(live, holdUntil, amount)) {
      status = switch (live.status) {
        TripAdvanceStatuses.proofSent => _proofSent,
        TripAdvanceStatuses.received => _received,
        TripAdvanceStatuses.holdExpired => _holdExpired,
        _ => wire,
      };
    }
    if ((status == _pending || status == _proofSent) && holdUntil != null && !holdUntil.isAfter(DateTime.now())) {
      status = _holdExpired;
    }
    return _AdvanceCard(
      status: status,
      enquiryId: _str(p, 'enquiryId'),
      amount: amount,
      holdUntil: holdUntil,
      upiId: _str(p, 'upiId'),
      whatsApp: _str(p, 'whatsApp'),
      stayName: _str(p, 'stayName') ?? '',
      checkIn: tripDate(p['checkIn']),
      checkOut: tripDate(p['checkOut']),
      agreedTotal: _num(p, 'agreedTotal')?.toInt(),
      guestPhone: _str(p, 'guestPhone'),
      proofSentAt: DateTime.tryParse(_str(p, 'proofSentAt') ?? ''),
    );
  }

  static bool _sameRequest(TripAdvanceModel live, DateTime? holdUntil, int? amount) {
    final h = live.holdUntil;
    if (h == null || holdUntil == null) return false;
    return h.isAtSameMomentAs(holdUntil) && live.amount == amount;
  }

  static Widget request(
    BuildContext context,
    MessageModel m, {
    required bool isOwner,
    required Color accent,
    required TripChatCallbacks callbacks,
  }) {
    final a = _read(m.payload, callbacks.advance);
    if (isOwner) return _hostRequest(context, m, a, accent, callbacks);
    return switch (a.status) {
      _proofSent => _waiting(context, m, a, accent, callbacks),
      _received => _receivedCard(context, m, a, accent, callbacks),
      _replaced => _replacedCard(context, m, a, accent),
      _holdExpired => _expiredGuest(context, m, a, accent, callbacks),
      _ => _payCard(context, m, a, accent, callbacks),
    };
  }

  static Widget proofSent(
    BuildContext context,
    MessageModel m, {
    required bool isOwner,
    required Color accent,
    required TripChatCallbacks callbacks,
  }) {
    final a = _read(m.payload, callbacks.advance);
    if (!isOwner) {
      final at = a.proofSentAt ?? callbacks.advance?.proofSentAt ?? m.createdAt;
      return _bubble(m, '${TripStrings.iSentProof} · ${TripFormat.time12Of(at)}', accent);
    }
    return _hostProof(context, m, a, accent, callbacks);
  }

  // guest

  static Widget _payCard(BuildContext context, MessageModel m, _AdvanceCard a, Color accent, TripChatCallbacks cb) {
    final upi = a.upiId;
    final wa = a.whatsApp == null ? '' : ContactLauncher.tenDigits(a.whatsApp!);
    final id = a.enquiryId;
    return _frame(
      context,
      m,
      icon: Iconsax.wallet_3,
      tone: accent,
      title: TripStrings.payDirectlyToHost,
      subtitle: a.holdUntil == null ? null : TripStrings.advanceHoldTill(a.holdTime),
      trailing: a.amount == null ? null : _moneyPill(a.money, accent),
      children: [
        if (upi != null && upi.isNotEmpty) ...[_upiBox(upi, accent), const SizedBox(height: 12)],
        _steps([
          (TripStrings.step1Pay(a.money), false),
          (TripStrings.step2Screenshot, false),
          (TripStrings.step3Host, false),
        ], accent),
        const SizedBox(height: 12),
        _button(TripStrings.iSentProof,
            kind: _Btn.primary,
            accent: accent,
            icon: Iconsax.tick_circle,
            onTap: id == null || cb.onProofSent == null ? null : () => cb.onProofSent!(id)),
        if (wa.isNotEmpty) ...[
          const SizedBox(height: 8),
          _button(TripStrings.openWhatsAppTo(wa),
              kind: _Btn.whatsApp,
              accent: accent,
              icon: Iconsax.message,
              onTap: () => ContactLauncher.whatsApp(wa,
                  message: TripStrings.proofWhatsAppText(a.money, a.stayName, a.range))),
        ],
        const SizedBox(height: 10),
        const TripPaymentLine(),
      ],
    );
  }

  static Widget _waiting(BuildContext context, MessageModel m, _AdvanceCard a, Color accent, TripChatCallbacks cb) {
    final live = cb.advance;
    final sentAt = live?.proofSentAt ?? a.proofSentAt;
    final last = live?.lastHostReminderAt;
    final next = live?.nextHostReminderAt;
    final notYetAt = live?.notYetAt;
    final wa = a.whatsApp == null ? '' : ContactLauncher.tenDigits(a.whatsApp!);
    final host = cb.hostPhone == null ? '' : ContactLauncher.tenDigits(cb.hostPhone!);
    return _frame(
      context,
      m,
      icon: Iconsax.timer_1,
      tone: TripStatusVisuals.advanceText(TripAdvanceStatuses.proofSent),
      title: TripStrings.waitingForHost,
      subtitle: sentAt == null ? null : TripStrings.youSaidProofSent(TripFormat.time12Of(sentAt)),
      trailing: a.amount == null ? null : _moneyPill(a.money, TripStatusVisuals.advanceBar(TripAdvanceStatuses.proofSent)),
      children: [
        _steps([
          (TripStrings.stepPaymentSent, true),
          (TripStrings.stepScreenshotSent, true),
          (TripStrings.stepHostChecks, false),
        ], accent),
        if (last != null) ...[
          const SizedBox(height: 8),
          Text(
            next == null
                ? TripStrings.hostRemindedOnly(TripFormat.time12Of(last))
                : TripStrings.hostReminded(TripFormat.time12Of(last), TripFormat.time12Of(next)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _small,
          ),
        ],
        if (notYetAt != null) ...[
          const SizedBox(height: 8),
          _note(
            TripStrings.hostNotSeenYet,
            [
              TripStrings.hostChecked(TripFormat.time12Of(notYetAt)),
              if (a.holdUntil != null) TripStrings.checkBefore(a.holdTime),
            ].join(' '),
          ),
        ],
        const SizedBox(height: 12),
        if (host.isNotEmpty)
          _button(TripStrings.callHost,
              kind: _Btn.plain, accent: accent, icon: Iconsax.call, onTap: () => ContactLauncher.call(host)),
        if (host.isNotEmpty && wa.isNotEmpty) const SizedBox(height: 8),
        if (wa.isNotEmpty)
          _button(TripStrings.openWhatsApp,
              kind: _Btn.whatsApp,
              accent: accent,
              icon: Iconsax.message,
              onTap: () => ContactLauncher.whatsApp(wa,
                  message: TripStrings.proofWhatsAppText(a.money, a.stayName, a.range))),
        const SizedBox(height: 10),
        const Text(TripStrings.waitingFooter, style: _fine),
      ],
    );
  }

  static Widget _receivedCard(BuildContext context, MessageModel m, _AdvanceCard a, Color accent, TripChatCallbacks cb) {
    final at = cb.advance?.receivedAt;
    final host = cb.hostPhone == null ? '' : ContactLauncher.tenDigits(cb.hostPhone!);
    final total = a.agreedTotal;
    final amount = a.amount;
    final tripId = cb.tripId;
    final tone = TripStatusVisuals.advanceText(TripAdvanceStatuses.received);
    return _frame(
      context,
      m,
      icon: Iconsax.tick_circle,
      tone: tone,
      title: TripStrings.advanceReceived,
      subtitle: at == null
          ? TripStrings.advanceReceivedHostSays
          : TripStrings.saysReceived(a.stayName, a.money, TripFormat.time12Of(at)),
      trailing: amount == null ? null : _moneyPill(a.money, TripStatusVisuals.advanceBar(TripAdvanceStatuses.received)),
      children: [
        if (total != null && amount != null && total > amount)
          Text(TripStrings.balanceAtCheckIn(BrowseItem.inr(total - amount)),
              maxLines: 2, overflow: TextOverflow.ellipsis, style: _body),
        const SizedBox(height: 12),
        if (host.isNotEmpty)
          _button(TripStrings.callHost,
              kind: _Btn.plain, accent: accent, icon: Iconsax.call, onTap: () => ContactLauncher.call(host)),
        if (host.isNotEmpty && tripId != null) const SizedBox(height: 8),
        if (tripId != null)
          _button(TripStrings.viewInTrip,
              kind: _Btn.plain,
              accent: accent,
              icon: Iconsax.routing_2,
              onTap: () => Get.toNamed(AppRoutes.tripPlan, arguments: {'tripId': tripId})),
        const SizedBox(height: 10),
        const TripPaymentLine(),
      ],
    );
  }

  static Widget _expiredGuest(BuildContext context, MessageModel m, _AdvanceCard a, Color accent, TripChatCallbacks cb) {
    final host = cb.hostPhone == null ? '' : ContactLauncher.tenDigits(cb.hostPhone!);
    final others = _otherReplies(cb);
    return _frame(
      context,
      m,
      icon: Iconsax.warning_2,
      tone: TripStatusColors.failed,
      title: TripStrings.hostDidNotConfirm,
      subtitle: TripStrings.roomMayBeReleased,
      trailing: const TripStatusPill(TripDisplayStatus.holdExpired),
      children: [
        if (others.isNotEmpty)
          Text(TripStrings.otherStaysReplied(others.length, others.join(', ')),
              maxLines: 2, overflow: TextOverflow.ellipsis, style: _body),
        const SizedBox(height: 12),
        _button(TripStrings.askOtherStays,
            kind: _Btn.primary, accent: accent, icon: Iconsax.building_4, onTap: () => _askOthers(cb)),
        if (host.isNotEmpty) ...[
          const SizedBox(height: 8),
          _button(TripStrings.callHost,
              kind: _Btn.plain, accent: accent, icon: Iconsax.call, onTap: () => ContactLauncher.call(host)),
        ],
        const SizedBox(height: 10),
        const Text(TripStrings.ifPaidFooter, style: _fine),
      ],
    );
  }

  static List<String> _otherReplies(TripChatCallbacks cb) {
    final day = cb.day;
    if (day == null || !Get.isRegistered<TripPlanController>()) return const [];
    final plan = Get.find<TripPlanController>();
    if (plan.trip.value?.id == null || plan.trip.value?.id != cb.tripId) return const [];
    return plan
        .enquiriesForNight(day)
        .where((e) => e.display == TripDisplayStatus.offered)
        .map((e) => e.listingName)
        .where((n) => n.isNotEmpty)
        .toList();
  }

  static void _askOthers(TripChatCallbacks cb) {
    final tripId = cb.tripId;
    final day = cb.day;
    final loaded = Get.isRegistered<TripPlanController>() && Get.find<TripPlanController>().trip.value?.id == tripId;
    if (loaded && day != null) {
      TripNavigation.openStay(day);
    } else if (tripId != null) {
      Get.toNamed(AppRoutes.tripPlan, arguments: {'tripId': tripId});
    }
  }

  static Widget _replacedCard(BuildContext context, MessageModel m, _AdvanceCard a, Color accent) => Opacity(
        opacity: 0.6,
        child: _frame(
          context,
          m,
          icon: Iconsax.wallet_3,
          tone: AppColors.textLight,
          title: TripStrings.advancePending(a.money),
          subtitle: a.holdUntil == null ? null : TripStrings.holdTill(a.holdTime),
          trailing: const TripStatusPill(TripDisplayStatus.closed, label: TripStrings.replacedByNewer),
          children: const [],
        ),
      );

  // host

  static Widget _hostRequest(BuildContext context, MessageModel m, _AdvanceCard a, Color accent, TripChatCallbacks cb) {
    if (a.status == _replaced) return _replacedCard(context, m, a, accent);
    if (a.status == _holdExpired) return _lateMark(context, m, a, accent, cb);
    final upi = a.upiId;
    final wa = a.whatsApp == null ? '' : ContactLauncher.tenDigits(a.whatsApp!);
    final pill = switch (a.status) {
      _received => TripStatusPill(TripDisplayStatus.confirmedByBoth, label: TripStrings.advanceReceivedHostSays),
      _proofSent => TripStatusPill(TripDisplayStatus.offered,
          label: cb.guestName == null ? TripStrings.waitingForHostHourly : TripStrings.saysProofSent(cb.guestName!)),
      _ => TripStatusPill(TripDisplayStatus.asked, label: TripStrings.holdTill(a.holdTime)),
    };
    return _frame(
      context,
      m,
      icon: Iconsax.wallet_3,
      tone: TripStatusVisuals.advanceText(_liveStatus(a.status)),
      title: TripStrings.advancePending(a.money),
      subtitle: a.holdUntil == null ? null : TripStrings.holdTill(a.holdTime),
      children: [
        Align(alignment: Alignment.centerLeft, child: pill),
        const SizedBox(height: 8),
        if (upi != null && upi.isNotEmpty) _kv(TripStrings.upiId, upi),
        if (wa.isNotEmpty) _kv(TripStrings.whatsApp, '+91 $wa'),
        const SizedBox(height: 10),
        const TripPaymentLine(),
      ],
    );
  }

  static Widget _lateMark(BuildContext context, MessageModel m, _AdvanceCard a, Color accent, TripChatCallbacks cb) {
    final guest = cb.guestPhone == null ? '' : ContactLauncher.tenDigits(cb.guestPhone!);
    final id = a.enquiryId;
    final canMark = !cb.movedOn && a.canStillMark && id != null && cb.onMarkReceived != null;
    return _frame(
      context,
      m,
      icon: Iconsax.warning_2,
      tone: TripStatusColors.failed,
      title: TripStrings.holdEnded,
      subtitle: TripStrings.advanceNotMarked,
      trailing: a.amount == null ? null : _moneyPill(a.money, TripStatusColors.failed),
      children: [
        Text(
          cb.movedOn ? TripStrings.guestMovedOn : TripStrings.canStillMark(cb.guestName ?? ''),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: _body,
        ),
        const SizedBox(height: 12),
        if (canMark) ...[
          _button(TripStrings.markAdvanceReceived,
              kind: _Btn.positive, accent: accent, icon: Iconsax.tick_circle, onTap: () => cb.onMarkReceived!(id)),
          const SizedBox(height: 8),
        ],
        if (guest.isNotEmpty)
          _button(TripStrings.callGuest,
              kind: _Btn.plain, accent: accent, icon: Iconsax.call, onTap: () => ContactLauncher.call(guest)),
        const SizedBox(height: 10),
        const TripPaymentLine(),
      ],
    );
  }

  static Widget _hostProof(BuildContext context, MessageModel m, _AdvanceCard a, Color accent, TripChatCallbacks cb) {
    if (a.status == _replaced) {
      return Opacity(
        opacity: 0.6,
        child: _frame(
          context,
          m,
          icon: Iconsax.camera,
          tone: AppColors.textLight,
          title: TripStrings.saysProofSent(cb.guestName ?? ''),
          trailing: const TripStatusPill(TripDisplayStatus.closed, label: TripStrings.replacedByNewer),
          children: const [],
        ),
      );
    }
    final phone = a.guestPhone == null ? '' : ContactLauncher.tenDigits(a.guestPhone!);
    final id = a.enquiryId;
    final open = a.status == _pending || a.status == _proofSent;
    final Widget? pill = switch (a.status) {
      _received => const TripStatusPill(TripDisplayStatus.confirmedByBoth, label: TripStrings.advanceReceivedHostSays),
      _holdExpired => const TripStatusPill(TripDisplayStatus.holdExpired),
      _ => null,
    };
    return _frame(
      context,
      m,
      icon: Iconsax.camera,
      tone: accent,
      title: TripStrings.saysProofSent(cb.guestName ?? ''),
      subtitle: phone.isEmpty ? null : TripStrings.checkWhatsApp(phone),
      trailing: a.amount == null ? null : _moneyPill(a.money, accent),
      children: [
        if (pill != null) ...[Align(alignment: Alignment.centerLeft, child: pill), const SizedBox(height: 8)],
        if (open) ...[
          const Text(TripStrings.checkAmountFirst, style: _body),
          const SizedBox(height: 12),
          _button(TripStrings.markAdvanceReceived,
              kind: _Btn.positive,
              accent: accent,
              icon: Iconsax.tick_circle,
              onTap: id == null || cb.onMarkReceived == null ? null : () => cb.onMarkReceived!(id)),
          const SizedBox(height: 8),
          _button(TripStrings.notYet,
              kind: _Btn.plain,
              accent: accent,
              onTap: id == null || cb.onNotYet == null ? null : () => cb.onNotYet!(id)),
        ],
        if (open && phone.isNotEmpty) ...[
          const SizedBox(height: 8),
          _button(TripStrings.openWhatsApp,
              kind: _Btn.whatsApp, accent: accent, icon: Iconsax.message, onTap: () => ContactLauncher.whatsApp(phone)),
        ],
      ],
    );
  }

  static String _liveStatus(String cardStatus) => switch (cardStatus) {
        _proofSent => TripAdvanceStatuses.proofSent,
        _received => TripAdvanceStatuses.received,
        _holdExpired => TripAdvanceStatuses.holdExpired,
        _ => TripAdvanceStatuses.pending,
      };

  // building blocks

  static const _body = TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textMedium, height: 1.35);
  static const _small = TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight, height: 1.35);
  static const _fine = TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35);

  static Widget _frame(
    BuildContext context,
    MessageModel m, {
    required IconData icon,
    required Color tone,
    required String title,
    String? subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    final maxWidth = math.min(300.0, MediaQuery.sizeOf(context).width - 40);
    return Align(
      alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: tone.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                  child: Icon(icon, size: 16, color: tone),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                      if (subtitle != null)
                        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _small),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 110), child: trailing),
                ],
              ],
            ),
            if (children.isNotEmpty) const SizedBox(height: 10),
            ...children,
            if (m.isMine) ...[
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerRight, child: _tick(m.readAt != null, onDark: false)),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _moneyPill(String text, Color color) => Container(
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Center(
          widthFactor: 1,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text,
                maxLines: 1,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ),
        ),
      );

  static Widget _upiBox(String upi, Color accent) => Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: AppColors.neutralChip,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(TripStrings.upiId, maxLines: 1, style: _fine),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(upi,
                          maxLines: 1,
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: TripStrings.copy,
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: upi));
                  AppToast.success(TripStrings.upiCopied);
                },
                icon: Icon(Iconsax.copy, size: 18, color: accent),
              ),
            ),
          ],
        ),
      );

  static Widget _steps(List<(String, bool)> steps, Color accent) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: steps[i].$2 ? AppColors.successSurface : accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: steps[i].$2
                        ? const Icon(Icons.check_rounded, size: 13, color: AppColors.successText)
                        : Text('${i + 1}',
                            style: TextStyle(
                                fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: accent)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(steps[i].$1, maxLines: 2, overflow: TextOverflow.ellipsis, style: _body),
                  ),
                ],
              ),
            ),
        ],
      );

  static Widget _note(String title, String body) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warningText)),
            Text(body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.warningText, height: 1.35)),
          ],
        ),
      );

  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: _small),
          const SizedBox(width: 10),
          Expanded(
            child: Text(v,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          ),
        ]),
      );

  static Widget _button(String label, {required _Btn kind, required Color accent, IconData? icon, VoidCallback? onTap}) {
    final disabled = onTap == null;
    final fill = switch (kind) {
      _Btn.primary => accent,
      _Btn.positive => AppColors.successDark,
      _ => Colors.transparent,
    };
    final filled = kind == _Btn.primary || kind == _Btn.positive;
    final fg = filled
        ? Colors.white
        : (kind == _Btn.whatsApp ? AppColors.successText : AppColors.textMedium);
    final edge = kind == _Btn.whatsApp ? AppColors.whatsApp.withValues(alpha: 0.6) : AppColors.divider;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
        Flexible(
          child: Text(label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: disabled ? AppColors.divider : fill,
                foregroundColor: disabled ? AppColors.textHint : fg,
                disabledBackgroundColor: AppColors.divider,
                disabledForegroundColor: AppColors.textHint,
                elevation: 0,
                shape: shape,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: fg,
                side: BorderSide(color: disabled ? AppColors.divider : edge),
                shape: shape,
              ),
              child: child,
            ),
    );
  }

  static Widget _bubble(MessageModel m, String text, Color accent) {
    final mine = m.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? accent : AppColors.cardBg,
          border: mine ? null : Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(text,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, color: mine ? Colors.white : AppColors.textDark)),
          if (mine) ...[const SizedBox(height: 2), _tick(m.readAt != null)],
        ]),
      ),
    );
  }

  static Widget _tick(bool read, {bool onDark = true}) => Icon(
        read ? Icons.done_all_rounded : Icons.done_rounded,
        size: 14,
        color: read ? AppColors.readTick : (onDark ? Colors.white70 : AppColors.textHint),
      );

  static String? _str(Map<String, dynamic> p, String k) {
    final v = p[k];
    return v is String ? v : null;
  }

  static num? _num(Map<String, dynamic> p, String k) {
    final v = p[k];
    return v is num ? v : null;
  }
}
