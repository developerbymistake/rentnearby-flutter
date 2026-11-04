import 'package:bakhli/utils/search_fold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const vectors = {
    'Dwārāhāt': 'dwarahat',
    'Hēm Kund': 'hem kund',
    'St. Mary’s Church': 'st mary s church',
    'Kalladikuttai - கல்லடிக்குட்டை': 'kalladikuttai',
    'Rani Sui Lake 360° view point': 'rani sui lake 360 view point',
    '  Sri   Bharat Mandir ': 'sri bharat mandir',
    'Tamil ்': 'tamil',
    'ＡＢ City': 'ab city',
    'Rishikesh': 'rishikesh',
    '---': '',
    '': '',
    'Ḍehrādūn': 'dehradun',
    'Śrīnagar': 'srinagar',
    'İstanbul': 'istanbul',
  };

  vectors.forEach((input, expected) {
    test('fold "$input"', () {
      expect(SearchFold.fold(input), expected);
    });
  });

  test('null folds to empty', () {
    expect(SearchFold.fold(null), '');
  });

  test('letters without decomposition are separators', () {
    expect(SearchFold.fold('Søren'), 's ren');
    expect(SearchFold.fold('Łódź'), 'odz');
    expect(SearchFold.fold('Kłos'), 'k os');
    expect(SearchFold.fold('Æon'), 'on');
    expect(SearchFold.fold('Straße'), 'stra e');
  });

  test('fold is idempotent', () {
    for (final input in vectors.keys) {
      final once = SearchFold.fold(input);
      expect(SearchFold.fold(once), once);
    }
  });

  test('startsWith and contains use folded text', () {
    expect(SearchFold.startsWith('Dwārāhāt', 'dwar'), isTrue);
    expect(SearchFold.contains('Hēm Kund', 'kund'), isTrue);
    expect(SearchFold.contains('Hēm Kund', 'xyz'), isFalse);
  });
}
