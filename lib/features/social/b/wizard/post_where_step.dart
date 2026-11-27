import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../utils/input_formatters.dart';
import '../../../trip/models/trip_city_model.dart';
import '../../../trip/trip_strings_v2_create.dart';
import '../../../trip/widgets/trip_city_art.dart';
import '../../../trip/widgets/trip_city_sheet.dart';
import '../../shared/social_strings.dart';
import '../social_strings_b.dart';
import '../widgets/social_widgets_b.dart';
import 'post_trip_controller.dart';
import 'post_wizard_parts.dart';

class PostWhereStep extends StatefulWidget {
  const PostWhereStep({super.key, required this.c});

  final PostTripController c;

  @override
  State<PostWhereStep> createState() => _PostWhereStepState();
}

class _PostWhereStepState extends State<PostWhereStep> {
  late final TextEditingController _search = TextEditingController(text: widget.c.query.value);

  PostTripController get c => widget.c;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(TripCityModel city) => c.toggleCity(city);

  Widget _picked(List<TripCityModel> cities) {
    final tone = ListingTone.indigo;
    return Padding(
      padding: DS.gapInsets(l: 18, t: 14, r: 18),
      child: Wrap(
        spacing: DS.gh(8),
        runSpacing: DS.gv(8),
        children: [
          for (var i = 0; i < cities.length; i++)
            Tap3D(
              onTap: c.fromTrip ? null : () => _toggle(cities[i]),
              label: cities[i].name,
              exclude: true,
              child: Container(
                padding: DS.insets(l: 6, t: 6, r: 12, b: 6),
                decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.circular(22), boxShadow: tone.glow(blur: 0, dy: 4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: DS.s(26),
                      height: DS.s(26),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: Ink3D.text(12.5, FontWeight.w700, tone.text, letterSpacing: 0)),
                    ),
                    Gap.h(8),
                    Text(cities[i].name, style: Ink3D.text(15, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 0)),
                    if (!c.fromTrip) ...[Gap.h(4), Icon(Icons.close_rounded, size: DS.s(16), color: DesignColors.onPrimary)],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _photo(TripCityModel city) {
    final cover = city.cover;
    if (cover == null) return null;
    return KitPhoto(
      key: ValueKey('post_city_photo_${city.cityKey}'),
      url: cover,
      width: DS.s(52),
      height: DS.s(52),
      tone: TripCityArt.toneOf(city.cityKey),
      asset: TravelIcon.map,
      iconSize: 20,
    );
  }

  Widget _list(List<TripCityModel> items) {
    final tone = ListingTone.indigo;
    return Container(
      margin: DS.gapInsets(l: 18, r: 18),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: SocialLookB.cardRadius, boxShadow: DS.shadows(Ink3D.softShadow)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            SheetListRow(
              key: ValueKey('post_city_${items[i].cityKey}'),
              tone: tone,
              art: TripCitySheet.artOf(items[i]),
              photo: _photo(items[i]),
              title: items[i].name,
              subtitle: items[i].spotCount > 0 ? TripStringsV2Create.cityMeta(items[i].spotCount) : items[i].placeLine,
              selected: c.isPicked(items[i]),
              trailing: RadioMark(selected: c.isPicked(items[i]), tone: tone),
              divider: i > 0,
              onTap: () => _toggle(items[i]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final d = c.draft.value;
      final children = <Widget>[
        const WizardQuestion(title: SocialStringsB.whereTitle, sub: SocialStringsB.whereSub),
      ];
      if (c.fromTrip) {
        children.addAll([
          _picked(d.cities),
          WizardNote(text: SocialStringsB.whereFromTrip),
        ]);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
      }
      children.add(SheetSearchField(
        key: const ValueKey('post_city_search'),
        tone: ListingTone.indigo,
        controller: _search,
        hint: SocialStringsB.searchCity,
        leadingArt: ListingArt.search,
        inputFormatters: noEmojiInputFormatters,
        onChanged: (v) => c.query.value = v,
        margin: DS.gapInsets(l: 18, t: 8, r: 18),
      ));
      if (d.cities.isNotEmpty) children.add(_picked(d.cities));
      final items = c.visibleCities();
      if (items.isEmpty) {
        if (c.citiesLoading.value) {
          children.add(Padding(padding: DS.gapInsets(t: 24), child: const Center(child: CircularProgressIndicator())));
        } else if (c.citiesFailed.value) {
          children.add(Padding(
            padding: DS.gapInsets(t: 18),
            child: StateCard.error(title: SocialStringsB.citiesFailed, actionLabel: SocialStrings.retry, onAction: c.retryCities),
          ));
        } else {
          children.add(WizardNote(text: SocialStringsB.noCities));
        }
      } else {
        children.add(Gap.v(14));
        children.add(_list(items));
      }
      children.add(WizardNote(text: SocialStringsB.whereNote));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    });
  }
}
