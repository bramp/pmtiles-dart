import 'dart:math';

import 'package:pmtiles/src/zxy.dart';
import 'package:test/test.dart';

void main() {
  group('ZXY', () {
    final tests = <ZXY, int>{
      ZXY(0, 0, 0): 0,
      ZXY(1, 0, 0): 1,
      ZXY(1, 0, 1): 2,
      ZXY(1, 1, 1): 3,
      ZXY(1, 1, 0): 4,
      ZXY(2, 0, 0): 5,
      ZXY(12, 3423, 1763): 19078479,
      ZXY(20, 1234, 5678): 366563052717,
      ZXY(25, 1234, 5678): 375299988763469,

      // Largest supported tileId:
      ZXY(26, 67108863, 0): 6004799503160660,

      // Max int that be stored precisely in a double
      // Currently not tested because we don't support it.
      // ZXY(27, 67108861, 67108863): (pow(2, 53) + 1).toInt(),
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
