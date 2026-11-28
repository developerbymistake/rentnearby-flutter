import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../buddy/shared/buddy_result.dart';
import '../../../trip/data/trip_city_catalog.dart';
import '../../../trip/data/trip_repository.dart';
import '../../../trip/models/trip_city_model.dart';
import '../../../trip/models/trip_model.dart';
import '../../shared/social_me_controller.dart';
import '../../shared/social_models.dart';
import '../data/public_trips_api.dart';
import '../models/post_draft.dart';
import '../social_strings_b.dart';

typedef TripLoader = Future<({List<TripCityModel> cities, DateTime? startDate, int days})> Function(String tripId);

class PostTripController extends GetxController {
  PostTripController({this.tripId, this.edit = false, PublicTripsApi api = const PublicTripsApi(), TripLoader? loadTrip, this.persist = true})
      : _api = api,
        _loadTrip = loadTrip ?? _defaultLoadTrip;

  static const int stepWhere = 0;
  static const int stepWhen = 1;
  static const int stepAbout = 2;

  final String? tripId;
  final bool edit;
  final PublicTripsApi _api;
  final TripLoader _loadTrip;
  final bool persist;
  final String clientTripId = const Uuid().v4();

  final draft = const PostDraft().obs;
  final step = stepWhere.obs;
  final saved = false.obs;
  final busy = false.obs;
  final preparing = false.obs;
  final prepareFailed = false.obs;
  final genderLocked = false.obs;
  final citiesLoading = false.obs;
  final citiesFailed = false.obs;
  final query = ''.obs;
  final catalogVersion = 0.obs;

  bool get fromTrip => tripId != null && tripId!.isNotEmpty;

  bool get editing => edit && fromTrip;

  bool get _store => persist && !editing;

  SocialLimits? get limits => SocialMeController.maybe?.me.value?.limits;

  // Spec 22: Anyone and Men only are free; Women only needs Plus.
  bool get canWomenOnly => limits?.genderOnlyTrips ?? false;

  bool get notifyPrivate => SocialMeController.maybe?.profile?.isPrivate ?? false;

  bool get notifyTooFar {
    final d = draft.value;
    final start = d.startDate;
    if (!d.isExact || start == null) return false;
    return start.difference(_today()).inDays > PostDraft.nearbyAheadDays;
  }

  // Server safety rule: a Men only / Women only post reaches nearby travellers only from a poster of that gender.
  // Profile not loaded yet: the server answer decides.
  bool get notifyGender {
    final code = draft.value.joinGender;
    final gender = SocialMeController.maybe?.profile?.gender;
    if (code == 'A' || gender == null) return false;
    return !((code == 'M' && gender == 'Male') || (code == 'F' && gender == 'Female'));
  }

  bool get canNotifyNearby => !editing && !notifyPrivate && !notifyTooFar && !notifyGender;

  void setNotifyNearby(bool on) {
    if (on && !canNotifyNearby) return;
    if (draft.value.notifyNearby == on) return;
    draft.value = draft.value.copyWith(notifyNearby: on);
  }

  bool allowedJoin(String code) => code == 'A' || code == 'M' || (code == 'F' && canWomenOnly);

  List<String> get postChips {
    final c = SocialMeController.maybe?.catalog.postChips ?? const <String>[];
    return c.isEmpty ? SocialStringsB.defaultPostChips : c;
  }

  String get _userId => Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id ?? '' : '';

  static Future<({List<TripCityModel> cities, DateTime? startDate, int days})> _defaultLoadTrip(String id) async {
    final trip = await const TripRepository().get(id);
    return (cities: citiesOf(trip, TripCityCatalog.to.search('')), startDate: trip.startDate, days: trip.dayCount);
  }

