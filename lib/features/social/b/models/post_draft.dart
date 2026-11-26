import 'package:get_storage/get_storage.dart';

import '../../../buddy/shared/buddy_json.dart';
import '../../../trip/models/trip_city_model.dart';
import '../../shared/social_formats.dart';
import '../social_strings_b.dart';

class PostDraft {
  const PostDraft({
    this.cities = const [],
    this.whenKind = within,
    this.withinMonths = 2,
    this.startDate,
    this.days = 4,
    this.joinGender = 'A',
    this.seats = 3,
    this.text = '',
    this.chips = const [],
    this.textEdited = false,
  });

  static const String within = 'within';
  static const String exact = 'exact';
  static const int maxCities = 4;
  static const int maxMonths = 6;
  static const int maxText = 500;
  static const int startAheadDays = 365;

  final List<TripCityModel> cities;
  final String whenKind;
  final int withinMonths;
  final DateTime? startDate;
  final int days;
  final String joinGender;
  final int seats;
  final String text;
  final List<String> chips;
  final bool textEdited;

  bool get isExact => whenKind == exact;

  String get cityLine => SocialFormats.cities([for (final c in cities) c.name]);

  bool get whenReady => !isExact || startDate != null;

  PostDraft copyWith({
    List<TripCityModel>? cities,
    String? whenKind,
    int? withinMonths,
    DateTime? startDate,
    bool clearStartDate = false,
    int? days,
    String? joinGender,
    int? seats,
    String? text,
    List<String>? chips,
    bool? textEdited,
  }) =>
      PostDraft(
        cities: cities ?? this.cities,
        whenKind: whenKind ?? this.whenKind,
        withinMonths: withinMonths ?? this.withinMonths,
        startDate: clearStartDate ? null : (startDate ?? this.startDate),
        days: days ?? this.days,
        joinGender: joinGender ?? this.joinGender,
        seats: seats ?? this.seats,
        text: text ?? this.text,
        chips: chips ?? this.chips,
        textEdited: textEdited ?? this.textEdited,
      );

  static String dateText(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Body of POST /social/trips (with cityKeys and clientTripId added by the API) and PUT /social/trips/{id}/post.
  Map<String, dynamic> toJson() => {
        'whenKind': whenKind,
        if (!isExact) 'withinMonths': withinMonths,
        if (isExact && startDate != null) 'startDate': dateText(startDate!),
        'days': days,
        'joinGender': joinGender,
        'seats': seats,
        'text': text.trim(),
      };

  String autoText() {
    final who = SocialStringsB.joinCodes.contains(joinGender) ? joinGender : 'A';
    final base = SocialStringsB.autoText(
      cities: cityLine,
      days: days,
      when: SocialStringsB.whenPhrase(whenKind, withinMonths, startDate),
      joinGender: who,
    );
    return [base, for (final c in chips) SocialStringsB.chipLine(c)].join(' ');
  }

  Map<String, dynamic> toStore() => {
        'cities': [for (final c in cities) c.toJson()],
        'whenKind': whenKind,
        'withinMonths': withinMonths,
        'startDate': startDate == null ? null : dateText(startDate!),
        'days': days,
        'joinGender': joinGender,
        'seats': seats,
        'text': text,
        'chips': chips,
        'textEdited': textEdited,
      };

  factory PostDraft.fromStore(Map<String, dynamic> j) {
    final cities = <TripCityModel>[];
    final raw = j['cities'];
    if (raw is List) {
      for (final c in raw) {
        if (c is Map) {
          try {
            cities.add(TripCityModel.fromJson(BuddyJson.map(c)));
          } catch (_) {}
        }
      }
    }
    final kind = BuddyJson.str(j['whenKind'], within);
    return PostDraft(
      cities: cities.take(maxCities).toList(),
      whenKind: kind == exact ? exact : within,
      withinMonths: BuddyJson.integer(j['withinMonths'], 2).clamp(1, maxMonths),
      startDate: BuddyJson.date(j['startDate']),
      days: BuddyJson.integer(j['days'], 4).clamp(1, SocialFormats.moreDays),
      joinGender: BuddyJson.str(j['joinGender'], 'A'),
      seats: BuddyJson.integer(j['seats'], 3),
      text: BuddyJson.str(j['text']),
      chips: BuddyJson.strings(j['chips']),
      textEdited: BuddyJson.boolean(j['textEdited']),
    );
  }
}

abstract final class PostDraftStore {
  static const String box = 'social_post_draft';
  static const String _key = 'draft_v1';
  static Future<void>? _init;

  static Future<void> init() => _init ??= GetStorage.init(box).then((_) {});

  static GetStorage get _box => GetStorage(box);

  static String _slot(String? tripId) => tripId == null || tripId.isEmpty ? 'new' : tripId;

  static Future<PostDraft?> read({required String userId, String? tripId}) async {
    await init();
    final raw = _box.read<dynamic>(_key);
    if (raw is! Map) return null;
    final j = BuddyJson.map(raw);
    if (BuddyJson.str(j['userId']) != userId || BuddyJson.str(j['slot']) != _slot(tripId)) return null;
    try {
      return PostDraft.fromStore(BuddyJson.map(j['draft']));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(PostDraft d, {required String userId, String? tripId}) async {
    await init();
    await _box.write(_key, {'userId': userId, 'slot': _slot(tripId), 'draft': d.toStore()});
  }

  static Future<void> clear() async {
    await init();
    await _box.remove(_key);
  }
}
