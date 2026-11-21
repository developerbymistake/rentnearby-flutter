import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/money_format.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/pricing/special_price_math.dart';
import '../../owner_core/sheets/owner_sheet.dart';
import '../../stay/models/stay_owner_model.dart';
import '../strings/stay_format.dart';
import '../strings/stay_hub_strings.dart';
import '../widgets/stay_widgets.dart';
import 'stay_hub_controller.dart';

abstract final class StayEditPriceSheet {
  static int? parse(String text) => int.tryParse(text.replaceAll(',', '').trim());

  static bool valid(int? v) => v != null && v >= SpecialPriceMath.minPrice && v <= SpecialPriceMath.maxPrice;

  static String? effectLine(StayOwnerModel stay, int price) {
    final first = stay.specialPricesRow?.first;
    final from = first?.dateFrom;
    final pct = first?.percent;
    if (first == null || from == null || pct == null || first.direction == PriceDirection.unknown) return null;
    final lower = first.direction == PriceDirection.lower;
    return StayHubStrings.effectLine(StayFormat.rangeTo(from, first.dateTo), Money.exact(SpecialPriceMath.adjust(price, lower, pct)), lower, pct);
  }

  static Future<void> show(BuildContext context, StayHubController ctrl, StayRoomModel room) {
    final stay = ctrl.stay;
    if (stay == null) return Future.value();
    if (stay.isPendingReview) {
      AppToast.info(StayHubStrings.underReview);
      return Future.value();
    }
    final text = TextEditingController(text: Money.group(room.pricePerNight));
    final value = ValueNotifier<String>(text.text);
    text.addListener(() => value.value = text.text);
    return OwnerSheet.show<void>(
      context,
      look: OwnerLook.stay,
      title: StayHubStrings.editPriceTitle,
      subtitle: StayHubStrings.priceFor(room.label),
      art: ListingArt.moneyBag,
      size: SheetSize.hug,
      dirty: () => parse(text.text) != room.pricePerNight,
      child: (c) => ValueListenableBuilder<String>(
        valueListenable: value,
        builder: (_, t, _) {
          final v = parse(t);
          final bad = t.trim().isNotEmpty && !valid(v);
          final effect = valid(v) ? effectLine(stay, v ?? 0) : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap.v(6),
              PillField(
                tone: ListingTone.forest,
                controller: text,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7), const _GroupFormatter()],
                prefixText: StayHubStrings.rupee,
                errorRing: bad,
              ),
              Gap.v(8),
              Semantics(
                liveRegion: true,
                child: Text(
                  StayHubStrings.priceHint,
                  style: Ink3D.text(11.5, FontWeight.w400, bad ? StayLook.redText : Ink3D.grey, height: 1.4, letterSpacing: 0),
                ),
              ),
              if (effect != null)
                Padding(
                  padding: EdgeInsets.only(top: DS.gv(4)),
                  child: Semantics(liveRegion: true, child: Text(effect, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, height: 1.4, letterSpacing: 0))),
                ),
              Gap.v(8),
            ],
          );
        },
      ),
      footer: (c) => ValueListenableBuilder<String>(
        valueListenable: value,
        builder: (_, t, _) => Obx(
          () => GradientPillButton(
            tone: ListingTone.forest,
            label: StayHubStrings.save,
            loading: ctrl.priceBusy.value,
            enabled: valid(parse(t)) && !ctrl.priceBusy.value,
            onTap: () async {
              final v = parse(t);
              if (!valid(v)) return;
              if (v == room.pricePerNight) {
                Navigator.of(c).pop();
                return;
              }
              final ok = await ctrl.updatePrice(room.id, v ?? 0);
              if (ok && c.mounted) Navigator.of(c).pop();
            },
          ),
        ),
      ),
    ).whenComplete(() {
      text.dispose();
      value.dispose();
    });
  }
}

class _GroupFormatter extends TextInputFormatter {
  const _GroupFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final n = int.tryParse(newValue.text);
    if (n == null) return newValue;
    final g = Money.group(n);
    return TextEditingValue(text: g, selection: TextSelection.collapsed(offset: g.length));
  }
}
