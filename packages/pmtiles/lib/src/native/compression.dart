import 'dart:convert';
import 'dart:io';

import '../convert.dart';
import '../types.dart';

extension CompressionDecoder on Compression {
  // TODO I wonder if we can change this to Converter<Uint8List, Uint8List>
  Converter<List<int>, List<int>> decoder() => switch (this) {
        Compression.none => nullConverter,
        Compression.gzip => zlib.decoder,
        // TODO Add support for the following:
        // Compression.brotli,
        // Compression.zstd,
        _ => throw UnsupportedError('$this compression.'),
      };
}
