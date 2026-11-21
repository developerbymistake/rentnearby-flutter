import 'dart:io';

import 'package:bakhli/config/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

const _stayModule = ['lib/features/stay_owner/', 'lib/features/stay/setup/', 'lib/features/stay/enquiries/', 'lib/features/jobs/'];
const _taxiModule = ['lib/features/taxi_driver/', 'lib/features/taxi/setup/', 'lib/features/taxi/requests/', 'lib/features/taxi/leads/'];
const _ownerCore = 'lib/features/owner_core/';
const _coreForbidden = [
  'lib/features/stay_owner/',
  'lib/features/taxi_driver/',
  'lib/features/stay/',
  'lib/features/taxi/',
  'lib/features/jobs/',
  'lib/features/seeker_home/',
];

// Files allowed to import both modules (CONTRACT_APP 2.5 rule 3). Adding to it needs the reviewer.
const _bothAllowed = {
  'lib/config/tab_shell.dart',
  'lib/config/app_routes.dart',
  'lib/config/tour_registry.dart',
  'lib/screens/main_screen.dart',
  'lib/screens/profile/profile_rows.dart',
};

// Imports between the two modules that exist on main before this work (read 2026-11-21); never extend.
const _legacyCrossImports = <String>{};

final _import = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);
final _string = RegExp(r"'((?:[^'\\]|\\.)*)'" '|' r'"((?:[^"\\]|\\.)*)"');

