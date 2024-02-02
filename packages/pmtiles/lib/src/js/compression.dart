import 'dart:convert';

import 'package:archive/archive.dart';
import '../convert.dart';
import '../types.dart';

// Remove this once https://github.com/brendan-duncan/archive/issues/4 is resolved.
final class MyZLibDecoder extends Converter<List<int>, List<int>> {
  @override
  List<int> convert(List<int> input) {
    return GZipDecoder().decodeBytes(input);
  }
}

extension CompressionDecoder on Compression {
  // TODO I wonder if we can change this to Converter<Uint8List, Uint8List>
  Converter<List<int>, List<int>> decoder() => switch (this) {
        Compression.none => nullConverter,
        Compression.gzip => MyZLibDecoder(),
        // TODO Add support for the following:
        // Compression.brotli,
        // Compression.zstd,
        _ => throw UnsupportedError('$this compression.'),
      };
}
