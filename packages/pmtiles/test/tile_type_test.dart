import 'dart:typed_data';

import 'package:pmtiles/src/convert.dart';
import 'package:pmtiles/src/exceptions.dart';
import 'package:pmtiles/src/types.dart';
import 'package:test/test.dart';

void main() {
  group('TileType v3.5', () {
    const decodeCases = <(int, TileType)>[
      (0, TileType.unknown),
      (1, TileType.mvt),
      (2, TileType.png),
      (3, TileType.jpeg),
      (4, TileType.webp),
      (5, TileType.avif),
      (6, TileType.mlt),
    ];

    for (final c in decodeCases) {
      test('decodes header tile type 0x${c.$1.toRadixString(16)}', () {
        final data = ByteData(1)..setUint8(0, c.$1);
        expect(data.getTileType(0), c.$2);
      });
    }

    test('throws for unknown tile type value', () {
      final data = ByteData(1)..setUint8(0, 7);
      expect(
        () => data.getTileType(0),
        throwsA(isA<CorruptArchiveException>()),
      );
    });

    const mappingCases = <(TileType, String, String)>[
      (
        TileType.mvt,
        'application/vnd.mapbox-vector-tile',
        'mvt',
      ),
      (
        TileType.mlt,
        'application/vnd.maplibre-vector-tile',
        'mlt',
      ),
      (TileType.png, 'image/png', 'png'),
      (TileType.jpeg, 'image/jpeg', 'jpg'),
      (TileType.webp, 'image/webp', 'webp'),
      (TileType.avif, 'image/avif', 'avif'),
    ];

    for (final c in mappingCases) {
      test('${c.$1} has expected MIME and extension', () {
        expect(c.$1.mimeType(), c.$2);
        expect(c.$1.ext(), c.$3);
      });
    }
  });
}
