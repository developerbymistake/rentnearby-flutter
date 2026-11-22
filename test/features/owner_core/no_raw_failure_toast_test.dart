import 'dart:io';

import 'package:bakhli/features/owner_core/data/owner_args.dart';
import 'package:flutter_test/flutter_test.dart';

// A failure (OwnerFailed) carries raw exception text; it must never reach a toast (FX-28, SEC2-03).
void main() {
  const roots = ['lib/features/owner_core', 'lib/features/stay_owner', 'lib/features/taxi_driver', 'lib/features/seeker_home'];
  final failedCase = RegExp(r'OwnerFailed(<[^>]*>)?\((:final message)?\)');
  final toastWithMessage = RegExp(r'AppToast\.\w+\([^)]*\bmessage\b');

  test('no file passes an OwnerFailed message to AppToast', () {
    final offenders = <String>[];
    for (final root in roots) {
      for (final f in Directory(root).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!failedCase.hasMatch(lines[i]) || !lines[i].contains('case ')) continue;
          for (var j = i + 1; j < lines.length && j <= i + 6; j++) {
            if (lines[j].contains('case ')) break;
            if (toastWithMessage.hasMatch(lines[j])) offenders.add('${f.path}:${j + 1}');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('the lint catches an offender', () {
    const sample = ['      case OwnerFailed(:final message):', '        AppToast.error(message);'];
    expect(failedCase.hasMatch(sample[0]), isTrue);
    expect(toastWithMessage.hasMatch(sample[1]), isTrue);
  });

  group('OwnerArgs.id', () {
    test('a GUID passes, trimmed', () {
      expect(OwnerArgs.id({'id': '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101'}, 'id'), '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a6101');
      expect(OwnerArgs.id({'id': ' 3F9A6C2D-1B7E-4F0A-8C55-2E7D9B4A6101 '}, 'id'), '3F9A6C2D-1B7E-4F0A-8C55-2E7D9B4A6101');
    });

    test('paths, scripts, numbers and empties are missing', () {
      for (final bad in <Object?>['../../admin', '/stays/me', '1 OR 1=1', '<script>', '', null, 42, 'abc', '3f9a6c2d-1b7e-4f0a-8c55-2e7d9b4a610']) {
        expect(OwnerArgs.id({'id': bad}, 'id'), isNull, reason: '$bad');
      }
    });
  });
}