String _norm(String p) => p.replaceAll(r'\', '/');

List<File> _dart(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  return d.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
}

String? _resolve(String from, String uri) {
  if (uri.startsWith('package:bakhli/')) return 'lib/${uri.substring('package:bakhli/'.length)}';
  if (uri.startsWith('package:') || uri.startsWith('dart:')) return null;
  final parts = _norm(File(from).parent.path).split('/');
  for (final seg in uri.split('/')) {
    if (seg == '..') {
      parts.removeLast();
    } else if (seg != '.') {
      parts.add(seg);
    }
  }
  return parts.join('/');
}

Map<String, List<String>> _imports(String dir) => {
      for (final f in _dart(dir))
        _norm(f.path): [
          for (final m in _import.allMatches(f.readAsStringSync())) ?_resolve(_norm(f.path), m.group(1)!),
        ],
    };

bool _in(String path, List<String> roots) => roots.any(path.startsWith);

Iterable<String> _literals(String source) sync* {
  for (final line in source.split('\n')) {
    final t = line.trimLeft();
    if (t.startsWith('import ') || t.startsWith('export ') || t.startsWith('//') || t.startsWith('part ')) continue;
    for (final m in _string.allMatches(line)) {
      yield (m.group(1) ?? m.group(2) ?? '');
    }
  }
}

void main() {
  final all = _imports('lib');

  test('1. the Stay Owner and Taxi Driver modules never import each other', () {
    final bad = <String>[];
    all.forEach((file, deps) {
      for (final d in deps) {
        final stayToTaxi = _in(file, _stayModule) && _in(d, _taxiModule);
        final taxiToStay = _in(file, _taxiModule) && _in(d, _stayModule);
        if ((stayToTaxi || taxiToStay) && !_legacyCrossImports.contains('$file -> $d')) bad.add('$file -> $d');
      }
    });
    expect(bad, isEmpty);
  });

  test('2. owner_core imports neither module nor the stay, taxi, jobs and seeker trees', () {
    final bad = <String>[];
    all.forEach((file, deps) {
      if (!file.startsWith(_ownerCore)) return;
      for (final d in deps) {
        if (_in(d, _coreForbidden)) bad.add('$file -> $d');
      }
    });
    expect(bad, isEmpty);
  });

  test('3. only the allow-listed files import both modules', () {
    final bad = <String>[];
    all.forEach((file, deps) {
      if (_bothAllowed.contains(file)) return;
      final stay = deps.any((d) => d.startsWith('lib/features/stay_owner/'));
      final taxi = deps.any((d) => d.startsWith('lib/features/taxi_driver/'));
      if (stay && taxi) bad.add(file);
    });
    expect(bad, isEmpty);
  });

  test('4. owner code names slots by place, never AppTabs.stays / trips / taxi', () {
    final bad = <String>[];
    for (final dir in ['lib/features/stay_owner', 'lib/features/taxi_driver', 'lib/features/owner_core']) {
      for (final f in _dart(dir)) {
        final s = f.readAsStringSync();
        if (RegExp(r'AppTabs\.(stays|trips|taxi)\b').hasMatch(s)) bad.add(_norm(f.path));
      }
    }
    expect(bad, isEmpty);
  });

  // Words a frame draws in the other role's module; each needs the frame id.
  const roleWordExceptions = <String, String>{
    // A5-taxi-core
    'Bakhli is checking your new licence details. Your bookings stay.': 'o_tx_42 B',
    'Bookings stay. A ringing request and unanswered trip leads close.': 'o_tx_11',
    'Shown in trip plans as a local day. Leave empty to stay out of local days.': 'o_tx_41 D',
    'You stop getting requests until Bakhli approves the change. Your bookings stay.': 'o_tx_42 A',
    // A6-taxi-work
    'Choose which route stays, or get Plus to use all your routes.': 'o_tx_36 E',
    'The request opens again for other drivers. Your calendar entry stays, marked Cancelled.': 'o_tx_38 B',
    '\$name’s request opens again for other drivers. Your calendar entry stays, marked Cancelled.': 'o_tx_38 B',
    // A7-taxi-calendar
    'Amounts stay free': 'o_tx_31',
    'Plus adds up the amounts you write on each booking. Writing them stays free.': 'o_tx_24',
    'Your dates are free again. Notes stay until \${OwnerSharedStrings.dayMonth(until)}.': 'o_tx_46 C',
  };

  test('5. role words stay in their own module', () {
    final bad = <String>[];
    void scan(String dir, List<String> banned) {
      for (final f in _dart(dir)) {
        for (final lit in _literals(f.readAsStringSync())) {
          final low = lit.toLowerCase();
          if (lit.startsWith('/') || lit.contains('.dart') || lit.contains('assets/')) continue;
          for (final w in banned) {
            if (low.contains(w) && !roleWordExceptions.containsKey(lit)) bad.add('${_norm(f.path)}: "$lit" ($w)');
          }
        }
      }
    }

    scan('lib/features/stay_owner', ['taxi', 'driver', 'ride']);
    scan('lib/features/taxi_driver', ['stay', 'homestay', 'room', 'enquir']);
    scan('lib/features/owner_core/strings', ['taxi', 'driver', 'ride', 'stay', 'homestay', 'room', 'enquir']);
    expect(bad, isEmpty);
  });

  test('6. no payment, advance, proof or hold words in the owner modules', () {
    const banned = ['advance request', 'ask advance', 'proof', 'hold for advance', 'holdUntil', 'upi://', 'Pay with'];
    final bad = <String>[];
    for (final dir in ['lib/features/stay_owner', 'lib/features/taxi_driver', 'lib/features/owner_core']) {
      for (final f in _dart(dir)) {
        final s = f.readAsStringSync();
        for (final w in banned) {
          if (s.toLowerCase().contains(w.toLowerCase())) bad.add('${_norm(f.path)}: $w');
        }
      }
    }
    expect(bad, isEmpty);
  });

  test('7. chat and enquiry routes stay registered', () {
    const kept = [
      AppRoutes.chatConversation,
      AppRoutes.chatsList,
      AppRoutes.stayEnquiries,
      AppRoutes.tripReplies,
      AppRoutes.tripLeads,
      AppRoutes.taxiRequests,
      AppRoutes.taxiRequestDetail,
      AppRoutes.myStays,
      AppRoutes.myTaxi,
      AppRoutes.myJobs,
      AppRoutes.notifications,
    ];
    for (final r in kept) {
      expect(AppRoutes.isRegistered(r), isTrue, reason: r);
    }
  });

  test('the guard sees the module folders', () {
    expect(_dart('lib/features/stay_owner'), isNotEmpty);
    expect(_dart('lib/features/taxi_driver'), isNotEmpty);
    expect(_dart('lib/features/owner_core'), isNotEmpty);
  });
}
