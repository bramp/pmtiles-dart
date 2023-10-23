import 'package:test/test.dart';
import 'package:pmtiles/src/zxy.dart';

void main() {
  group('ZXY', () {
    final tests = {
      ZXY(0, 0, 0): 0,
      ZXY(1, 0, 0): 1,
      ZXY(1, 0, 1): 2,
      ZXY(1, 1, 1): 3,
      ZXY(1, 1, 0): 4,
      ZXY(2, 0, 0): 5,
      ZXY(12, 3423, 1763): 19078479,
    };

    test('fromTileId', () {
      for (final entry in tests.entries) {
        final zxy = ZXY.fromTileId(entry.value);
        expect(zxy, equals(entry.key));
      }
    });

    test('toTileId', () {
      for (final entry in tests.entries) {
        final tileId = entry.key.toTileId();
        expect(tileId, equals(entry.value));
      }
    });
  });
}
