import 'dart:convert';
import 'dart:io';

import 'package:pmtiles/src/convert.dart';
import 'package:pmtiles/src/types.dart';

extension CompressionDecoder on Compression {
  // TODO(bramp): I wonder if we can change this to Converter<Uint8List, Uint8List>
  Converter<List<int>, List<int>> decoder() => switch (this) {
    Compression.none => nullConverter,
    Compression.gzip => ZLibDecoder(),
    // TODO(bramp): Add support for the following:
    // Compression.brotli,
    // Compression.zstd,
    _ => throw UnsupportedError('$this compression.'),
  };
}
