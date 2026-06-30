import 'package:pmtiles/pmtiles.dart';
import 'package:test/test.dart';

void main() {
  group('Terrarium', () {
    test('detects terrarium metadata', () {
      expect(Terrarium.isTerrarium({'encoding': 'terrarium'}), isTrue);
      expect(Terrarium.isTerrarium({'encoding': 'foo'}), isFalse);
      expect(Terrarium.isTerrarium({'nope': 'terrarium'}), isFalse);
      expect(Terrarium.isTerrarium(null), isFalse);
    });

    test('decodes known elevations', () {
      expect(Terrarium.decodeElevation(128, 0, 0), 0);
      expect(Terrarium.decodeElevation(0, 0, 0), -32768);
      expect(Terrarium.decodeElevation(255, 255, 255), 32767.99609375);
    });

    test('decodes from rgb list', () {
      final rgb = [10, 20, 30, 40, 50, 60];
      expect(
        Terrarium.decodeElevationFromRgb(rgb),
        Terrarium.decodeElevation(10, 20, 30),
      );
      expect(
        Terrarium.decodeElevationFromRgb(rgb, offset: 3),
        Terrarium.decodeElevation(40, 50, 60),
      );
    });

    test('decodes from rgba list using pixelIndex', () {
      final rgba = [
        10,
        20,
        30,
        255,
        40,
        50,
        60,
        128,
      ];

      expect(
        Terrarium.decodeElevationFromRgba(rgba),
        Terrarium.decodeElevation(10, 20, 30),
      );
      expect(
        Terrarium.decodeElevationFromRgba(rgba, pixelIndex: 1),
        Terrarium.decodeElevation(40, 50, 60),
      );
    });

    test('validates channels and offsets', () {
      expect(() => Terrarium.decodeElevation(-1, 0, 0), throwsRangeError);
      expect(() => Terrarium.decodeElevation(0, 256, 0), throwsRangeError);
      expect(() => Terrarium.decodeElevation(0, 0, 999), throwsRangeError);
      expect(
        () => Terrarium.decodeElevationFromRgb([1, 2]),
        throwsRangeError,
      );
      expect(
        () => Terrarium.decodeElevationFromRgba([1, 2, 3], pixelIndex: 1),
        throwsRangeError,
      );
      expect(
        () => Terrarium.decodeElevationFromRgba([1, 2, 3, 4], pixelIndex: -1),
        throwsRangeError,
      );
    });
  });
}