  // An archived trip has no plan legs: its cities come from the kept city names.
  @visibleForTesting
  static List<TripCityModel> citiesOf(TripModel trip, List<TripCityModel> catalog) {
    if (trip.archived) {
      return [
        for (final name in trip.archiveOrFallback.cities.map((c) => c.name))
          if (catalog.where((c) => c.name == name).firstOrNull case final known?) known,
      ];
    }
    final cities = <TripCityModel>[];
    for (final leg in trip.plan.legs) {
      final known = catalog.where((c) => c.cityKey == leg.cityKey);
      cities.add(known.isNotEmpty ? known.first : TripCityModel(cityKey: leg.cityKey, name: leg.cityName, latitude: leg.latitude, longitude: leg.longitude));
    }
    return cities;
  }

  @override
  void onInit() {
    super.onInit();
    _prepare();
  }

  Future<void> _prepare() async {
    preparing.value = true;
    prepareFailed.value = false;
    final catalog = TripCityCatalog.to;
    catalog.warmFromDisk();
    if (!fromTrip) _loadCities();
    if (editing) return _prepareEdit();
    PostDraft? restored;
    if (persist && _userId.isNotEmpty) {
      try {
        restored = await PostDraftStore.read(userId: _userId, tripId: tripId);
      } catch (_) {
        restored = null;
      }
    }
    if (fromTrip) {
      try {
        final t = await _loadTrip(tripId!);
        final base = restored ?? const PostDraft();
        final today = _today();
        final start = t.startDate == null ? null : DateTime(t.startDate!.year, t.startDate!.month, t.startDate!.day);
        restored = base.copyWith(
          cities: t.cities.take(PostDraft.maxCities).toList(),
          whenKind: restored == null && start != null && !start.isBefore(today) ? PostDraft.exact : null,
          startDate: restored == null && start != null && !start.isBefore(today) ? start : null,
          days: restored == null && t.days > 0 ? t.days.clamp(1, PostDraft.maxDays) : null,
        );
      } catch (_) {
        preparing.value = false;
        prepareFailed.value = true;
        return;
      }
    }
    var d = restored ?? const PostDraft();
    if (!fromTrip && d.cities.length > 1) d = d.copyWith(cities: d.cities.take(1).toList());
    final fixed = allowedJoin(d.joinGender) ? d : d.copyWith(joinGender: 'A');
    draft.value = fixed.textEdited ? fixed : fixed.copyWith(text: fixed.autoText());
    saved.value = restored != null;
    if (fromTrip) step.value = stepWhen;
    preparing.value = false;
  }

  // Edit post: prefill from the live post; never the stored draft, never coerce the join gender.
  Future<void> _prepareEdit() async {
    try {
      final t = await _loadTrip(tripId!);
      final r = await _api.post(tripId!);
      if (r case BuddyOk(:final value) when value.isMine) {
        draft.value = PostDraft.fromPost(value, cities: t.cities, startDate: t.startDate);
        saved.value = false;
        step.value = stepWhen;
      } else {
        prepareFailed.value = true;
      }
    } catch (_) {
      prepareFailed.value = true;
    }
    preparing.value = false;
  }

  void retryPrepare() => _prepare();

  Future<void> _loadCities() async {
    final catalog = TripCityCatalog.to;
    citiesLoading.value = !catalog.hasData;
    citiesFailed.value = false;
    try {
      await catalog.load();
    } catch (_) {
      if (!catalog.hasData) citiesFailed.value = true;
    }
    citiesLoading.value = false;
    catalogVersion.value++;
  }

  void retryCities() => _loadCities();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<TripCityModel> visibleCities() {
    catalogVersion.value;
    final q = query.value;
    return [for (final c in TripCityCatalog.to.search(q)) if (c.isReady) c];
  }

  bool isPicked(TripCityModel c) => draft.value.cities.any((p) => p.cityKey == c.cityKey);

  // A Travel buddies post is ONE city: a tap picks it (replacing the one before), a second tap clears it.
  void toggleCity(TripCityModel c) {
    if (fromTrip) return;
    final d = draft.value;
    if (isPicked(c)) {
      _update(d.copyWith(cities: const []));
      return;
    }
    if (!c.isReady) return;
    _update(d.copyWith(cities: [c]));
  }

