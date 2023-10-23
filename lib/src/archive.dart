import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'constants.dart';
import 'convert.dart';
import 'directory.dart';
import 'header.dart';
import 'types.dart';

class PmTilesArchive {
  // TODO come up with a better interface than a RandomAccessFile.
  final RandomAccessFile f;

  /// Cache of the Archive's header. Populated with a call to [header].
  Header? _header;

  PmTilesArchive._(
    this.f,
  );

  /// Returns the PMTiles header.
  /// See https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md#3-header
  Future<Header> get header async {
    if (_header != null) return _header!;

    await f.setPosition(0);
    final headerAndRoot = await f.read(headerAndRootMaxLength);

    _header = Header(
      ByteData.sublistView(headerAndRoot, 0, 127),
    );
    _header!.validate();

    return _header!;
  }

  Future<Directory> get root async {
    assert(_header != null, 'Must call header before metadata');
    final header = _header!;

    // TODO This can be read out of the first 16k we already read.
    await f.setPosition(header.rootDirectoryOffset);
    final root = await f.read(header.rootDirectoryLength);

    final uncompressedRoot = internalDecoder.convert(root);

    return Directory.from(uncompressedRoot);
  }

  static Converter<List<int>, List<int>> _decoder(Compression compression) {
    return switch (compression) {
      Compression.none => nullConverter,
      Compression.gzip => zlib.decoder,
      // TODO Add support for the following:
      // Compression.brotli,
      // Compression.zstd,
      _ => throw Exception('$compression is not supported'),
    };
  }

  /// Return an appropriate decoder for the internal compression.
  Converter<List<int>, List<int>> get internalDecoder {
    assert(_header != null, 'Must call header before metadata');
    final header = _header!;

    return _decoder(header.internalCompression);
  }

  /// Return an appropriate decoder for the internal compression.
  Converter<List<int>, List<int>> get tileDecoder {
    assert(_header != null, 'Must call header before metadata');
    final header = _header!;

    return _decoder(header.tileCompression);
  }

  /// Returns a JSON Object containing the embedded metadata.
  /// See https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md#5-json-metadata
  Future<Object?> get metadata async {
    assert(_header != null, 'Must call header before metadata');
    final header = _header!;

    await f.setPosition(header.metadataOffset);
    final metadata = await f.read(header.metadataLength);
    final utf8ToJson = utf8.decoder.fuse(json.decoder);

    return internalDecoder.fuse(utf8ToJson).convert(metadata);
  }

  static Future<PmTilesArchive> from(RandomAccessFile f) async {
    final archive = PmTilesArchive._(f);

    // Read it once to check it's valid.
    await archive.header;

    return archive;
  }
}
