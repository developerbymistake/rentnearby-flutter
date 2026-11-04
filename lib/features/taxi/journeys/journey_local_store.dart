import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../controllers/auth_controller.dart';
import 'journey_models.dart';

typedef _StoreState = ({List<SavedJourney> list, JourneyPhones contacts});

class JourneyLocalStore {
  const JourneyLocalStore._();

  static const String _boxName = 'journeys';
  static const String _journeysKey = 'journeys_v1';
  static const String _ownerKey = 'journeys_owner_v1';
  static const String _contactsKey = 'journey_contacts_v1';
  static const FlutterSecureStorage _secure = FlutterSecureStorage(aOptions: AndroidOptions());

  static Future<void>? _init;
  static Future<void> _queue = Future.value();

  static Future<void> init() => _init ??= GetStorage.init(_boxName).then((_) {});

  static GetStorage get _box => GetStorage(_boxName);

  static Future<T> _run<T>(Future<T> Function() op) {
    final next = _queue.then((_) => op());
    _queue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  static String? _user() => Get.isRegistered<AuthController>() ? Get.find<AuthController>().user.value?.id : null;

  static List<SavedJourney> _parse(String? raw) {
    if (raw == null || raw.isEmpty) return <SavedJourney>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException();
      return decoded.whereType<Map<String, dynamic>>().map(SavedJourney.fromJson).toList();
    } catch (_) {
      _box.remove(_journeysKey);
      return <SavedJourney>[];
    }
  }

  static Future<JourneyPhones> _readContacts() async {
    try {
      final raw = await _secure.read(key: _contactsKey);
      if (raw == null || raw.isEmpty) return <String, Map<String, String>>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Map<String, String>>{};
      final out = <String, Map<String, String>>{};
      decoded.forEach((k, v) {
        if (k is String && v is Map) {
          final entry = <String, String>{};
          v.forEach((a, b) {
            if (a is String && b is String && b.isNotEmpty) entry[a] = b;
          });
          if (entry.isNotEmpty) out[k] = entry;
        }
      });
      return out;
    } catch (_) {
      return <String, Map<String, String>>{};
    }
  }

  static Future<_StoreState> _load(String user) async {
    await init();
    if (_box.read<String>(_ownerKey) != user) {
      return (list: <SavedJourney>[], contacts: <String, Map<String, String>>{});
    }
    return (list: _parse(_box.read<String>(_journeysKey)), contacts: await _readContacts());
  }

  static void _collect(JourneyPhones contacts, SavedJourney j) {
    for (final leg in j.legs) {
      for (final c in leg.contacts) {
        final entry = contacts[c.taxiId] ?? <String, String>{};
        if (c.hasPhone) entry['phone'] = c.phone!;
        if (c.hasWhatsApp) entry['whatsApp'] = c.whatsApp!;
        if (entry.isNotEmpty) contacts[c.taxiId] = entry;
      }
    }
  }

  static Future<void> _save(String user, List<SavedJourney> list, JourneyPhones contacts) async {
    final keep = <String>{for (final j in list) for (final l in j.legs) for (final c in l.contacts) c.taxiId};
    contacts.removeWhere((taxiId, _) => !keep.contains(taxiId));
    await _box.write(_ownerKey, user);
    await _box.write(_journeysKey, jsonEncode(list.map((j) => j.toJson(includeContacts: false)).toList()));
    try {
      await _secure.write(key: _contactsKey, value: jsonEncode(contacts));
    } catch (_) {}
  }

  static Future<List<SavedJourney>> read() => _run(() async {
        final user = _user();
        if (user == null) return <SavedJourney>[];
        final s = await _load(user);
        return s.list.map((j) => j.withContacts(s.contacts)).toList();
      });

  static Future<void> upsert(SavedJourney journey) => _run(() async {
        final user = _user();
        if (user == null) return;
        final s = await _load(user);
        _collect(s.contacts, journey);
        final stamped = journey.copyWith(savedLocallyAt: DateTime.now());
        final i = s.list.indexWhere((j) => j.id == journey.id);
        if (i >= 0) {
          s.list[i] = stamped;
        } else {
          s.list.add(stamped);
        }
        await _save(user, s.list, s.contacts);
      });

  static Future<void> replaceAll(List<SavedJourney> journeys) => _run(() async {
        final user = _user();
        if (user == null) return;
        final s = await _load(user);
        final now = DateTime.now();
        for (final j in journeys) {
          _collect(s.contacts, j);
        }
        await _save(user, journeys.map((j) => j.copyWith(savedLocallyAt: now)).toList(), s.contacts);
      });

  static Future<void> remove(String id) => _run(() async {
        final user = _user();
        if (user == null) return;
        final s = await _load(user);
        s.list.removeWhere((j) => j.id == id);
        await _save(user, s.list, s.contacts);
      });

  static Future<void> clear() => _run(() async {
        await init();
        await _box.remove(_journeysKey);
        await _box.remove(_ownerKey);
        try {
          await _secure.delete(key: _contactsKey);
        } catch (_) {}
      });
}
