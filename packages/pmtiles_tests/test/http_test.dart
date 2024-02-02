import 'package:pmtiles/pmtiles.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

import 'io_helpers.dart';

void main() async {
  late HttpAt at;

  setUpAll(() async {
    final httpUrl = await startHttpServer();

    final client = http.Client();
    at = HttpAt(client, Uri.parse('$httpUrl/countries-leaf.pmtiles'));
  });

  test('Http.ReadAt', () async {
    for (final size in [1024, 1024 * 1024, 1024 * 1024 * 7]) {
      final s = await at.readAt(0, size);
      final bytes = await s.toBytes();

      expect(bytes.length, size);
    }
  });

  test('Http.ReadAt with offset', () async {
    for (final size in [1024, 1024 * 1024, 1024 * 1024 * 7]) {
      final s = await at.readAt(8978, size);
      final bytes = await s.toBytes();

      expect(bytes.length, size);
    }
  });
}
