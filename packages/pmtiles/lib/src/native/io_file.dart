import 'dart:io';
import 'package:http/http.dart';
import 'package:pool/pool.dart';

import '../io.dart';

class FileAt implements ReadAt {
  final File file;

  /// RandomAccessFile only allows a single outstanding read at any time, so
  /// we open a new RandomAccessFile for each read. To bound the number
  /// we use a pool to cap us to 8 outstanding reads.
  final _pool = Pool(8, timeout: Duration(seconds: 30));

  FileAt(this.file);

  @override
  Future<ByteStream> readAt(final int offset, final int length) async {
    return _pool.withResource(() async {
      // TODO Consider caching the open files.
      final file = await this.file.open(mode: FileMode.read);
      try {
        final f = await file.setPosition(offset);
        final data = await f.read(length);

        return ByteStream.fromBytes(data);
      } finally {
        await file.close();
      }
    });
  }

  @override
  Future<void> close() {
    return _pool.close();
  }
}