  void setWhenKind(String kind) => _update(draft.value.copyWith(whenKind: kind == PostDraft.exact ? PostDraft.exact : PostDraft.within));

  void setMonths(int n) => _update(draft.value.copyWith(withinMonths: n.clamp(1, PostDraft.maxMonths), whenKind: PostDraft.within));

  void setDate(DateTime d) => _update(draft.value.copyWith(startDate: DateTime(d.year, d.month, d.day), whenKind: PostDraft.exact));

  void setDays(int n) => _update(draft.value.copyWith(days: n.clamp(1, PostDraft.maxDays)));

  void setSeats(int n) => _update(draft.value.copyWith(seats: n));

  void setTravelMode(String code) {
    if (TravelModes.codes.contains(code)) _update(draft.value.copyWith(travelMode: code));
  }

  void setJoinGender(String code) {
    if (!SocialStringsB.joinCodes.contains(code)) return;
    if (!allowedJoin(code)) {
      genderLocked.value = true;
      _update(draft.value.copyWith(joinGender: 'A'));
      return;
    }
    genderLocked.value = false;
    _update(draft.value.copyWith(joinGender: code));
  }

  void setText(String text) {
    if (text == draft.value.text) return;
    _update(draft.value.copyWith(text: text, textEdited: true), regenerate: false);
  }

  void toggleChip(String chip) {
    final d = draft.value;
    final on = d.chips.contains(chip);
    final chips = on ? [for (final c in d.chips) if (c != chip) c] : [...d.chips, chip];
    if (!d.textEdited) {
      _update(d.copyWith(chips: chips));
      return;
    }
    final line = SocialStringsB.chipLine(chip);
    var text = d.text;
    if (on) {
      text = text.replaceFirst(' $line', '').replaceFirst(line, '').trim();
    } else {
      final t = text.trimRight();
      final joined = t.isEmpty ? line : '$t $line';
      text = joined.length > PostDraft.maxText ? text : joined;
    }
    _update(d.copyWith(chips: chips, text: text), regenerate: false);
  }

  void addLine(String line) {
    final d = draft.value;
    final t = d.text.trimRight();
    final joined = t.isEmpty ? line : '$t $line';
    if (joined.length > PostDraft.maxText) return;
    _update(d.copyWith(text: joined, textEdited: true), regenerate: false);
  }

  void _update(PostDraft next, {bool regenerate = true}) {
    final d = regenerate && !next.textEdited ? next.copyWith(text: next.autoText()) : next;
    draft.value = d;
    _save(d);
  }

  void _save(PostDraft d) {
    if (editing) return;
    if (!persist) {
      saved.value = true;
      return;
    }
    final user = _userId;
    if (user.isEmpty) return;
    PostDraftStore.save(d, userId: user, tripId: tripId).then((_) {
      saved.value = true;
    }).catchError((Object _) {});
  }

  bool canNext(int s) {
    final d = draft.value;
    return switch (s) {
      stepWhere => d.cities.isNotEmpty,
      stepWhen => d.whenReady,
      _ => d.text.trim().isNotEmpty && d.text.length <= PostDraft.maxText && d.cities.isNotEmpty && d.whenReady,
    };
  }

  void goTo(int s) {
    if (s < stepWhere || s > stepAbout) return;
    if (fromTrip && s == stepWhere) return;
    step.value = s;
  }

  bool back() {
    final first = fromTrip ? stepWhen : stepWhere;
    if (step.value <= first) return false;
    step.value--;
    return true;
  }

  Future<BuddyResult<PublicTrip>> submit() async {
    if (busy.value) return const BuddyFailed(message: '');
    busy.value = true;
    try {
      final d = draft.value.copyWith(notifyNearby: draft.value.notifyNearby && canNotifyNearby);
      final r = fromTrip ? await _api.publish(tripId!, d) : await _api.create(d, clientTripId: clientTripId);
      if (r.isOk && _store) await PostDraftStore.clear().catchError((Object _) {});
      return r;
    } finally {
      busy.value = false;
    }
  }
}
