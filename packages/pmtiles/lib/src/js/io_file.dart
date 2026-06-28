import 'package:http/http.dart';

import 'package:pmtiles/src/io.dart';

class FileAt implements ReadAt {
  FileAt(Object? _) {
    throw UnsupportedError('File APIs are not supported for dart2js');
  }

  @override
  Future<ByteStream> readAt(int offset, int length) async {
    throw UnsupportedError('File APIs are not supported for dart2js');
  }

  @override
  Future<void> close() {
    throw UnsupportedError('File APIs are not supported for dart2js');
  }
}
