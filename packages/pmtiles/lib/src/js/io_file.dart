import 'package:http/http.dart';

import 'package:pmtiles/src/io.dart';

class FileAt implements ReadAt {
  FileAt(Object? file) {
    if (file != null) {
      // Keep the constructor signature compatible with native FileAt(File).
    }
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
