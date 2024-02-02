// Exclude on browsers because it doesn't support the filesystem.
@TestOn('!js')

import 'package:pmtiles/pmtiles.dart';

import 'package:test/test.dart';
import 'package:path/path.dart' as path;

import '../samples/headers.dart';

/// Removes multiple whitespace from a string.
String removeMultipleWhitespace(String s) {
  return s.replaceAll(RegExp(r'\s+'), ' ');
}

void main() async {
  for (final e in sampleHeaders.entries) {
    final name = e.key;

    test('PmTilesArchive.header($name).header', () async {
      final filename = path.join('samples', name);
      final archive = await PmTilesArchive.from(filename);

      final actual = removeMultipleWhitespace(archive.header.toString());
      final expected = removeMultipleWhitespace(e.value);

      expect(actual, expected);
    });
  }
}
