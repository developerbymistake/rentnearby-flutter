import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/contact_launcher.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_navigation.dart';
import '../trip_strings.dart';
import 'trip_sheet_frame.dart';
import 'trip_today_card.dart';

class TripProblemKinds {
  static const String driverNoShow = 'DriverNoShow';
  static const String hostNoRoom = 'HostNoRoom';
  static const String roadClosed = 'RoadClosed';
  static const String other = 'Other';
}

class TripProblemSheet {
  static Future<bool> show(BuildContext context, {required int day}) async {
    final done = await TripSheetFrame.show<bool>(context, _ProblemBody(day: day));
    return done == true;
  }
}

class _ProblemBody extends StatefulWidget {
  const _ProblemBody({required this.day});

  final int day;

  @override
  State<_ProblemBody> createState() => _ProblemBodyState();
}

class _ProblemBodyState extends State<_ProblemBody> {
  final _note = TextEditingController();
  String? _busyKind;
  bool _otherOpen = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<({String name, String phone})> _contacts() {
    final c = TripPlanController.to;
    final day = widget.day;
    final out = <({String name, String phone})>[];
    void add(String name, String? phone) {
      if (phone != null && ContactLauncher.tenDigits(phone).isNotEmpty) out.add((name: name, phone: phone));
    }

    final stay = c.todayStay(day);
    if (stay != null) {
      add(stay.listingName, TripTodayCard.stayPhone(stay));
    } else {
      final own = c.ownStayOf(day);
      if (own != null) add(own.name, own.ownPhone);
    }
    final taxi = c.todayTaxi(day);
    if (taxi != null) {
      add(taxi.listingName, taxi.owner.phone);
    } else {
      final own = c.ownTaxiOf(day);
      if (own != null) add(own.name, own.ownPhone);
    }
    return out;
  }

  Future<void> _pick(String kind) async {
    if (_busyKind != null) return;
    if (kind == TripProblemKinds.other && !_otherOpen) {
      setState(() => _otherOpen = true);
      return;
    }
    FocusScope.of(context).unfocus();
    final c = TripPlanController.to;
    final day = widget.day;
    final enquiryId = switch (kind) {
      TripProblemKinds.driverNoShow => c.todayTaxi(day)?.id,
      TripProblemKinds.hostNoRoom => c.todayStay(day)?.id,
      _ => null,
    };
    final note = kind == TripProblemKinds.other ? _note.text.trim() : '';
    setState(() => _busyKind = kind);
    final ok = await c.reportProblem(
      day: day,
      kind: kind,
      enquiryId: enquiryId,
      note: note.isEmpty ? null : note,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _busyKind = null);
      return;
    }
    final queued = c.lastProblemQueued;
    Navigator.pop(context, true);
    if (queued) return;
    AppToast.info(TripStrings.problemNoted);
    switch (kind) {
      case TripProblemKinds.driverNoShow:
        TripNavigation.openTaxi(day);
      case TripProblemKinds.hostNoRoom:
        TripNavigation.openStay(day);
      default:
        TripNavigation.openMap(day: day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      c.enquiryList.length;
      c.plan.value;
      final offline = c.offline.value;
      final contacts = offline ? _contacts() : const <({String name, String phone})>[];
      return TripSheetFrame(
        title: TripStrings.whatWentWrong,
        footer: const Text(
          TripStrings.problemFooter,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight, height: 1.4),
        ),
        children: [
          if (offline) ...[
            _offlineBlock(contacts),
            const SizedBox(height: 12),
          ],
          _row(Iconsax.car, TripStrings.driverDidNotCome, TripProblemKinds.driverNoShow),
          const SizedBox(height: 8),
          _row(Iconsax.building_4, TripStrings.hostNoRoom, TripProblemKinds.hostNoRoom),
          const SizedBox(height: 8),
          _row(Iconsax.danger, TripStrings.roadClosed, TripProblemKinds.roadClosed),
          const SizedBox(height: 8),
          _row(Iconsax.edit_2, TripStrings.somethingElse, TripProblemKinds.other),
          if (_otherOpen) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              autofocus: true,
              enabled: _busyKind == null,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                ...noEmojiInputFormatters,
                LengthLimitingTextInputFormatter(TripConstants.problemNoteMax),
              ],
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: TripStrings.whatHappened,
                hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.scaffoldBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TripColors.accent, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: TripStrings.done,
              height: 48,
              isLoading: _busyKind == TripProblemKinds.other,
              gradient: TripColors.gradient,
              shadowColor: TripColors.accent,
              onPressed: () => _pick(TripProblemKinds.other),
            ),
          ],
        ],
      );
    });
  }

  Widget _offlineBlock(List<({String name, String phone})> contacts) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            TripStrings.noNetworkTitle,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warningText),
          ),
          const SizedBox(height: 2),
          const Text(
            TripStrings.callHostOrDriver,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.warningText),
          ),
          for (final x in contacts) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => ContactLauncher.call(x.phone),
                icon: const Icon(Iconsax.call, size: 16, color: TripColors.accentDark),
                label: Text(
                  '${TripStrings.call} · ${x.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: TripColors.accentDark),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  side: BorderSide(color: TripColors.accent.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String kind) {
    final busy = _busyKind == kind;
    final selected = kind == TripProblemKinds.other && _otherOpen;
    return Material(
      color: selected ? TripColors.surface : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _busyKind == null && !selected ? () => _pick(kind) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? TripColors.accent : AppColors.divider),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
              ),
              if (busy && kind != TripProblemKinds.other)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: TripColors.accent),
                )
              else
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
