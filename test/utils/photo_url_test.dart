import 'package:bakhli/config/app_constants.dart';
import 'package:bakhli/utils/photo_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('absolute http and https urls are kept as they are, trimmed', () {
    expect(PhotoUrl.parse('https://res.cloudinary.com/a/b.jpg'), 'https://res.cloudinary.com/a/b.jpg');
    expect(PhotoUrl.parse('http://x.test/a.png'), 'http://x.test/a.png');
    expect(PhotoUrl.parse('  https://x.test/a.png  '), 'https://x.test/a.png');
  });

  test('a /path gets the server origin', () {
    expect(PhotoUrl.parse('/uploads/t.jpg'), '${AppConstants.serverUrl}/uploads/t.jpg');
  });

  test('anything else is null and never throws', () {
    for (final bad in <Object?>[null, '', '   ', 'abc', 'ftp://x/y.jpg', 'httpx', '//cdn/x.jpg', 'data:image/png;base64,AA', 42, 1.5, true, const <String>[], const <String, int>{}]) {
      expect(PhotoUrl.parse(bad), isNull, reason: '$bad');
    }
  });
}
